import 'dart:async';

import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_core/media_core.dart';

import 'floating_system_pip.dart';
import 'pip_config.dart';
import 'pip_window.dart';
import 'system_pip.dart';
import 'window_manager_pip_window.dart';

/// Which platform family the driver is running on.
///
/// Resolved from the OS, but injectable so the two paths can be exercised
/// without a device: the mobile path is the one that cannot be reached on a
/// desktop test host, and it is also the one with the more subtle contract.
enum PipPlatform {
  /// Windows, macOS, Linux: the small window is a real window.
  desktop,

  /// Android/iOS: the small window is the system picture-in-picture window.
  mobile,

  /// Web and anything else: picture-in-picture is not served here.
  unsupported;

  /// Resolves this host's family.
  static PipPlatform resolve() {
    // PlatformUtils is the core's single answer to "what am I running on";
    // re-deriving it here from Platform would let the two drift apart.
    if (kIsWeb) {
      return PipPlatform.unsupported;
    }
    if (PlatformUtils.isDesktop) {
      return PipPlatform.desktop;
    }
    if (PlatformUtils.isMobile) {
      return PipPlatform.mobile;
    }
    return PipPlatform.unsupported;
  }
}

/// Owns the picture-in-picture mode.
///
/// Responsibilities:
///
/// - enter and leave picture-in-picture for one player
/// - size the small window from the video's shape
/// - keep [isPip] truthful, including when the system ends PiP on its own
///
/// It does not:
///
/// - decide when picture-in-picture is appropriate
/// - own fullscreen or the in-app small window (separate packages own those)
/// - restore the host's UI after PiP ends
///
/// ## Desktop vs mobile
///
/// On desktop the feature is a window the app fully controls: capture the
/// window state, shrink it into a corner, restore on the way out.
///
/// On mobile the feature is the platform's own PiP window. Three platform facts
/// shape that path, and none of them are worked around here:
///
/// - picture-in-picture can be **requested** but not exited from the app, so
///   `normal` cannot undo it; the state follows the system's own status stream;
/// - Android accepts only aspect ratios inside 1/2.39..2.39, so an extreme
///   video falls back to the platform default rather than failing the request;
/// - the plugin is Android-only, so iOS reports unavailable instead of
///   pretending.
///
/// A request the platform cannot serve throws [UnsupportedError] rather than
/// silently doing nothing: the presentation state machine records a failed
/// transition, and the host can tell the viewer why nothing happened.
final class PipDriver implements KernelPresentationDriver {
  /// Creates the driver.
  PipDriver({
    this.config = PipConfig.defaults,
    PipPlatform? platform,
    PipWindow? desktopWindow,
    SystemPip? systemPip,
  }) : platform = platform ?? PipPlatform.resolve(),
       _desktopWindow = desktopWindow,
       _systemPip = systemPip;

  /// Tunables.
  final PipConfig config;

  /// Platform family this driver serves.
  final PipPlatform platform;

  PipWindow? _desktopWindow;
  SystemPip? _systemPip;

  final StreamController<bool> _pipChanges = StreamController<bool>.broadcast();

  StreamSubscription<SystemPipStatus>? _statusSubscription;
  PipWindowSnapshot? _desktopSnapshot;

  bool _initialized = false;
  bool _disposed = false;
  bool _isPip = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  Rect? _videoRect;

  /// Whether this driver has been initialized.
  bool get initialized => _initialized;

  /// Whether the app is currently in picture-in-picture.
  bool get isPip => _isPip;

  /// Picture-in-picture state changes, including system-initiated ones.
  Stream<bool> get onPipChanged => _pipChanges.stream;

  /// Whether picture-in-picture can be entered at all on this host.
  ///
  /// Async on mobile (the platform answers), synchronous on desktop (a window
  /// can always be shrunk), false where the feature is unsupported.
  Future<bool> get isAvailable async {
    switch (platform) {
      case PipPlatform.desktop:
        return true;
      case PipPlatform.mobile:
        return await _systemPip?.isAvailable ?? false;
      case PipPlatform.unsupported:
        return false;
    }
  }

  /// Initializes the driver and starts observing platform PiP state.
  ///
  /// Call once, early. Safe to call again.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;

    if (platform != PipPlatform.mobile) {
      return;
    }

