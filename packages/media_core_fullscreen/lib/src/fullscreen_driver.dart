import 'dart:async';

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_core/media_core.dart';

import 'fullscreen_config.dart';
import 'fullscreen_window.dart';
import 'window_manager_fullscreen_window.dart';

/// Which fullscreen variants the host can actually present.
enum FullscreenPlatform {
  /// Windows, macOS, Linux: system fullscreen is a window state.
  desktop,

  /// Android/iOS: there is no window to make fullscreen, so "fullscreen" means
  /// the host hides the system UI and fills the screen.
  mobile,

  /// Web and anything else.
  unsupported;

  /// Resolves this host's family.
  static FullscreenPlatform resolve() {
    // PlatformUtils is the core's single answer to "what am I running on";
    // re-deriving it here from Platform would let the two drift apart.
    if (kIsWeb) {
      return FullscreenPlatform.unsupported;
    }
    if (PlatformUtils.isDesktop) {
      return FullscreenPlatform.desktop;
    }
    if (PlatformUtils.isMobile) {
      return FullscreenPlatform.mobile;
    }
    return FullscreenPlatform.unsupported;
  }
}

/// Owns both fullscreen variants.
///
/// Responsibilities:
///
/// - enter and leave system fullscreen ([PresentationMode.fullscreen])
/// - track window-level fullscreen ([PresentationMode.windowFullscreen])
/// - answer which fit strategy the current video orientation wants
/// - keep the two variants mutually exclusive
///
/// It does not:
///
/// - draw the fullscreen layout (the host does)
/// - decide when to go fullscreen on rotation (the presentation policy does)
/// - own picture-in-picture or the small windows (separate packages do)
///
/// ## The two variants
///
/// [PresentationMode.fullscreen] is the platform's own fullscreen: a desktop
/// window covers the screen, a phone hides the system UI. It is a real platform
/// state, so it can fail and has to be restored on exit.
///
/// [PresentationMode.windowFullscreen] is the host's layout: the video fills
/// the application window while the window stays a window. Nothing platform
/// facing happens here, and the mode is tracked so that PiP, the small windows
/// and the host's own chrome all agree on what is being left when the mode
/// changes.
///
/// Because one driver owns both, it is also the place that guarantees they do
/// not overlap: entering window fullscreen while the system fullscreen is
/// active leaves the system one first. That hand-off cannot be delegated to the
/// driver chain, which only knows about *different* drivers.
///
/// ## Orientation
///
/// Mobile "fullscreen" is not one layout per platform but one per orientation:
/// portrait media fills a portrait screen, landscape media takes the long axis,
/// and a portrait stream on a landscape screen is either letterboxed or
/// rotated. The driver answers that question through [strategyFor] so a host
/// does not re-derive it, and configures it through [FullscreenConfig].
final class FullscreenDriver implements KernelPresentationDriver {
  /// Creates the driver.
  FullscreenDriver({
    this.config = FullscreenConfig.defaults,
    FullscreenPlatform? platform,
    FullscreenWindow? desktopWindow,
  }) : platform = platform ?? FullscreenPlatform.resolve(),
       _desktopWindow = desktopWindow;

  /// Tunables, including the per-orientation fit strategies.
  final FullscreenConfig config;

  /// Platform family this driver serves.
  final FullscreenPlatform platform;

  FullscreenWindow? _desktopWindow;

  final StreamController<bool> _fullscreenChanges = StreamController<bool>.broadcast();

  Rect? _preFullscreenBounds;

  bool _initialized = false;
  bool _disposed = false;
  bool _isSystemFullscreen = false;
  bool _isWindowFullscreen = false;
  int _videoWidth = 0;
  int _videoHeight = 0;

  /// Whether this driver has been initialized.
  bool get initialized => _initialized;

  /// Whether system fullscreen is active.
  bool get isSystemFullscreen => _isSystemFullscreen;

  /// Whether window-level fullscreen is active.
  bool get isWindowFullscreen => _isWindowFullscreen;

  /// Whether either variant is active.
  bool get isAnyFullscreen => _isSystemFullscreen || _isWindowFullscreen;

  /// Fullscreen state changes (either variant).
  Stream<bool> get onFullscreenChanged => _fullscreenChanges.stream;

