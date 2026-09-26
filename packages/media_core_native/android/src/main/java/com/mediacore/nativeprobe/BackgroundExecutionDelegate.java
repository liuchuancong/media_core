package com.mediacore.nativeprobe;

import android.content.Context;

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
 * | Dart → host | {@code acquire} | {title, text, wakeLock} | session id, or null when the platform refused |
 * | Dart → host | {@code release} | {id} | – |
 *
 * <p>No {@code isSupported} call: the platform name is known in Dart, and a
 * round trip to answer "am I Android" would only be a way to disagree with it.
 *
 * <p>A refused acquire is answered with null rather than an error: the caller
 * runs the job unprotected, which is better than failing a recording because
 * the user declined a notification.
 */
final class BackgroundExecutionDelegate implements MethodChannel.MethodCallHandler {

  /** Channel name; kept in sync with the Dart side. */
  static final String CHANNEL_NAME = "media_core_native/background";

  private final Context context;

  BackgroundExecutionDelegate(Context context) {
    this.context = context;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "acquire":
        final String title = call.argument("title");
        final String text = call.argument("text");
        final Boolean wakeLock = call.argument("wakeLock");

        final int sessionId =
            BackgroundExecutionService.start(
                context,
                title == null ? "Running" : title,
                text,
                wakeLock != null && wakeLock);

        result.success(sessionId < 0 ? null : sessionId);

        break;

      case "release":
        final Integer id = call.argument("id");

        if (id != null && id >= 0) {
          BackgroundExecutionService.stop(context, id);
        }

        result.success(null);

        break;

      default:
        result.notImplemented();
    }
  }
}
