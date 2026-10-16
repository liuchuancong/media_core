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

import java.util.ArrayList;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Base of the per-feature foreground services.
 *
 * <p><strong>One feature, one service, one notification, one wake lock.</strong>
 * {@link Feature} names the features — recording, download and generic work — and
 * each one is a separate service class with its own channel, its own notification
 * id, its own session register and its own foreground-service type. That is the
 * isolation the runtime contract asks for: with a single service, the six-hour
 * {@code dataSync} cap a long recording eventually hits also stopped the download
 * sharing that instance, and one notification could only ever describe one of the
 * two jobs while the rest were reduced to a "+2" in its second line.
 *
 * <p>Sessions of <em>one</em> feature still share that feature's notification,
 * because that is what a foreground service is: three concurrent recordings are
 * one line saying what is newest and how many others are running. A feature's
 * release ends only its own sessions, and {@link #onTimeout} stops only the
 * service the platform gave up on.
 *
 * <p>A session handle is {@code (featureCode << 16) | localId}. Dart holds it
 * opaquely and hands it back on update and release, which is how a call reaches
 * the right service without a second, separately-failing registry of who owns
 * which id.
 *
 * <p>State is keyed per feature rather than held in statics of one class, and all
 * of it is touched on the platform's main thread: the method channel and the
 * service callbacks run there, so the registers need no locking of their own.
 */
public abstract class JobForegroundService extends Service {

  /** Extras a service is started with. */
  static final String EXTRA_TITLE = "title";
  static final String EXTRA_TEXT = "text";
  static final String EXTRA_SESSION_ID = "sessionId";
  static final String EXTRA_WAKE_LOCK = "wakeLock";
  static final String EXTRA_KIND = "kind";
  static final String EXTRA_ICON = "icon";
  static final String EXTRA_PROGRESS_STATE = "progressState";
  static final String EXTRA_PROGRESS_CURRENT = "progressCurrent";
  static final String EXTRA_PROGRESS_TOTAL = "progressTotal";

  /** Bits of a session handle that say which feature issued it. */
  private static final int HANDLE_SHIFT = 16;

  /** Local ids of one feature, unique within it. */
  private static final int LOCAL_ID_MASK = 0xFFFF;

  /**
   * A feature that needs to keep running in the background, and everything that
   * belongs to it alone.
   *
   * <p>The {@code key} is the wire spelling of the runtime contract's
   * {@code BackgroundServiceOwner}, sent by Dart on every acquire: routing is
   * decided by the declared owner, never by guessing from a title or a glyph.
   */
  public enum Feature {
    /** Capturing a stream to disk: hours long, so {@code specialUse}. */
    RECORDING("recording", 1, "media_core.recording", "录制 / Recording", 0x4D52, "media_core:recording", "specialUse", R.drawable.ic_stat_media_core_record),

    /** Fetching a file: bounded by the file, so {@code dataSync}. */
    DOWNLOAD("download", 2, "media_core.download", "下载 / Downloads", 0x4D44, "media_core:download", "dataSync", R.drawable.ic_stat_media_core_download),

    /** Work the runtime hosts but cannot name. */
    GENERIC("generic", 3, "media_core.background", "后台任务 / Background tasks", 0x4D43, "media_core:background", "dataSync", R.drawable.ic_stat_media_core_task);

    /** The wire spelling, matching {@code BackgroundServiceOwner.name}. */
    public final String key;

    /** High half of every handle this feature issues. */
    public final int code;

    /** Notification channel this feature alone uses. */
    public final String channelId;

    /** Channel label the user sees in the system's settings. */
    public final String channelName;

    /**
     * Notification id.
     *
     * Constant per feature rather than the session id: the platform associates one
     * notification with one foreground service, and a per-session id would leave
     * the previous session's notification behind as an orphan the user cannot
     * dismiss.
     */
    public final int notificationId;

    /** Tag of this feature's wake lock, so a leak names the feature that took it. */
    public final String wakeLockTag;

    /**
     * {@code android:foregroundServiceType} spelling this feature declares.
     *
     * Kept as text because the manifest is where it has to match; see
     * {@link #serviceTypeId()} for the numeric form the start call needs.
     */
    public final String serviceType;

    /** Glyph shipped for this feature when the host named no icon. */
    public final int defaultGlyph;

    Feature(
        String key,
        int code,
        String channelId,
        String channelName,
        int notificationId,
        String wakeLockTag,
        String serviceType,
        int defaultGlyph) {
      this.key = key;
      this.code = code;
      this.channelId = channelId;
      this.channelName = channelName;
      this.notificationId = notificationId;
      this.wakeLockTag = wakeLockTag;
      this.serviceType = serviceType;
      this.defaultGlyph = defaultGlyph;
    }

    /**
     * The {@link ServiceInfo} type constant for this feature, on API 34 and up.
     *
     * A long recording must not be declared {@code dataSync}: Android caps that
     * type at six hours a day and calls {@code onTimeout} when it runs out, which
     * would end a recording that the user asked to keep running.
     */
    @SuppressWarnings("deprecation")
    public int serviceTypeId() {
      if ("specialUse".equals(serviceType)) {
        // ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE is the API 34 constant;
        // asking for it by name would break a compile against an older SDK the way
        // the rest of this file avoids.
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            ? ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            : 0;
      }

      return ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC;
    }

    /** Which service class implements this feature. */
    public Class<? extends JobForegroundService> serviceClass() {
      switch (this) {
        case RECORDING:
          return RecordingForegroundService.class;
        case DOWNLOAD:
          return DownloadForegroundService.class;
        default:
          return GenericForegroundService.class;
      }
    }
  }

  /** Per-feature session state, alive as long as the process is. */
  private static final class Register {
    /** Running sessions, oldest first. */
    final Map<Integer, Session> sessions = new LinkedHashMap<Integer, Session>();

    final AtomicInteger nextLocalId = new AtomicInteger(1);

    /** The live instance of that feature, while it exists. */
    JobForegroundService instance;
  }

  private static final Map<Feature, Register> REGISTERS = new EnumMap<Feature, Register>(Feature.class);

  private static Register register(Feature feature) {
    Register existing = REGISTERS.get(feature);

    if (existing == null) {
      existing = new Register();
      REGISTERS.put(feature, existing);
    }

    return existing;
  }

  /** Feature a session handle was issued for. */
  public static Feature featureOf(int handle) {
    for (Feature feature : Feature.values()) {
      if (feature.code == (handle >>> HANDLE_SHIFT)) {
        return feature;
      }
    }

    return Feature.GENERIC;
  }

  /** The feature named on the wire, or generic when Dart named none it knows. */
  public static Feature featureForKey(String key) {
    if (key != null) {
      for (Feature feature : Feature.values()) {
        if (feature.key.equals(key)) {
          return feature;
        }
      }
    }

    return Feature.GENERIC;
  }

  /**
   * What the host asked the notification to say.
   *
   * Every field comes from Dart and none of them is invented here: the library
   * knows what a notification is, not what this job is called.
   */
  static final class Description {
    /** Nothing to draw. */
    static final int PROGRESS_NONE = 0;

    /** A spinner: the job is running, its end is unknown. */
    static final int PROGRESS_INDETERMINATE = 1;

    /** A bar: a known amount of a known total. */
    static final int PROGRESS_DETERMINATE = 2;

    final String title;
    final String text;
    final String kind;
    final String icon;
    final int progressState;
    final int progressCurrent;
    final int progressTotal;

    Description(
        String title,
        String text,
        String kind,
        String icon,
        int progressState,
        int progressCurrent,
        int progressTotal) {
      this.title = title == null || title.isEmpty() ? "Running" : title;
      this.text = text;
      this.kind = kind;
      this.icon = icon;
      // A bar needs a positive total to mean anything; anything else is the
      // spinner, which is what "running, length unknown" honestly looks like.
      final boolean bar = progressState == PROGRESS_DETERMINATE && progressTotal > 0;

      this.progressState = bar ? PROGRESS_DETERMINATE : progressState == PROGRESS_NONE ? PROGRESS_NONE : PROGRESS_INDETERMINATE;
      this.progressTotal = bar ? progressTotal : 0;
      this.progressCurrent = bar ? Math.max(0, Math.min(progressCurrent, progressTotal)) : 0;
    }

    /** Whether a bar or a spinner belongs in the notification. */
    boolean hasProgress() {
      return progressState != PROGRESS_NONE;
    }

    /** Whether the end of the job is known. */
    boolean isDeterminate() {
      return progressState == PROGRESS_DETERMINATE;
    }
  }

  /** One job that asked not to be frozen. */
  private static final class Session {
    final int id;
    final Description description;
    final boolean wakeLock;

    Session(int id, Description description, boolean wakeLock) {
      this.id = id;
      this.description = description;
      this.wakeLock = wakeLock;
    }
  }

  /**
   * Starts a session for {@code ownerKey}.
   *
   * Returns the session handle, or -1 when the platform refuses to run the service
   * at all (a restricted background launch, a missing declaration) — the caller
   * then runs the job unprotected instead of failing it. A refused
   * <em>notification</em> is not that case: the service still runs and the wake
   * lock still holds, only the notification is hidden.
   */
  public static int start(Context context, String ownerKey, Description description, boolean wakeLock) {
    final Feature feature = featureForKey(ownerKey);
    final Register register = register(feature);
    final int localId = register.nextLocalId.getAndIncrement();

    if (localId > LOCAL_ID_MASK) {
      // 65k sessions in one feature is a caller that stopped releasing them; the
      // handle would collide with the next one, and a wrong release is worse than
      // no protection at all.
      return -1;
    }

    final Intent intent = new Intent(context, feature.serviceClass());

    putDescription(intent, description);

    intent.putExtra(EXTRA_SESSION_ID, localId).putExtra(EXTRA_WAKE_LOCK, wakeLock);

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

    return (feature.code << HANDLE_SHIFT) | localId;
  }

  /**
   * Replaces what a running session's notification says.
   *
   * A no-op for a session that is gone: the notification went with it, and a job
   * that finishes while an update is in flight must not resurrect one.
   */
  public static void update(int handle, Description description) {
    final JobForegroundService service = serviceFor(handle);

    if (service != null) {
      service.updateSession(localIdOf(handle), description);
    }
  }

  /**
   * Ends the session behind {@code handle}, leaving that feature's other sessions
   * and every other feature alone.
   *
   * A no-op when the service is already gone: its sessions went with it.
   */
  public static void stop(int handle) {
    final JobForegroundService service = serviceFor(handle);

    if (service != null) {
      service.releaseSession(localIdOf(handle));
    }
  }

  private static JobForegroundService serviceFor(int handle) {
    return handle < 0 ? null : register(featureOf(handle)).instance;
  }

  private static int localIdOf(int handle) {
    return handle & LOCAL_ID_MASK;
  }

  private static void putDescription(Intent intent, Description description) {
    intent
        .putExtra(EXTRA_TITLE, description.title)
        .putExtra(EXTRA_TEXT, description.text)
        .putExtra(EXTRA_KIND, description.kind)
        .putExtra(EXTRA_ICON, description.icon)
        .putExtra(EXTRA_PROGRESS_STATE, description.progressState)
        .putExtra(EXTRA_PROGRESS_CURRENT, description.progressCurrent)
        .putExtra(EXTRA_PROGRESS_TOTAL, description.progressTotal);
  }

  /**
   * Reads a description back out of the Intent.
   *
   * The Intent is the durable half: extras survive a service the platform
   * recreated, which is why the description travels with it rather than through a
   * field of this instance.
   */
  private static Description readDescription(Intent intent) {
    if (intent == null) {
      return new Description(null, null, null, null, Description.PROGRESS_NONE, 0, 0);
    }

    return new Description(
        intent.getStringExtra(EXTRA_TITLE),
        intent.getStringExtra(EXTRA_TEXT),
        intent.getStringExtra(EXTRA_KIND),
        intent.getStringExtra(EXTRA_ICON),
        intent.getIntExtra(EXTRA_PROGRESS_STATE, Description.PROGRESS_NONE),
        intent.getIntExtra(EXTRA_PROGRESS_CURRENT, 0),
        intent.getIntExtra(EXTRA_PROGRESS_TOTAL, 0));
  }

  /** Which feature this instance serves. */
  abstract Feature feature();

  private Register myRegister() {
    return register(feature());
  }

  private PowerManager.WakeLock wakeLock;

  @Override
  public void onCreate() {
    super.onCreate();

    myRegister().instance = this;
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    final Register register = myRegister();
    final int sessionId = intent == null ? -1 : intent.getIntExtra(EXTRA_SESSION_ID, -1);

    if (sessionId < 0) {
      stopSelf(startId);

      return START_NOT_STICKY;
    }

    final boolean wakeLock = intent.getBooleanExtra(EXTRA_WAKE_LOCK, false);
    final Session session = new Session(sessionId, readDescription(intent), wakeLock);

    register.sessions.put(sessionId, session);

    startForegroundInternal(startId);

    if (session.wakeLock) {
      acquireWakeLock();
    }

    if (!notificationsVisible()) {
      // The session is real and its lock is held; only the user cannot see it. That
      // is "running, with something given up", which is what `degraded` means here —
      // not a failure, and not a reason to fail a recording over a picture.
      publish(sessionId, BackgroundStatusPublisher.STATUS_DEGRADED);
    }

    // Not sticky: resuming a recording after the process was killed would write
    // a second stream into the same directory without the user asking.
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    releaseWakeLock();

    final Register register = myRegister();

    // Sessions left behind when the platform ended the service: Dart is still
    // holding a lease for each of them, and a lease that is never told stops
    // counting is how a job ends up reporting protection it no longer has. The
    // normal path is empty here — the last release stopped the service after
    // removing its own session.
    for (Integer sessionId : new ArrayList<Integer>(register.sessions.keySet())) {
      publish(sessionId, BackgroundStatusPublisher.STATUS_STOPPED);
    }

    register.sessions.clear();

    if (register.instance == this) {
      register.instance = null;
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
   * Stopping here is what keeps the process from being killed for not responding,
   * and it takes down <em>only this feature's</em> sessions: a download that ran
   * out of allowance used to stop the service a recording shared with it, which
   * is exactly the interference this split exists to remove. The job itself keeps
   * running (it is the app's own process), just without the protection — which is
   * what the recording module documents.
   */
  @Override
  public void onTimeout(int startId, int foregroundServiceType) {
    final Register register = myRegister();

    // The jobs themselves are still running in this process; what ended is the
    // exemption and the lock. `protectionLost` says exactly that, and it is not
    // `stopped`, which would tell the caller its own release worked.
    for (Integer sessionId : new ArrayList<Integer>(register.sessions.keySet())) {
      publish(sessionId, BackgroundStatusPublisher.STATUS_PROTECTION_LOST);
    }

    // Cleared before stopping: the onDestroy pass must not report these twice.
    register.sessions.clear();

    stopForegroundAndSelf();
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  /** The handle Dart holds for {@code sessionId} of this feature. */
  private int handleOf(int sessionId) {
    return (feature().code << HANDLE_SHIFT) | sessionId;
  }

  /** Tells Dart what happened to one of this feature's sessions. */
  private void publish(int sessionId, String status) {
    BackgroundStatusPublisher.publish(handleOf(sessionId), status);
  }

  /**
   * Whether a notification posted by this service can reach the user.
   *
   * Below API 33 the permission does not exist, so the answer is what the platform
   * has always been. A missing permission hides the line and nothing else: the
   * service runs and the wake lock holds, which is why this is a report rather than
   * a refusal.
   */
  private boolean notificationsVisible() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      return true;
    }

    return checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
        == android.content.pm.PackageManager.PERMISSION_GRANTED;
  }

  private void updateSession(int sessionId, Description description) {
    final Register register = myRegister();
    final Session session = register.sessions.get(sessionId);

    if (session == null) {
      return;
    }

    // Replacement keeps the register's order, so an update never decides which
    // job owns the notification.
    register.sessions.put(sessionId, new Session(sessionId, description, session.wakeLock));

    updateNotification();
  }

  private void releaseSession(int sessionId) {
    final Register register = myRegister();

    if (register.sessions.remove(sessionId) == null) {
      return;
    }

    if (register.sessions.isEmpty()) {
      releaseWakeLock();
      stopForegroundAndSelf();

      return;
    }

    // Other jobs of the same feature are still running: keep the service, but stop
    // holding the CPU for a job that no longer needs it.
    if (!anySessionWantsWakeLock()) {
      releaseWakeLock();
    }

    updateNotification();
  }

  /** The session the notification describes: the one that started last. */
  private Session newestSession() {
    Session newest = null;

    for (Session session : myRegister().sessions.values()) {
      newest = session;
    }

    return newest;
  }

  private boolean anySessionWantsWakeLock() {
    for (Session session : myRegister().sessions.values()) {
      if (session.wakeLock) {
        return true;
      }
    }

    return false;
  }

  // The boolean form is the API < 24 branch.
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

  private void startForegroundInternal(int startId) {
    createChannel();

    final Notification notification = buildNotification();
    final Feature feature = feature();

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      startForeground(feature.notificationId, notification, feature.serviceTypeId());

      return;
    }

    startForeground(feature.notificationId, notification);
  }

  /** Reposts the notification after a session ended, without re-alerting. */
  private void updateNotification() {
    final NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    if (manager != null) {
      manager.notify(feature().notificationId, buildNotification());
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

    final Feature feature = feature();
    final NotificationChannel channel =
        new NotificationChannel(feature.channelId, feature.channelName, NotificationManager.IMPORTANCE_LOW);

    // Silence and no badge: work the user started, not news.
    channel.setShowBadge(false);
    channel.setDescription(feature.channelName);

    manager.createNotificationChannel(channel);
  }

  // The one-argument Builder is the API < 26 branch; the channel id is the only
  // way to build one from 26 on.
  @SuppressWarnings("deprecation")
  private Notification buildNotification() {
    final Feature feature = feature();
    final Session visible = newestSession();
    final Description description =
        visible == null
            ? new Description(null, null, null, null, Description.PROGRESS_NONE, 0, 0)
            : visible.description;

    final Notification.Builder builder =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(this, feature.channelId)
            : new Notification.Builder(this);

    final Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());

    if (launch != null) {
      launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);

      final PendingIntent pending =
          PendingIntent.getActivity(
              this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

      builder.setContentIntent(pending);
    }

    final String text = description.text;
    final String others = count(myRegister().sessions.size() - 1);

    builder
        .setContentTitle(description.title)
        .setContentText(
            text == null || text.isEmpty() ? others : others.isEmpty() ? text : text + "  (" + others + ")")
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setShowWhen(false)
        .setSmallIcon(notificationIcon(description, feature));

    if (description.hasProgress()) {
      // The two shapes the platform draws: a filled bar with a known total, and
      // a spinner with no numbers at all.
      builder.setProgress(description.progressTotal, description.progressCurrent, !description.isDeterminate());
    }

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
   * Icon of the notification.
   *
   * The host's own drawable when it named one (the convention the media
   * notification uses too), otherwise the glyph shipped for the feature —
   * borrowing a system drawable would show a download arrow on a recording. A name
   * that does not resolve falls back to that glyph rather than leaving the
   * notification without an icon, which the platform refuses to post at all.
   */
  private int notificationIcon(Description description, Feature feature) {
    final int named = resolveIcon(description.icon);

    return named != 0 ? named : feature.defaultGlyph;
  }

  /**
   * Looks a host icon up by name.
   *
   * A bare name is tried as a drawable and then as a mipmap, and a full
   * {@code @drawable/name} reference is accepted too, because both spellings are
   * common in a host's resources. Zero means "not found".
   */
  private int resolveIcon(String name) {
    if (name == null || name.isEmpty()) {
      return 0;
    }

    String bare = name;

    if (bare.startsWith("@drawable/")) {
      bare = bare.substring("@drawable/".length());
    } else if (bare.startsWith("@mipmap/")) {
      bare = bare.substring("@mipmap/".length());
    }

    final int drawable = getResources().getIdentifier(bare, "drawable", getPackageName());

    return drawable != 0 ? drawable : getResources().getIdentifier(bare, "mipmap", getPackageName());
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

      wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, feature().wakeLockTag);
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
