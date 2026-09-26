package com.mediacore.audio;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import androidx.annotation.NonNull;

import java.util.Map;

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Android side of {@code media_core_audio}'s runtime permissions.
 *
 * Wire protocol — channel {@code media_core_audio/permissions}:
 *
 * | method | arguments | result |
 * |---|---|---|
 * | {@code isGranted} | {permission: <name>} | bool |
 * | {@code request} | {permission: <name>} | bool, after the round trip |
 *
 * Names come from the Dart {@code AudioPermission} enum. A permission that this
 * platform does not have resolves to true — the caller asked "may I?", and the
 * answer on a platform that never asks is yes.
 *
 * Two request styles live behind one API, because Android itself has two:
 *
 * - notification and media-library permissions are ordinary runtime
 *   permissions: a dialog, answered by {@code onRequestPermissionsResult};
 * - {@code SYSTEM_ALERT_WINDOW} has no dialog at all — it is granted on a system
 *   settings screen, so the request spans "open that screen, wait for the grant
 *   to land, answer". A short poll of {@code Settings.canDrawOverlays} is used
 *   rather than activity lifecycle plumbing: it needs no androidx lifecycle
 *   dependency, it answers the moment the user toggles the switch (even before
 *   they navigate back), and it stops on its own.
 */
final class AudioPermissionsDelegate
    implements MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

  static final String CHANNEL_NAME = "media_core_audio/permissions";

  /** How long the overlay grant is awaited before answering false. */
  private static final long OVERLAY_TIMEOUT_MILLIS = 60_000L;

  private static final long OVERLAY_POLL_MILLIS = 400L;

  private static final int REQUEST_CODE_NOTIFICATIONS = 0x4D01;
  private static final int REQUEST_CODE_MEDIA_LIBRARY = 0x4D02;

  private final Context context;
  private final Handler main = new Handler(Looper.getMainLooper());

  private MethodChannel channel;
  private Activity activity;

  /** Result waiting for {@code onRequestPermissionsResult}. */
  private MethodChannel.Result pendingDialogResult;
  private int pendingRequestCode = -1;

  /** Result waiting for the overlay grant to appear. */
  private MethodChannel.Result pendingOverlayResult;
  private boolean pollingOverlay;

  AudioPermissionsDelegate(Context context) {
    this.context = context;
  }

  // ---------------------------------------------------------------------------
  // Plugin wiring
  // ---------------------------------------------------------------------------

  void attach(BinaryMessenger messenger) {
    channel = new MethodChannel(messenger, CHANNEL_NAME);
    channel.setMethodCallHandler(this);
  }

  void detach() {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }

    completePending(false);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    final Map<?, ?> arguments = call.arguments instanceof Map ? (Map<?, ?>) call.arguments : null;
    final String name = arguments == null || arguments.get("permission") == null
        ? null
        : arguments.get("permission").toString();

    if (name == null) {
      result.error("invalid_argument", "Missing permission name.", null);

      return;
    }

    switch (call.method) {
      case "isGranted":
        result.success(isGranted(name));
        break;

      case "request":
        request(name, result);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Activity awareness
  // ---------------------------------------------------------------------------

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    binding.addRequestPermissionsResultListener(this);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;

    // A dialog or settings screen whose activity is gone can never answer:
    // resolve the waiting futures instead of leaving them hanging forever.
    completePending(false);
  }

  @Override
  public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
    if (requestCode != pendingRequestCode || pendingDialogResult == null) {
      return false;
    }

    boolean granted = grantResults.length > 0;

    for (final int value : grantResults) {
      granted = granted && value == PackageManager.PERMISSION_GRANTED;
    }

    completePending(granted);

    return true;
  }

  // ---------------------------------------------------------------------------
  // Permission logic
  // ---------------------------------------------------------------------------

  private boolean isGranted(String name) {
    if ("desktopLyricOverlay".equals(name)) {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        return true;
      }

      return Settings.canDrawOverlays(context);
    }

    final String platformPermission = platformPermissionFor(name);

    if (platformPermission == null) {
      // Not a permission of this platform.
      return true;
    }

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      // Install-time permissions only.
      return true;
    }

    return context.checkSelfPermission(platformPermission) == PackageManager.PERMISSION_GRANTED;
  }

  private void request(String name, MethodChannel.Result result) {
    if (isGranted(name)) {
      result.success(true);

      return;
    }

    if ("desktopLyricOverlay".equals(name)) {
      requestOverlay(result);

      return;
    }

    final String platformPermission = platformPermissionFor(name);
    final Activity current = activity;

    if (platformPermission == null || current == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      // Without an activity there is nobody to show a dialog; report the state
      // rather than answering optimistically.
      result.success(isGranted(name));

      return;
    }

    if (pendingDialogResult != null) {
      // One dialog at a time: the second request would arrive with no way to
      // tell the two answers apart.
      result.success(false);

      return;
    }

    pendingDialogResult = result;
    pendingRequestCode = "notifications".equals(name) ? REQUEST_CODE_NOTIFICATIONS : REQUEST_CODE_MEDIA_LIBRARY;

    try {
      current.requestPermissions(new String[] {platformPermission}, pendingRequestCode);
    } catch (RuntimeException error) {
      completePending(false);
    }
  }

  /**
   * Opens the overlay settings screen and answers once the grant is visible.
   *
   * {@code ACTION_MANAGE_OVERLAY_PERMISSION} has no result contract, which is
   * why the answer comes from re-reading {@link Settings#canDrawOverlays}.
   */
  private void requestOverlay(MethodChannel.Result result) {
    overlayDeadline = System.currentTimeMillis() + OVERLAY_TIMEOUT_MILLIS;

    try {
      final Intent intent = new Intent(
          Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
          Uri.parse("package:" + context.getPackageName()));
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      context.startActivity(intent);
    } catch (RuntimeException error) {
      // Some TV builds have no such settings screen.
      result.success(false);

      return;
    }

    if (pendingOverlayResult != null) {
      pendingOverlayResult.success(isGranted("desktopLyricOverlay"));
    }

    pendingOverlayResult = result;

    if (!pollingOverlay) {
      pollingOverlay = true;
      main.postDelayed(overlayPoll, OVERLAY_POLL_MILLIS);
    }
  }

  private final Runnable overlayPoll = new Runnable() {
    @Override
    public void run() {
      final MethodChannel.Result pending = pendingOverlayResult;

      if (pending == null) {
        pollingOverlay = false;

        return;
      }

      if (isGranted("desktopLyricOverlay")) {
        pollingOverlay = false;
        pendingOverlayResult = null;
        pending.success(true);

        return;
      }

      if (System.currentTimeMillis() > overlayDeadline) {
        pollingOverlay = false;
        overlayDeadline = 0L;
        pendingOverlayResult = null;
        pending.success(false);

        return;
      }

      main.postDelayed(this, OVERLAY_POLL_MILLIS);
    }
  };

  /** When the current overlay wait gives up; 0 while none is running. */
  private long overlayDeadline;

  private String platformPermissionFor(String name) {
    if ("notifications".equals(name)) {
      // Below API 33 notifications need no permission at all.
      return Build.VERSION.SDK_INT >= 33 ? "android.permission.POST_NOTIFICATIONS" : null;
    }

    if ("mediaLibrary".equals(name)) {
      return Build.VERSION.SDK_INT >= 33
          ? "android.permission.READ_MEDIA_AUDIO"
          : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    return null;
  }

  private void completePending(boolean granted) {
    final MethodChannel.Result result = pendingDialogResult;

    pendingDialogResult = null;
    pendingRequestCode = -1;

    if (result != null) {
      result.success(granted);
    }
  }
}