  /// Orientation of the last reported video size.
  VideoOrientation get orientation {
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      return config.fallbackOrientation;
    }
    return VideoOrientation.fromSize(_videoWidth, _videoHeight);
  }

  /// The fit strategy the current orientation wants.
  ///
  /// A host applies this to its fullscreen surface; the driver does not, since
  /// only the host knows what it is drawing into.
  FullscreenFitStrategy get strategy {
    final current = orientation;
    if (current == VideoOrientation.portrait) {
      return config.portraitStrategy;
    }
    return config.landscapeStrategy;
  }

  /// Initializes the driver.
  ///
  /// Call once, early. Safe to call again.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
  }

  /// Feeds the latest video size, used to pick the fit strategy.
  void onVideoSize(int width, int height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    _videoWidth = width;
    _videoHeight = height;
  }

  @override
  Future<void> apply(PlayerId playerId, PresentationRequest request) async {
    if (_disposed) {
      throw StateError('FullscreenDriver has been disposed.');
    }

    final wasAnyFullscreen = isAnyFullscreen;

    switch (request.mode) {
      case PresentationMode.fullscreen:
        await _enterSystemFullscreen();
      case PresentationMode.windowFullscreen:
        await _enterWindowFullscreen();
      case PresentationMode.normal:
        await _leaveFullscreen();
      case PresentationMode.pip:
      case PresentationMode.floating:
        throw UnsupportedError(
          'FullscreenDriver serves the two fullscreen variants only; mode "${request.mode.name}" '
          'belongs to another driver (see PresentationDriverChain).',
        );
    }

    _notifyIfChanged(wasAnyFullscreen);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    // Leaving the platform state behind on dispose would strand a desktop
    // window in fullscreen after the host has torn the player down.
    final wasAnyFullscreen = isAnyFullscreen;
    if (_isSystemFullscreen) {
      await _leaveSystemFullscreen();
    }
    _isWindowFullscreen = false;
    _notifyIfChanged(wasAnyFullscreen);

    await _fullscreenChanges.close();
  }

  // ---------------------------------------------------------------------------
  // Variants
  // ---------------------------------------------------------------------------

  Future<void> _enterSystemFullscreen() async {
    // The two variants are mutually exclusive, and this driver owns both, so
    // the hand-off happens here rather than in the chain.
    if (_isWindowFullscreen) {
      _setWindowFullscreen(false);
    }
    if (_isSystemFullscreen) {
      return;
    }

    switch (platform) {
      case FullscreenPlatform.desktop:
        final window = _desktopWindow ??= WindowManagerFullscreenWindow();
        if (config.restorePreviousBounds) {
          _preFullscreenBounds = await window.captureBounds();
        }
        await window.setFullscreen(true);
      case FullscreenPlatform.mobile:
        // No window to resize and no API to call: on mobile the host hides the
        // system UI. The mode is still tracked so the other features can leave
        // it, and so the host can render the right chrome.
        break;
      case FullscreenPlatform.unsupported:
        throw UnsupportedError('System fullscreen is not supported on this platform.');
    }

    _setSystemFullscreen(true);
  }

  Future<void> _enterWindowFullscreen() async {
    if (_isWindowFullscreen) {
      return;
    }

    if (platform == FullscreenPlatform.unsupported) {
      throw UnsupportedError('Window-level fullscreen is not supported on this platform.');
    }

    // Filling the window while the screen is also fullscreen would leave the
    // host with two active variants and no defined exit.
    if (_isSystemFullscreen) {
      await _leaveSystemFullscreen();
    }

    _setWindowFullscreen(true);
  }

  Future<void> _leaveFullscreen() async {
    if (_isSystemFullscreen) {
      await _leaveSystemFullscreen();
    }
    if (_isWindowFullscreen) {
      _setWindowFullscreen(false);
    }
  }

  Future<void> _leaveSystemFullscreen() async {
    if (platform == FullscreenPlatform.desktop) {
      final window = _desktopWindow ??= WindowManagerFullscreenWindow();
      await window.setFullscreen(false, restoreBounds: config.restorePreviousBounds ? _preFullscreenBounds : null);
    }
    _preFullscreenBounds = null;
    _setSystemFullscreen(false);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  void _setSystemFullscreen(bool value) {
    _isSystemFullscreen = value;
  }

  void _setWindowFullscreen(bool value) {
    _isWindowFullscreen = value;
  }

  /// Publishes the final value once per transition.
  ///
  /// Handing over between the two variants passes through a moment where
  /// neither is set. Publishing each flag change would emit that moment as a
  /// `false`, and a host reacting to it would flash its non-fullscreen chrome
  /// mid-transition — so only the settled value is reported.
  void _notifyIfChanged(bool previous) {
    final current = isAnyFullscreen;
    if (previous == current || _fullscreenChanges.isClosed) {
      return;
    }
    _fullscreenChanges.add(current);
  }
}
