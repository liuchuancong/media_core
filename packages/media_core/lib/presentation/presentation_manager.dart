import 'dart:async';
import 'presentation_mode.dart';
import 'presentation_state.dart';
import 'presentation_request.dart';
import 'presentation_snapshot.dart';
import 'presentation_controller.dart';
import 'presentation_capabilities.dart';

/// High level presentation manager.
///
/// Public facade for player presentation.
///
/// Responsibilities:
///
/// - expose presentation APIs
/// - provide unified presentation state
/// - provide snapshot
/// - simplify presentation operations
///
/// Does not:
///
/// - call platform APIs
/// - create windows
/// - control fullscreen system UI
/// - manage native lifecycle
///
/// Platform operations are handled by:
///
/// - PresentationAdapter
/// - platform implementations
final class PresentationManager {
  /// Creates presentation manager.
  PresentationManager({required PresentationController controller}) : _controller = controller {
    _subscription = _controller.state.listen((state) {
      _latestState = state;
    });
  }

  final PresentationController _controller;

  late final StreamSubscription<PresentationState> _subscription;

  PresentationState _latestState = PresentationState.initial();

  bool _disposed = false;

  /// Current presentation state stream.
  Stream<PresentationState> get state => _controller.state;

  /// Current presentation state.
  PresentationState get current => _latestState;

  /// Current presentation snapshot.
  PresentationSnapshot get snapshot {
    final state = _latestState;

    return PresentationSnapshot(
      mode: state.mode,
      capabilities: state.capabilities,
      transitioning: state.transitioning,
      enabled: state.enabled,
      generation: state.generation,
      error: state.error,
    );
  }

  /// Whether manager is disposed.
  bool get isDisposed => _disposed;

  /// Current presentation mode.
  PresentationMode get mode => _latestState.mode;

  /// Whether fullscreen active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether PiP active.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether floating active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether normal mode.
  bool get isNormal => mode == PresentationMode.normal;

  /// Whether presentation is transitioning.
  bool get isTransitioning => _latestState.transitioning;

  /// Whether presentation has error.
  bool get hasError => _latestState.hasError;

  /// Whether presentation is available.
  bool get available => _latestState.available;

  /// Requests presentation mode change.
  ///
  /// The real platform operation is executed
  /// by PresentationAdapter.
  Future<void> request(PresentationRequest request) {
    _ensureNotDisposed();

    return _controller.request(request);
  }

  /// Enters fullscreen.
  Future<void> enterFullscreen({bool animated = true, String? source}) {
    return request(PresentationRequest.fullscreen(animated: animated, source: source));
  }

  /// Enters picture-in-picture.
  Future<void> enterPip({bool animated = true, String? source}) {
    return request(PresentationRequest.pip(animated: animated, source: source));
  }

  /// Enters floating window mode.
  Future<void> enterFloating({bool animated = true, String? source}) {
    return request(PresentationRequest.floating(animated: animated, source: source));
  }

  /// Returns to normal presentation.
  Future<void> exit({bool animated = true, String? source}) {
    return request(PresentationRequest.normal(animated: animated, source: source));
  }

  /// Changes presentation mode.
  Future<void> setMode(PresentationMode mode, {bool animated = true, String? source}) {
    return request(PresentationRequest(mode: mode, animated: animated, source: source));
  }

  /// Toggles fullscreen.
  Future<void> toggleFullscreen({bool animated = true}) {
    if (isFullscreen) {
      return exit(animated: animated, source: 'toggle_fullscreen');
    }

    return enterFullscreen(animated: animated, source: 'toggle_fullscreen');
  }

  /// Toggles PiP.
  Future<void> togglePip({bool animated = true}) {
    if (isPip) {
      return exit(animated: animated, source: 'toggle_pip');
    }

    return enterPip(animated: animated, source: 'toggle_pip');
  }

  /// Updates state from outside.
  ///
  /// Usually called by adapters.
  void update(PresentationState state) {
    _ensureNotDisposed();

    _controller.update(state);
  }

  /// Updates platform capabilities.
  void updateCapabilities(PresentationCapabilities capabilities) {
    _ensureNotDisposed();

    _controller.updateCapabilities(capabilities);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationManager has already been disposed.');
    }
  }

  /// Releases resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _subscription.cancel();

    await _controller.dispose();
  }
}
