import 'dart:math' show Rectangle;

import 'package:floating/floating.dart';

import 'system_pip.dart';

/// [SystemPip] backed by the `floating` plugin.
///
/// The plugin implements Android only (its own documentation states other
/// platforms are not planned), so on iOS every member here answers
/// "unavailable" rather than pretending the request can be served.
///
/// Two platform details shape this implementation:
///
/// - **Aspect ratio bounds.** Android accepts ratios between 1/2.39 and 2.39
///   and throws for anything outside, so a ratio that does not fit is replaced
///   by the plugin default instead of failing the transition. The ratio only
///   affects the shape of the small window; losing it is cosmetic, losing the
///   transition is not.
/// - **No exit call.** The plugin exposes no way to leave picture-in-picture
///   from Dart, because the platform has none: the user returns to the app or
///   closes the window. State is therefore observed through [statusStream].
final class FloatingSystemPip implements SystemPip {
  /// Creates the implementation.
  ///
  /// [floating] exists for tests and for hosts that already own a plugin
  /// instance; production callers omit it and the plugin singleton is used.
  FloatingSystemPip({Floating? floating}) : _floating = floating ?? Floating();

  final Floating _floating;

  bool _disposed = false;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _floating.isPipAvailable;
    } catch (_) {
      // A platform that has no picture-in-picture support at all reports it
      // by throwing on the channel rather than by answering false.
      return false;
    }
  }

  @override
  Future<SystemPipStatus> get status async {
    try {
      return _map(await _floating.pipStatus);
    } catch (_) {
      return SystemPipStatus.unavailable;
    }
  }

  @override
  Stream<SystemPipStatus> get statusStream {
    try {
      return _floating.pipStatusStream.map(_map);
    } catch (_) {
      return const Stream<SystemPipStatus>.empty();
    }
  }

  @override
  Future<SystemPipStatus> enable({
    required int width,
    required int height,
    SystemPipSourceRect? sourceRect,
    SystemPipTrigger trigger = SystemPipTrigger.immediate,
  }) async {
    if (_disposed) {
      throw StateError('FloatingSystemPip has been disposed.');
    }
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Picture-in-picture needs a positive video size, got ${width}x$height.');
    }

    final aspectRatio = _aspectRatio(width, height);
    final hint = sourceRect == null
        ? null
        : Rectangle<int>(sourceRect.left, sourceRect.top, sourceRect.width, sourceRect.height);

    // The plugin models the two triggers as separate argument types, which is
    // also how the platform sees them: `ImmediatePiP` shrinks now, `OnLeavePiP`
    // arms the next navigation away.
    final arguments = switch (trigger) {
      SystemPipTrigger.immediate => ImmediatePiP(aspectRatio: aspectRatio, sourceRectHint: hint),
      SystemPipTrigger.onLeaveApp => OnLeavePiP(aspectRatio: aspectRatio, sourceRectHint: hint),
    };

    return _map(await _floating.enable(arguments));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    // Releases the platform listener without changing the current mode: the
    // app may still be shrunk, and the system ends that on its own.
    await _floating.cancelOnLeavePiP();
  }

  /// Keeps the requested ratio inside Android's accepted band.
  ///
  /// The band is inclusive (1/2.39 .. 2.39); anything wider or taller falls
  /// back to the plugin default so the platform still enters picture-in-picture.
  Rational _aspectRatio(int width, int height) {
    const minRatio = 1 / 2.39;
    const maxRatio = 2.39;
    final ratio = width / height;
    if (ratio < minRatio || ratio > maxRatio) {
      return const Rational.landscape();
    }
    return Rational(width, height);
  }

  SystemPipStatus _map(PiPStatus status) {
    return switch (status) {
      PiPStatus.enabled => SystemPipStatus.enabled,
      PiPStatus.disabled => SystemPipStatus.disabled,
      PiPStatus.automatic => SystemPipStatus.automatic,
      PiPStatus.unavailable => SystemPipStatus.unavailable,
    };
  }
}
