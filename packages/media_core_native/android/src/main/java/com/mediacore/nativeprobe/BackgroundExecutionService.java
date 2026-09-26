package com.mediacore.nativeprobe;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Keeps long-running jobs alive while the app is in the background.
 *
 * A foreground service is the platform's own mechanism for "the user knows this
 * is running": the process is not frozen with the screen off, and the
 * notification is what tells the user why. Two things are held here together:
 *
 * <ul>
 *   <li>the service itself, typed {@code dataSync} on API 34+ (a download or a
 *       recording is data transfer, not media playback);
 *   <li>a {@link PowerManager#PARTIAL_WAKE_LOCK}, so the CPU keeps running after
 *       the screen goes off — a phone or a TV box that suspends the CPU would
 *       otherwise stall the writer mid-segment.
 * </ul>
 *
 * <p><strong>One service, one notification, several sessions.</strong> A
 * foreground service is per-service, not per-job, so two jobs (a recording and a
 * download) share this instance. They are tracked in a register: the
 * notification describes the newest session and says how many others are
 * running, and a job that ends removes only itself. Stopping the service on the
 * first release would silently take the protection away from a job that is still
 * running, and dropping the wake lock with it would let the device sleep
 * mid-recording — so the lock is released only once no remaining session wants
 * it.
 *
 * <p>Declared in this plugin's own manifest, which the app inherits — a plain
 * {@code <service>} merges from a library manifest, unlike audio_service's
 * activity replacement, so the host does not have to copy anything. The
 * notification permission is asked for by {@link BackgroundExecutionDelegate}
 * while an activity is attached.
 */
public final class BackgroundExecutionService extends Service {

  /** Notification channel every session uses. */
  static final String CHANNEL_ID = "media_core.background";

  /** Extras the service is started with. */
  static final String EXTRA_TITLE = "title";
  static final String EXTRA_TEXT = "text";
  static final String EXTRA_SESSION_ID = "sessionId";
  static final String EXTRA_WAKE_LOCK = "wakeLock";
  static final String EXTRA_KIND = "kind";

  /**
   * Notification id.
   *
   * A constant rather than the session id: the platform associates one
   * notification with the foreground service, and a per-session id would leave
   * the previous session's notification behind as an orphan the user cannot
   * dismiss.
   */
  private static final int NOTIFICATION_ID = 0x4D43;

  /** Session ids, unique per process. */
  private static final AtomicInteger NEXT_SESSION_ID = new AtomicInteger(1);

  /**
   * Running sessions, oldest first.
   *
   * Static because the sessions belong to the process rather than to an
   * instance: a service the platform recreated must not forget what is still
   * running.
   */
  private static final Map<Integer, Session> SESSIONS = new LinkedHashMap<Integer, Session>();

  /** The process's single instance, while it is alive. */
  private static BackgroundExecutionService instance;

  /** One job that asked not to be frozen. */
  private static final class Session {
    final int id;
    final String title;
    final String text;
    final String kind;
    final boolean wakeLock;

    Session(int id, String title, String text, String kind, boolean wakeLock) {
      this.id = id;
      this.title = title;
      this.text = text;
      this.kind = kind;
      this.wakeLock = wakeLock;
    }
  }

  /** Counter handed to whoever asked for a session. */
  static int nextSessionId() {
    return NEXT_SESSION_ID.getAndIncrement();
  }

  /**
   * Starts a session.
   *
   * Returns the session id, or -1 when the platform refuses to run the service
   * at all (a restricted background launch, a missing declaration) — the caller
   * then runs the job unprotected instead of failing it. A refused
   * <em>notification</em> is not that case: the service still runs and the wake
   * lock still holds, only the notification is hidden.
   */
  static int start(Context context, String title, String text, boolean wakeLock, String kind) {
    final int sessionId = nextSessionId();

    final Intent intent =
        new Intent(context, BackgroundExecutionService.class)
            .putExtra(EXTRA_TITLE, title)
            .putExtra(EXTRA_TEXT, text)
            .putExtra(EXTRA_SESSION_ID, sessionId)
            .putExtra(EXTRA_WAKE_LOCK, wakeLock)
            .putExtra(EXTRA_KIND, kind);

    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent);
      } else {
        context.startService(intent);
      }
    } catch (Throwable error) {
      // A platform that refuses to start it means "no protection", not "the job
      // failed". Nothing was registered, so there is nothing to release.
      return -1;
    }

    return sessionId;
  }

  /**
   * Ends the session with {@code sessionId}, leaving every other session alone.
   *
   * A no-op when the service is already gone: the sessions went with it.
   */
  static void stop(int sessionId) {
    final BackgroundExecutionService service = instance;

    if (service != null) {
      service.releaseSession(sessionId);
    }
  }

  private PowerManager.WakeLock wakeLock;

  @Override
  public void onCreate() {
    super.onCreate();

    instance = this;
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    final int sessionId = intent == null ? -1 : intent.getIntExtra(EXTRA_SESSION_ID, -1);

    if (sessionId < 0) {
      stopSelf(startId);

      return START_NOT_STICKY;
    }

    final String title = intent.getStringExtra(EXTRA_TITLE);
    final Session session =
        new Session(
            sessionId,
            title == null ? "Running" : title,
            intent.getStringExtra(EXTRA_TEXT),
            intent.getStringExtra(EXTRA_KIND),
            intent.getBooleanExtra(EXTRA_WAKE_LOCK, false));

    SESSIONS.put(sessionId, session);

    startForegroundInternal(session, startId);

    if (session.wakeLock) {
      acquireWakeLock();
    }

    // Not sticky: resuming a recording after the process was killed would write
    // a second stream into the same directory without the user asking.
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    releaseWakeLock();

    SESSIONS.clear();

    if (instance == this) {
      instance = null;
    }

    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }

  /**
   * Android 15 caps {@code dataSync} foreground services at six hours a day.
   *
   * When the cap is reached the platform calls this and the service has to stop.
   * Stopping here is what keeps the process from being killed for not
   * responding; the job itself keeps running (it is the app's own process), just
   * without the protection — which is what the recording module documents.
   */
  @Override
  public void onTimeout(int startId, int foregroundServiceType) {
    stopForegroundAndSelf();
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  private void releaseSession(int sessionId) {
    if (SESSIONS.remove(sessionId) == null) {
      return;
    }

    if (SESSIONS.isEmpty()) {
      releaseWakeLock();
      stopForegroundAndSelf();

      return;
    }

    // Other jobs are still running: keep the service, but stop holding the CPU
    // for a job that no longer needs it.
    if (!anySessionWantsWakeLock()) {
      releaseWakeLock();
    }

    updateNotification();
  }

  /** The session the notification describes: the one that started last. */
  private Session newestSession() {
    Session newest = null;

    for (Session session : SESSIONS.values()) {
      newest = session;
    }

    return newest;
  }

  private boolean anySessionWantsWakeLock() {
    for (Session session : SESSIONS.values()) {
      if (session.wakeLock) {
        return true;
      }
    }

    return false;
  }

  @SuppressWarnings("deprecation")
  private void stopForegroundAndSelf() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE);
    } else {
      stopForeground(true);
    }

    stopSelf();
  }

  // ---------------------------------------------------------------------------
  // Foreground notification
  // ---------------------------------------------------------------------------

  private void startForegroundInternal(Session session, int startId) {
    createChannel();

    final Notification notification = buildNotification();

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);

      return;
    }

    startForeground(NOTIFICATION_ID, notification);
  }

  /** Reposts the notification after a session ended, without re-alerting. */
  private void updateNotification() {
    final NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    if (manager != null) {
      manager.notify(NOTIFICATION_ID, buildNotification());
    }
  }

  private void createChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return;
    }

    final NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    if (manager == null) {
      return;
    }

    final NotificationChannel channel =
        new NotificationChannel(CHANNEL_ID, "Background tasks", NotificationManager.IMPORTANCE_LOW);

    // Silence and no badge: work the user started, not news.
    channel.setShowBadge(false);

    manager.createNotificationChannel(channel);
  }

  // The one-argument Builder is the API < 26 branch; the channel id is the
  // only way to build one from 26 on.
  @SuppressWarnings("deprecation")
  private Notification buildNotification() {
    final Session visible = newestSession();

    final Notification.Builder builder =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(this, CHANNEL_ID)
            : new Notification.Builder(this);

    final Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());

    if (launch != null) {
      launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);

      final PendingIntent pending =
          PendingIntent.getActivity(
              this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

      builder.setContentIntent(pending);
    }

    final String text = visible == null ? null : visible.text;
    final String others = count(SESSIONS.size() - 1);

    builder
        .setContentTitle(visible == null ? "Running" : visible.title)
        .setContentText(
            text == null || text.isEmpty() ? others : others.isEmpty() ? text : text + "  (" + others + ")")
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setShowWhen(false)
        .setSmallIcon(notificationIcon(visible == null ? null : visible.kind));

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // Show it now rather than after the platform's grace period for a service
      // started from the background: a notification that appears ten seconds
      // late reads as "there is none".
      builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE);
    }

    return builder.build();
  }

  /** "+2" for the other running jobs, or empty when this is the only one. */
  private static String count(int others) {
    return others <= 0 ? "" : "+" + others;
  }

  /**
   * Icon of the notification, by what the job is.
   *
   * Shipped as vectors in this plugin's resources (merged into the app), because
   * borrowing a system drawable would show a download arrow on a recording.
   */
  private int notificationIcon(String kind) {
    if ("record".equals(kind)) {
      return R.drawable.ic_stat_media_core_record;
    }

    if ("download".equals(kind)) {
      return R.drawable.ic_stat_media_core_download;
    }

    return R.drawable.ic_stat_media_core_task;
  }

  // ---------------------------------------------------------------------------
  // Wake lock
  // ---------------------------------------------------------------------------

  private void acquireWakeLock() {
    if (wakeLock != null) {
      return;
    }

    try {
      final PowerManager power = (PowerManager) getSystemService(Context.POWER_SERVICE);

      if (power == null) {
        return;
      }

      wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "media_core:background");
      wakeLock.setReferenceCounted(false);
      wakeLock.acquire();
    } catch (Throwable ignored) {
      // Without the lock the job still runs while the app is foreground; the
      // screen going off is the platform's decision, not a failure here.
      wakeLock = null;
    }
  }

  private void releaseWakeLock() {
    final PowerManager.WakeLock lock = wakeLock;

    wakeLock = null;

    if (lock == null) {
      return;
    }

    try {
      if (lock.isHeld()) {
        lock.release();
      }
    } catch (Throwable ignored) {
      /* Already released by the platform. */
    }
  }
}
