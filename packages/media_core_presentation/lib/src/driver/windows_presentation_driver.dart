import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_presentation/media_core_presentation.dart' show MediaCorePresentation;
import 'package:media_core_presentation/src/geometry/presentation_capability_config.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop presentation driver backed by window_manager's nativeapi `Window`.
///
/// **Superseded.** The modes this driver bundles now have dedicated packages -
/// `media_core_fullscreen` and `media_core_pip` - composed through
/// `PresentationDriverChain`. This class is kept for consumers that already
/// depend on it and is not extended with new modes.
///
/// Works on Windows (primary target), macOS and Linux where
/// window_manager is available.
///
/// Implements the [KernelPresentationDriver] contract:
///
/// - fullscreen: `window.isFullScreen = true` with the pre-fullscreen
///   window bounds remembered for restore
/// - pip: an always-on-top, non-resizable, aspect-locked small
///   window sized from the video orientation — landscape video
///   gets a wide window, portrait video gets a tall one
/// - floating: same always-on-top window without aspect lock
///
/// Video-orientation awareness: the driver is fed the video size
/// through [onVideoSize] (wired automatically by
/// [MediaCorePresentation] from adapter events), so PiP sizing
/// matches the actual media.
///
/// The nativeapi API is synchronous FFI: every transition resolves the
/// current window once and applies state directly. A missing desktop window
/// (widget tests, mobile) makes the whole transition a no-op.
final class WindowManagerPresentationDriver implements KernelPresentationDriver {
  /// Creates the driver.
  WindowManagerPresentationDriver({this.config = const PresentationCapabilityConfig()});

  /// Capability configuration.
  final PresentationCapabilityConfig config;

  bool _initialized = false;
  bool _disposed = false;
  bool _isFullscreen = false;
  bool _isPip = false;

  // Window state remembered before a transition, for restore.
  bool _wasAlwaysOnTop = false;
  bool _wasResizable = true;
  bool _wasSkipTaskbar = false;
  String? _previousTitle;
  Rect? _preFullscreenBounds;
  Rect? _prePipBounds;

  (int, int)? _latestVideoSize;

  /// Whether this driver has been initialized.
  bool get initialized => _initialized;

  /// Current fullscreen state of the window.
  bool get isFullscreen => _isFullscreen;

  /// Current picture-in-picture state of the window.
  bool get isPip => _isPip;

  /// Whether this driver's platform is supported.
  static bool get supportsPlatform => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Marks the driver ready.
  ///
  /// The nativeapi API needs no explicit initialization; this only gates
  /// [apply] so callers keep their "initialize once, then present" flow.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
  }

  @override
  Future<void> apply(PlayerId playerId, PresentationRequest request) async {
    if (_disposed) {
      throw StateError('WindowManagerPresentationDriver has been disposed.');
    }
    if (!_initialized) {
      throw StateError('WindowManagerPresentationDriver is not initialized. Call initialize() first.');
    }

    switch (request.mode) {
      case PresentationMode.normal:
        await _exitPip();
        await _exitFullscreen();
      case PresentationMode.fullscreen:
      case PresentationMode.windowFullscreen:
        // This composite driver predates the split into per-feature packages and
        // cannot draw window-level fullscreen (that is the host's layout); it
        // treats both variants as system fullscreen. New code should use
        // media_core_fullscreen.
        await _exitPip();
        await _enterFullscreen();
      case PresentationMode.pip:
        await _exitFullscreen();
        await _enterPip(lockAspectRatio: true);
      case PresentationMode.floating:
        await _exitFullscreen();
        await _enterPip(lockAspectRatio: false);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  /// Feeds the latest video size, used for PiP sizing.
  ///
  /// Wired automatically by [MediaCorePresentation] from the
  /// adapter `videoSizeChanged` events.
  void onVideoSize(int width, int height) {
    _latestVideoSize = (width, height);
  }

  // ---------------------------------------------------------------------------
  // Fullscreen
  // ---------------------------------------------------------------------------

  Future<void> _enterFullscreen() async {
    if (_isFullscreen) {
      return;
    }

    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return;
    }
    _preFullscreenBounds = window.bounds.toRect();

    window.isFullScreen = true;
    _isFullscreen = true;
  }

  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) {
      return;
    }

    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      _isFullscreen = false;
      return;
    }
    window.isFullScreen = false;
    _isFullscreen = false;

    final bounds = _preFullscreenBounds;
    if (bounds != null) {
      window.bounds = bounds.toNative();
      _preFullscreenBounds = null;
    }
  }

  // ---------------------------------------------------------------------------
  // PiP / floating
  // ---------------------------------------------------------------------------

  Future<void> _enterPip({required bool lockAspectRatio}) async {
    if (_isPip) {
      return;
    }

    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return;
    }

    _wasAlwaysOnTop = window.isAlwaysOnTop;
    _wasResizable = window.isResizable;
    _wasSkipTaskbar = !window.isVisibleInTaskbar;
    _previousTitle = window.title;
    _prePipBounds = window.bounds.toRect();

    final videoSize = _latestVideoSize;
    final orientation = VideoOrientation.fromSize(videoSize?.$1 ?? 0, videoSize?.$2 ?? 0);

    // Size the small window from the video orientation:
    // landscape → wide window, portrait → tall window.
    final Size pipSize;
    if (orientation.isLandscape && videoSize != null) {
      final ratio = videoSize.$1 / videoSize.$2;
      pipSize = Size(config.pipWidth, (config.pipWidth / ratio).roundToDouble());
    } else if (orientation.isPortrait && videoSize != null) {
      final ratio = videoSize.$2 / videoSize.$1;
      pipSize = Size((config.pipHeight / ratio).roundToDouble(), config.pipHeight);
    } else {
      pipSize = Size(config.pipWidth, config.pipHeight);
    }

    window
      ..title = config.pipTitle
      ..isAlwaysOnTop = true
      ..isResizable = false;
    if (lockAspectRatio) {
      window.aspectRatio = pipSize.width / pipSize.height;
    }

    // Bottom-right corner of the previous window bounds, clamped
    // to stay on the same monitor.
    final anchor = _prePipBounds ?? const Rect.fromLTWH(0, 0, 1920, 1080);
    final pipPosition = Offset(
      (anchor.right - pipSize.width - config.pipCornerSpacing).clamp(0, double.infinity),
      (anchor.bottom - pipSize.height - config.pipCornerSpacing).clamp(0, double.infinity),
    );

    window
      ..setSize(pipSize.toNative(), false)
      ..position = pipPosition.toNative();
    if (config.pipSkipTaskbar) {
      window.isVisibleInTaskbar = false;
    }

    _isPip = true;
  }

  Future<void> _exitPip() async {
    if (!_isPip) {
      return;
    }

    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window
        ..isAlwaysOnTop = _wasAlwaysOnTop
        ..isResizable = _wasResizable;
      if (config.pipSkipTaskbar) {
        window.isVisibleInTaskbar = !_wasSkipTaskbar;
      }
      if (_previousTitle != null) {
        window.title = _previousTitle!;
      }

      final bounds = _prePipBounds;
      if (config.exitPipRestoresWindow && bounds != null) {
        window.bounds = bounds.toNative();
      }
    }

    _isPip = false;
    _prePipBounds = null;
  }
}
