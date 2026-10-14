package com.mediacore.nativeprobe;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import java.util.Map;

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
 * | Dart → host | {@code acquire} | {notification, wakeLock} | session id, or null when the platform refused |
 * | Dart → host | {@code update} | {id, notification} | – |
 * | Dart → host | {@code release} | {id} | – |
 * | Dart → host | {@code notificationsPermitted} | – | whether the user may see notifications at all |
 *
 * <p>{@code notification} is the map `BackgroundExecution.encodeNotification`
 * builds: title, text, kind, icon and an optional progress map that says which
 * of the two shapes it is. None of it is defaulted here beyond a placeholder
 * title — the words and the icon are the host's.
 *
 * <p>No {@code isSupported} call: the platform name is known in Dart, and a
 * round trip to answer "am I Android" would only be a way to disagree with it.
 *
 * <p><strong>This class never asks for a permission.</strong> From API 33 a
 * foreground service shows its notification only with {@code POST_NOTIFICATIONS},
 * and asking is the app's decision — when it has a screen for the question, not
 * whatever job happened to need protection first. An earlier version requested
 * the permission here, from inside {@code acquire}, and that meant a download
 * resumed in the background could put a system dialog in front of the user and
 * hold the acquire answer until they decided. The plugin still declares
 * {@code POST_NOTIFICATIONS}; the host asks through
 * {@code MediaCoreNotify.requestPermission()}, which is the one entry point for
 * the question, and {@link #notificationsPermitted} is how it checks the answer
 * without asking.
 *
 * <p>A missing permission is not a failure either: the service runs and the wake
 * lock holds with the notification hidden, which is the user's choice about being
 * told, not about the work. A refused <em>service</em> is answered with null
 * rather than an error for the same reason — the caller runs the job unprotected,
 * which is better than failing a recording because the platform would not take it.
 */
final class BackgroundExecutionDelegate implements MethodChannel.MethodCallHandler {

  /** Channel name; kept in sync with the Dart side. */
  static final String CHANNEL_NAME = "media_core_native/background";

  private static final String PERMISSION_NOTIFICATIONS = Manifest.permission.POST_NOTIFICATIONS;

  private final Context context;

  BackgroundExecutionDelegate(Context context) {
    this.context = context;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "acquire":
        result.success(start(descriptionOf(call), Boolean.TRUE.equals(call.argument("wakeLock"))));
        break;

      case "update":
        update(call);

        result.success(null);
        break;

      case "release":
        final Integer id = call.argument("id");

        if (id != null && id >= 0) {
          BackgroundExecutionService.stop(id);
        }

        result.success(null);
        break;

      case "notificationsPermitted":
        result.success(notificationsPermitted());
        break;

      default:
        result.notImplemented();
    }
  }

  /** Replaces what a running session's notification says. */
  private void update(MethodCall call) {
    final Integer id = call.argument("id");

    if (id == null || id < 0) {
      return;
    }

    BackgroundExecutionService.update(id, descriptionOf(call));
  }

  /**
   * Whether a notification posted here can reach the user.
   *
   * A check, not a question: this never shows a dialog, because when the user is
   * asked is the app's decision. Below API 33 the permission does not exist, so
   * the answer is what the platform has always been — permitted.
   */
  private boolean notificationsPermitted() {
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
        || context.checkSelfPermission(PERMISSION_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
  }

  private Integer start(BackgroundExecutionService.Description description, boolean wakeLock) {
    final int sessionId = BackgroundExecutionService.start(context, description, wakeLock);

    return sessionId < 0 ? null : sessionId;
  }

  /**
   * Reads the notification description out of a call.
   *
   * A missing or malformed map yields a plain "Running" — the platform still
   * needs a notification, and refusing to start a job over a bad title would
   * fail the work for the label on it.
   */
  private BackgroundExecutionService.Description descriptionOf(MethodCall call) {
    final Object encoded = call.argument("notification");

    if (!(encoded instanceof Map)) {
      return new BackgroundExecutionService.Description(
          null, null, null, null, BackgroundExecutionService.Description.PROGRESS_NONE, 0, 0);
    }

    final Map<?, ?> notification = (Map<?, ?>) encoded;
    final Object progress = notification.get("progress");

    int state = BackgroundExecutionService.Description.PROGRESS_NONE;
    int current = 0;
    int total = 0;

    if (progress instanceof Map) {
      final Map<?, ?> values = (Map<?, ?>) progress;

      if (Boolean.TRUE.equals(values.get("indeterminate"))) {
        state = BackgroundExecutionService.Description.PROGRESS_INDETERMINATE;
      } else {
        state = BackgroundExecutionService.Description.PROGRESS_DETERMINATE;
        current = intValue(values.get("current"));
        total = intValue(values.get("total"));
      }
    }

    return new BackgroundExecutionService.Description(
        stringValue(notification.get("title")),
        stringValue(notification.get("text")),
        stringValue(notification.get("kind")),
        stringValue(notification.get("icon")),
        state,
        current,
        total);
  }

  private static String stringValue(Object value) {
    return value instanceof String ? (String) value : null;
  }

  private static int intValue(Object value) {
    return value instanceof Integer ? (Integer) value : 0;
  }
}
