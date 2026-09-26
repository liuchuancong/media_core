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

import java.util.concurrent.atomic.AtomicInteger;

/**
 * Keeps a long-running job alive while the app is in the background.
 *
 * A foreground service is the platform's own mechanism for "the user knows this
 * is running": the process is not frozen with the screen off, and the
 * notification is what tells the user why. Two things are started and stopped
 * together here:
 *
 * <ul>
 *   <li>the service itself, typed {@code dataSync} on API 34+ (a download or a
 *       recording is data transfer, not media playback);
 *   <li>a {@link PowerManager#PARTIAL_WAKE_LOCK}, so the CPU keeps running
 *       after the screen goes off — a TV box or a phone that suspends the CPU
 *       would otherwise stall the writer mid-segment.
 * </ul>
 *
 * <p>The service holds nothing about the job: it is started with the text to
 * show and stopped by whoever started it. A session id is returned so several
 * jobs (a recording and a download) do not stop each other's notification.
 *
 * <p>Declared in this plugin's own manifest, which the app inherits — a plain
 * {@code <service>} merges from a library manifest, unlike audio_service's
 * activity replacement, so the host does not have to copy anything.
 */
public final class BackgroundExecutionService extends Service {

  /** Notification channel every session uses. */
  static final String CHANNEL_ID = "media_core.background";

  /** Extras the service is started with. */
  static final String EXTRA_TITLE = "title";
  static final String EXTRA_TEXT = "text";
  static final String EXTRA_SESSION_ID = "sessionId";

  /** Session ids, unique per process. */
  private static final AtomicInteger NEXT_SESSION_ID = new AtomicInteger(1);

  /** Counter handed to whoever asked for a session. */
  static int nextSessionId() {
    return NEXT_SESSION_ID.getAndIncrement();
  }

  private PowerManager.WakeLock wakeLock;

  /**
   * Starts a session.
   *
   * Returns the session id, or -1 when the notification cannot be posted (on
   * Android 13+ without {@code POST_NOTIFICATIONS} a foreground service has
   * nothing to display) — the caller then runs the job unprotected instead of
   * failing it.
   */
  static int start(Context context, String title, String text, boolean wakeLock) {
    final int sessionId = nextSessionId();

    final Intent intent = new Intent(context, BackgroundExecutionService.class)
        .putExtra(EXTRA_TITLE, title)
        .putExtra(EXTRA_TEXT, text)
        .putExtra(EXTRA_SESSION_ID, sessionId)
        .putExtra("wakeLock", wakeLock);

    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent);
      } else {
        context.startService(intent);
      }
    } catch (Throwable error) {
      // A platform that refuses to start it (restricted background launch, a
      // missing permission) means "no protection", not "the job failed".
      return -1;
    }

    return sessionId;
  }

  /** Stops the session with [sessionId], leaving other sessions alone. */
  static void stop(Context context, int sessionId) {
    context.stopService(
        new Intent(context, BackgroundExecutionService.class).putExtra(EXTRA_SESSION_ID, sessionId));
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    final int sessionId = intent == null ? -1 : intent.getIntExtra(EXTRA_SESSION_ID, -1);

    if (sessionId < 0) {
      stopSelf(startId);

      return START_NOT_STICKY;
    }

    final String title = intent.getStringExtra(EXTRA_TITLE);
    final String text = intent.getStringExtra(EXTRA_TEXT);

    startForegroundInternal(title == null ? "Running" : title, text == null ? "" : text, startId);

    if (intent.getBooleanExtra("wakeLock", false)) {
      acquireWakeLock();
    }

    // Not sticky: resuming a recording after the process was killed would write
    // a second stream into the same directory without the user asking.
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    releaseWakeLock();
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }

  // ---------------------------------------------------------------------------
  // Foreground notification
  // ---------------------------------------------------------------------------

  private void startForegroundInternal(String title, String text, int startId) {
    final NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
      final NotificationChannel channel =
          new NotificationChannel(CHANNEL_ID, "Background tasks", NotificationManager.IMPORTANCE_LOW);
      channel.setShowBadge(false);
      manager.createNotificationChannel(channel);
    }

    final Notification.Builder builder =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(this, CHANNEL_ID)
            : new Notification.Builder(this);

    final Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());

    if (launch != null) {
      launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);

      final PendingIntent pending =
          PendingIntent.getActivity(
              this,
              0,
              launch,
              PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

      builder.setContentIntent(pending);
    }

    final Notification notification =
        builder
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setShowWhen(false)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .build();

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      startForeground(startId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);

      return;
    }

    startForeground(startId, notification);
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
