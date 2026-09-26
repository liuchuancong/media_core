import 'dart:async';

import 'package:flutter/painting.dart' show Rect;

/// System picture-in-picture state as reported by the platform.
///
/// Mirrors the platform vocabulary rather than collapsing it: [automatic]
/// means the system is allowed to shrink the app on its own, which is a
/// different state from [enabled] (already shrunk), and [unavailable] means
/// the device or the OS version cannot do it at all — a fact the driver needs
/// in order to refuse the request instead of silently doing nothing.
enum SystemPipStatus {
  /// The app is currently shrunk into the system picture-in-picture window.
  enabled,

  /// The app is not floating over other apps.
  disabled,

  /// The app will shrink once the user navigates away from it.
  automatic,

  /// The device cannot present system picture-in-picture.
  unavailable,
}

/// How the platform should be asked to shrink the app.
enum SystemPipTrigger {
  /// Shrink as soon as the request arrives — a tap on the app's own control.
  immediate,

  /// Shrink once the user navigates away from the app, without shrinking now.
  onLeaveApp,
}

/// Video region the platform should animate the PiP window out of.
///
/// Only a hint: a wrong rectangle costs animation polish, never correctness,
/// which is why every implementation must tolerate `null`.
final class SystemPipSourceRect {
  const SystemPipSourceRect({required this.left, required this.top, required this.width, required this.height});

  /// Builds a hint from a layout rectangle, dropping it when it carries no area.
  ///
  /// A zero-sized video widget is the normal case while a route is still
  /// laying out; passing it on would make the platform animate from a point.
  static SystemPipSourceRect? fromRect(Rect? rect) {
    if (rect == null || rect.width <= 0 || rect.height <= 0) {
      return null;
    }
    return SystemPipSourceRect(
      left: rect.left.round(),
      top: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
    );
  }

  final int left;
  final int top;
  final int width;
  final int height;

  @override
  String toString() => 'SystemPipSourceRect($left,$top ${width}x$height)';
}

/// Platform picture-in-picture API.
///
/// This is the seam the mobile driver talks to. It exists so the driver's
/// sequencing, aspect-ratio policy and failure handling can be tested without
/// a device, and so a host can supply a different implementation (a plugin
/// fork, a test double, or a platform the package does not ship yet).
///
/// Responsibilities:
///
/// - report availability and current state
/// - request entering picture-in-picture
/// - stream state changes, including ones the system made on its own
///
/// It does not:
///
/// - decide when picture-in-picture should be entered
/// - restore the app's UI when picture-in-picture ends
/// - exit picture-in-picture on request
///
/// The last point is a platform property, not an omission: Android and iOS end
/// picture-in-picture when the user returns to the app or closes the window,
/// and expose no API for the app to do it on its own. Implementations
/// therefore have no `disable`/`exit` member, and callers observe
/// [statusStream] instead of commanding an exit.
abstract interface class SystemPip {
  /// Whether the current device and OS version can present picture-in-picture.
  Future<bool> get isAvailable;

  /// Current state.
  Future<SystemPipStatus> get status;

  /// State changes, including system-initiated ones.
  Stream<SystemPipStatus> get statusStream;

  /// Requests picture-in-picture with the given video size.
  ///
  /// [width] and [height] describe the media, not the window: the platform
  /// uses their ratio. Implementations that cannot honor a ratio must fall
  /// back to a platform default rather than fail the transition.
  ///
  /// [trigger] decides whether the app shrinks now or on the next navigation
  /// away from it; an implementation whose platform only supports one of the
  /// two must treat the other as [SystemPipTrigger.immediate] rather than
  /// refuse the request.
  ///
  /// Returns the state the platform reports after the request. A device that
  /// cannot present picture-in-picture returns [SystemPipStatus.unavailable]
  /// or throws; callers must handle both.
  Future<SystemPipStatus> enable({
    required int width,
    required int height,
    SystemPipSourceRect? sourceRect,
    SystemPipTrigger trigger,
  });

  /// Releases subscriptions and platform resources.
  Future<void> dispose();
}