    final pip = _systemPip ??= FloatingSystemPip();
    try {
      _statusSubscription = pip.statusStream.listen(_handleSystemStatus, onError: (_) {});
    } catch (_) {
      // A platform without the plugin throws when the stream is created rather
      // than reporting unavailability; the driver stays usable either way.
    }
  }

  /// Feeds the latest video size, used for the small window's shape.
  void onVideoSize(int width, int height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    _videoWidth = width;
    _videoHeight = height;
  }

  /// Feeds the video widget's rectangle, used as the mobile source hint.
  void onVideoRect(Rect? rect) {
    _videoRect = rect;
  }

  @override
  Future<void> apply(PlayerId playerId, PresentationRequest request) async {
    if (_disposed) {
      throw StateError('PipDriver has been disposed.');
    }

    switch (request.mode) {
      case PresentationMode.pip:
        await _enterPip();
      case PresentationMode.normal:
        await _leavePip();
      case PresentationMode.fullscreen:
      case PresentationMode.windowFullscreen:
      case PresentationMode.floating:
        throw UnsupportedError(
          'PipDriver serves picture-in-picture only; mode "${request.mode.name}" '
          'belongs to another driver (see PresentationDriverChain).',
        );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _statusSubscription?.cancel();
    _statusSubscription = null;

    await _systemPip?.dispose();

    _isPip = false;
    await _pipChanges.close();
  }

  // ---------------------------------------------------------------------------
  // Entering and leaving
  // ---------------------------------------------------------------------------

  Future<void> _enterPip() async {
    if (_isPip) {
      return;
    }

    switch (platform) {
      case PipPlatform.desktop:
        await _enterDesktopPip();
      case PipPlatform.mobile:
        await _enterMobilePip();
      case PipPlatform.unsupported:
        throw UnsupportedError('Picture-in-picture is not supported on this platform.');
    }
  }

  Future<void> _leavePip() async {
    if (!_isPip) {
      return;
    }

    if (platform == PipPlatform.desktop) {
      final snapshot = _desktopSnapshot;
      if (snapshot != null && config.restoreWindowOnExit) {
        await _desktopWindow?.restore(snapshot);
      }
      _desktopSnapshot = null;
      _setPip(false);
      return;
    }

    // Mobile: the app cannot end the system PiP window. The platform ends it
    // when the viewer returns to the app or closes the window, and
    // `_handleSystemStatus` reports that. Claiming an exit here would make the
    // state machine believe a window is gone while it is still on screen.
    if (platform == PipPlatform.unsupported) {
      _setPip(false);
    }
  }

  Future<void> _enterDesktopPip() async {
    final window = _desktopWindow ??= WindowManagerPipWindow();

    final snapshot = await window.capture();
    _desktopSnapshot = snapshot;

    final size = _smallWindowSize();
    final anchor = snapshot.bounds;

    await window.applySmallWindow(
      size: size,
      // Bottom-right corner of the previous bounds, clawed back from the
      // screen edge so the window does not sit flush against it.
      position: Offset(
        (anchor.right - size.width - config.cornerSpacing).clamp(0, double.infinity),
        (anchor.bottom - size.height - config.cornerSpacing).clamp(0, double.infinity),
      ),
      aspectRatio: config.lockAspectRatio ? _aspectRatio() : null,
      alwaysOnTop: true,
      resizable: false,
      skipTaskbar: config.skipTaskbar,
      title: config.title,
    );

    _setPip(true);
  }

  Future<void> _enterMobilePip() async {
    final pip = _systemPip;
    if (pip == null) {
      throw UnsupportedError('No system picture-in-picture implementation is installed.');
    }
    if (!await pip.isAvailable) {
      throw UnsupportedError('System picture-in-picture is not available on this device.');
    }
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      throw StateError('Picture-in-picture needs a video size. Call onVideoSize() first.');
    }

    final status = await pip.enable(
      width: _videoWidth,
      height: _videoHeight,
      sourceRect: config.requestSourceRectHint ? SystemPipSourceRect.fromRect(_videoRect) : null,
    );

    if (status == SystemPipStatus.unavailable) {
      throw UnsupportedError('The platform refused to enter picture-in-picture.');
    }

    _handleSystemStatus(status);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  void _handleSystemStatus(SystemPipStatus status) {
    final active = status == SystemPipStatus.enabled || status == SystemPipStatus.automatic;
    _setPip(active);
  }

  void _setPip(bool value) {
    if (value == _isPip) {
      return;
    }
    _isPip = value;
    if (!_pipChanges.isClosed) {
      _pipChanges.add(value);
    }
  }

  /// Small window size, following the video's orientation.
  ///
  /// The configured [PipConfig.width] is the window's *long* side in both
  /// cases and [PipConfig.height] the short one, so a landscape stream gets a
  /// 320x180 window and a portrait stream a 180x320 one. Keeping one dimension
  /// fixed in each direction is what makes the small window read as the same
  /// size regardless of the video's shape; deriving the short side from
  /// `height` instead would shrink portrait windows to a sliver.
  ///
  /// An unknown video size falls back to the configured pair unchanged.
  Size _smallWindowSize() {
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      return Size(config.width, config.height);
    }

    final orientation = VideoOrientation.fromSize(_videoWidth, _videoHeight);
    if (orientation == VideoOrientation.landscape) {
      final ratio = _videoWidth / _videoHeight;
      return Size(config.width, (config.width / ratio).roundToDouble());
    }
    if (orientation == VideoOrientation.portrait) {
      final ratio = _videoHeight / _videoWidth;
      return Size((config.width / ratio).roundToDouble(), config.width);
    }
    return Size(config.width, config.height);
  }

  /// Aspect ratio to lock the desktop window to, or null when unknown.
  double? _aspectRatio() {
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      return null;
    }
    return _videoWidth / _videoHeight;
  }
}
