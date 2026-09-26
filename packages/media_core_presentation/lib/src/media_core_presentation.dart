import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:media_core/media_core.dart';

import 'presentation_capability_config.dart';
import 'windows_presentation_driver.dart';

/// Presentation capability driver for the media_core kernel.
///
/// [MediaCorePresentation] implements [KernelPresentationDriver]
/// and delegates to a platform implementation:
///
/// ```text
/// Windows / macOS / Linux → WindowManagerPresentationDriver
///                           (fullscreen + always-on-top PiP)
/// Android / iOS / other   → throws on apply
///                           (use media_core_presentation_mobile there:
///                            system PiP + a host-owned small window)
/// ```
///
/// It also tracks the active video orientation from adapter
/// events so both the driver and the overlay widgets react to
/// landscape/portrait media correctly.
///
/// Usage:
///
/// ```dart
/// final presentation = MediaCorePresentation();
/// await presentation.initialize();
/// kernel.attachPresentation(presentation);
///
/// await kernel.enterFullscreen(playerId);
/// await kernel.enterPip(playerId);          // Windows: small window
/// ```
final class MediaCorePresentation implements KernelPresentationDriver {
  /// Creates the driver.
  MediaCorePresentation({
    this.config = const PresentationCapabilityConfig(),
    WindowManagerPresentationDriver? desktopDriver,
  }) : _desktopDriver = desktopDriver;

  /// Capability configuration.
  final PresentationCapabilityConfig config;

  final WindowManagerPresentationDriver? _desktopDriver;

  StreamSubscription<PlayerEvent>? _eventSub;
  VideoOrientation _orientation = VideoOrientation.unknown;
  bool _disposed = false;

  WindowManagerPresentationDriver? _resolvedDesktop;

  /// Latest video orientation observed from adapter events.
  VideoOrientation get orientation => _orientation;

  /// Whether this platform serves PiP/floating requests.
  ///
  /// Desktop platforms serve them through an always-on-top
  /// window. Mobile platforms are served by
  /// `media_core_presentation_mobile` instead, not by this class.
  bool get supportsFloatingWindow => _desktop != null;

  /// Whether overlays should use hover show/hide on this device.
  ///
  /// True on desktop platforms (mouse available); false on
  /// touch-primary platforms where overlays are always visible.
  bool get overlayHoverMode {
    if (!config.overlayHoverMode) {
      return false;
    }
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
  }

  /// The desktop driver when on a supported platform.
  WindowManagerPresentationDriver? get _desktop {
    if (_resolvedDesktop != null) {
      return _resolvedDesktop;
    }
    if (!WindowManagerPresentationDriver.supportsPlatform) {
      return null;
    }
    return _desktopDriver ?? (_resolvedDesktop ??= WindowManagerPresentationDriver(config: config));
  }

  /// Initializes the platform driver.
  ///
  /// Call once early. No-op on unsupported platforms.
  Future<void> initialize() async {
    if (_disposed) {
      return;
    }
    await _desktop?.initialize();
  }

  // ---------------------------------------------------------------------------
  // Kernel wiring
  // ---------------------------------------------------------------------------

  /// Called by the kernel (or manually) to start observing video
  /// size events from [kernel]'s event bus.
  ///
  /// Video orientation feeds PiP window sizing and overlay
  /// layouts.
  void observeKernel(PlayerKernel kernel) {
    _eventSub?.cancel();
    _eventSub = kernel.events.listen((event) {
      final orientation = _orientationFromEvent(event);
      if (orientation == null) {
        return;
      }
      _orientation = orientation;
      _desktop?.onVideoSize(_lastWidth, _lastHeight);
    }, onError: (_) {});
  }

  int _lastWidth = 0;
  int _lastHeight = 0;

  VideoOrientation? _orientationFromEvent(PlayerEvent event) {
    if (event is! GenericPlayerEvent) {
      return null;
    }
    if (event.type != PlayerEventType.renderer) {
      return null;
    }
    final width = event.data['width'];
    final height = event.data['height'];
    if (width is! int || height is! int) {
      return null;
    }
    _lastWidth = width;
    _lastHeight = height;
    return VideoOrientation.fromSize(width, height);
  }

  // ---------------------------------------------------------------------------
  // KernelPresentationDriver
  // ---------------------------------------------------------------------------

  @override
  Future<void> apply(PlayerId playerId, PresentationRequest request) async {
    if (_disposed) {
      throw StateError('MediaCorePresentation has been disposed.');
    }

    final desktop = _desktop;
    if (desktop != null) {
      await desktop.apply(playerId, request);
      return;
    }

    throw UnsupportedError(
      'Presentation mode "${request.mode.name}" is not implemented on '
      '${Platform.operatingSystem}. This driver serves Windows/macOS/Linux '
      '(fullscreen and floating PiP windows); use media_core_presentation_mobile '
      'on Android/iOS.',
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _eventSub?.cancel();
    _eventSub = null;

    await _resolvedDesktop?.dispose();
    _resolvedDesktop = null;
  }
}
