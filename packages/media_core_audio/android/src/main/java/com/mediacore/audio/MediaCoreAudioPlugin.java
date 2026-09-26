package com.mediacore.audio;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Android side of {@code media_core_audio}'s desktop-lyric overlay.
 *
 * Wire protocol (see {@code MethodChannelDesktopLyricTransport} on the Dart
 * side, which is the source of truth):
 *
 * | direction | method | arguments | result |
 * |---|---|---|---|
 * | Dart → host | {@code isSupported} | – | true |
 * | Dart → host | {@code show} | – | whether the window is on screen |
 * | Dart → host | {@code hide} | – | – |
 * | Dart → host | {@code update} | state map | – |
 * | Dart → host | {@code setBounds} | {x, y, width, height} | – |
 * | host → Dart | {@code action} | {action: previous/toggle/next/close/lock/unlock} | – |
 *
 * The plugin owns no playback state: it draws what it is told and reports which
 * button was pressed.
 */
public final class MediaCoreAudioPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

  /** Channel name; kept in sync with the Dart transport. */
  private static final String CHANNEL_NAME = "media_core_audio/desktop_lyric";

  /** Channel back to Dart. Static because the overlay outlives one engine binding. */
  private static MethodChannel channel;

  private DesktopLyricWindow window;

  /** Runtime permissions; needs the activity, forwarded through ActivityAware. */
  private AudioPermissionsDelegate permissions;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(this);

    permissions = new AudioPermissionsDelegate(binding.getApplicationContext());
    permissions.attach(binding.getBinaryMessenger());

    window = new DesktopLyricWindow(
        binding.getApplicationContext(),
        new DesktopLyricWindow.ActionSink() {
          @Override
          public void onAction(String action) {
            sendAction(action);
          }
        });
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (permissions != null) {
      permissions.detach();
      permissions = null;
    }

    if (window != null) {
      window.dispose();
      window = null;
    }

    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Activity awareness (forwarded to the permissions delegate)
  // ---------------------------------------------------------------------------

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    if (permissions != null) {
      permissions.onAttachedToActivity(binding);
    }
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    if (permissions != null) {
      permissions.onDetachedFromActivityForConfigChanges();
    }
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    if (permissions != null) {
      permissions.onReattachedToActivityForConfigChanges(binding);
    }
  }

  @Override
  public void onDetachedFromActivity() {
    if (permissions != null) {
      permissions.onDetachedFromActivity();
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    final DesktopLyricWindow lyricWindow = window;

    if (lyricWindow == null) {
      // A call after the engine detached (a hot restart race): report "no
      // overlay" instead of crashing the host.
      if ("show".equals(call.method)) {
        result.success(false);
      } else if ("isSupported".equals(call.method)) {
        result.success(false);
      } else {
        result.success(null);
      }

      return;
    }

    switch (call.method) {
      case "isSupported":
        result.success(lyricWindow.isSupported());
        break;

      case "show":
        // Requests the overlay permission on the first call and returns false;
        // the host offers the feature again once the user is back.
        result.success(lyricWindow.show());
        break;

      case "hide":
        lyricWindow.hide();
        result.success(null);
        break;

      case "update":
        lyricWindow.update(call.arguments);
        result.success(null);
        break;

      case "setBounds":
        lyricWindow.setBounds(call.arguments);
        result.success(null);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * Sends a button press back to Dart.
   *
   * Called from the overlay's click listeners, which run on the main thread —
   * the same thread the channel requires.
   */
  private void sendAction(String action) {
    final MethodChannel target = channel;

    if (target == null) {
      return;
    }

    final Map<String, Object> arguments = new HashMap<>();
    arguments.put("action", action);

    target.invokeMethod("action", arguments);
  }
}
