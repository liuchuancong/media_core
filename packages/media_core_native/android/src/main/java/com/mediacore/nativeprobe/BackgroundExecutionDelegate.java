package com.mediacore.nativeprobe;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Dart side of {@link BackgroundExecutionService}.
 *
 * Wire protocol (see {@code BackgroundExecution} on the Dart side, which is the
 * source of truth):
 *
 * | direction | method | arguments | result |
 * |---|---|---|---|
 * | Dart → host | {@code acquire} | {title, text, wakeLock, kind} | session id, or null when the platform refused |
 * | Dart → host | {@code release} | {id} | – |
 *
 * <p>No {@code isSupported} call: the platform name is known in Dart, and a
 * round trip to answer "am I Android" would only be a way to disagree with it.
 *
 * <p><strong>The notification permission is asked for here.</strong> From API 33
 * a foreground service posts its notification only with
 * {@code POST_NOTIFICATIONS}, and the plugin declares it in its manifest; asking
 * is the step that was missing, and without it the service runs, the wake lock
 * holds, and the user sees nothing at all. The question is asked while an
 * activity is attached and the {@code acquire} answer waits for it, so Dart does
 * not have to know the platform asked. A refusal is not an error: the session is
 * still started, because the wake lock is what keeps the job alive — only the
 * notification stays hidden.
 *
 * <p>A refused acquire is answered with null rather than an error for the same
 * reason: the caller runs the job unprotected, which is better than failing a
 * recording because the platform would not take the service.
 */
final class BackgroundExecutionDelegate implements MethodChannel.MethodCallHandler {

  /** Channel name; kept in sync with the Dart side. */
  static final String CHANNEL_NAME = "media_core_native/background";

  /** Request code for the notification dialog. Ours alone: nothing else asks. */
  private static final int REQUEST_NOTIFICATIONS = 0x4D31;

  private static final String PERMISSION_NOTIFICATIONS = Manifest.permission.POST_NOTIFICATIONS;

  private final Context context;

  /** The activity to ask from, while one is attached. */
  private Activity activity;

  /** The acquire waiting for the user to answer the dialog, if one is. */
  private MethodChannel.Result pendingResult;
  private String pendingTitle;
  private String pendingText;
  private String pendingKind;
  private boolean pendingWakeLock;

  BackgroundExecutionDelegate(Context context) {
    this.context = context;
  }

  /**
   * Follows the activity this plugin is attached to.
   *
   * A missing activity is not a failure: it only means the permission cannot be
   * asked for right now, so an acquire that was waiting on the dialog is
   * answered by starting the session anyway.
   */
  void setActivity(Activity activity) {
    this.activity = activity;

    if (activity == null) {
      finishPending();
    }
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "acquire":
        acquire(call, result);
        break;

      case "release":
        final Integer id = call.argument("id");

        if (id != null && id >= 0) {
          BackgroundExecutionService.stop(id);
        }

        result.success(null);
        break;

      default:
        result.notImplemented();
    }
  }

  /** Answers {@link #REQUEST_NOTIFICATIONS}; returns whether it was ours. */
  boolean onPermissionResult(int requestCode) {
    if (requestCode != REQUEST_NOTIFICATIONS) {
      return false;
    }

    finishPending();

    return true;
  }

  private void acquire(MethodCall call, MethodChannel.Result result) {
    final String title = call.argument("title");
    final String text = call.argument("text");
    final String kind = call.argument("kind");
    final boolean wakeLock = Boolean.TRUE.equals(call.argument("wakeLock"));

    final String name = title == null ? "Running" : title;

    if (needsNotificationPermission()) {
      pendingResult = result;
      pendingTitle = name;
      pendingText = text;
      pendingKind = kind;
      pendingWakeLock = wakeLock;

      activity.requestPermissions(new String[] {PERMISSION_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);

      // Answered from onPermissionResult, or from setActivity(null) if the
      // activity goes away while the dialog is open.
      return;
    }

    result.success(start(name, text, kind, wakeLock));
  }

  /** Starts the session the pending acquire asked for, and answers it. */
  private void finishPending() {
    final MethodChannel.Result result = pendingResult;

    if (result == null) {
      return;
    }

    pendingResult = null;

    result.success(start(pendingTitle, pendingText, pendingKind, pendingWakeLock));

    pendingTitle = null;
    pendingText = null;
    pendingKind = null;
    pendingWakeLock = false;
  }

  private Integer start(String title, String text, String kind, boolean wakeLock) {
    final int sessionId =
        BackgroundExecutionService.start(context, title, text, wakeLock, kind);

    return sessionId < 0 ? null : sessionId;
  }

  /**
   * Whether the dialog has to be shown before the service starts.
   *
   * Only from API 33, only with an activity to ask from, and only when no
   * acquire is already waiting on the dialog — a second job asking while the
   * user is deciding starts immediately rather than queueing behind a question
   * that is already on screen.
   */
  private boolean needsNotificationPermission() {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        && activity != null
        && pendingResult == null
        && context.checkSelfPermission(PERMISSION_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED;
  }
}
