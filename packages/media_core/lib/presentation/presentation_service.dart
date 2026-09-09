import 'dart:async';
import 'presentation_event.dart';
import 'presentation_state.dart';
import 'presentation_adapter.dart';
import 'presentation_request.dart';
import 'package:rxdart/rxdart.dart';
import 'presentation_controller.dart';
import 'presentation_capabilities.dart';

/// Application level presentation service.
///
/// PresentationService is the public API layer
/// above PresentationController.
///
/// Responsibilities:
///
/// - expose presentation API
/// - forward requests
/// - expose presentation state
/// - expose capabilities
/// - synchronize adapter events
///
/// Does not:
///
/// - own presentation state
/// - execute platform operations
/// - call native APIs
/// - manage windows
///
/// Platform operations are handled by:
///
/// PresentationAdapter
///
final class PresentationService {
  PresentationService({required PresentationController controller, required PresentationAdapter adapter})
    : _controller = controller,
      _adapter = adapter {
    _eventSubscription = _adapter.events.listen(_onEvent);
  }

  final PresentationController _controller;

  final PresentationAdapter _adapter;

  StreamSubscription<PresentationEvent>? _eventSubscription;

  bool _disposed = false;

  // ============================================================
  // State
  // ============================================================

  /// Current presentation state stream.
  ValueStream<PresentationState> get state => _controller.state;

  /// Current presentation state.
  PresentationState get current => _controller.current;

  /// Current platform capabilities.
  PresentationCapabilities get capabilities => _adapter.capabilities;

  // ============================================================
  // Request API
  // ============================================================

  /// Requests presentation change.
  ///
  /// Flow:
  ///
  /// UI
  ///  |
  /// PresentationService
  ///  |
  /// PresentationController
  ///  |
  /// PresentationAdapter
  ///
  Future<void> request(PresentationRequest request) async {
    _ensureNotDisposed();

    await _controller.request(request);
  }

  /// Enter fullscreen.
  Future<void> enterFullscreen() {
    return request(PresentationRequest.fullscreen());
  }

  /// Exit fullscreen.
  Future<void> exitFullscreen() {
    return request(PresentationRequest.normal());
  }

  /// Enter picture-in-picture.
  Future<void> enterPip() {
    return request(PresentationRequest.pip());
  }

  /// Exit picture-in-picture.
  Future<void> exitPip() {
    return request(PresentationRequest.normal());
  }

  /// Enter floating window.
  Future<void> enterFloating() {
    return request(PresentationRequest.floating());
  }

  /// Exit current presentation mode.
  Future<void> exit() {
    return request(PresentationRequest.normal(source: 'service'));
  }

  // ============================================================
  // Capability
  // ============================================================

  /// Refresh platform capability.
  ///
  /// Adapter updates its own capability state.
  ///
  /// Controller reads capability when needed.
  Future<void> refreshCapabilities() async {
    _ensureNotDisposed();

    await _adapter.refreshCapabilities();
  }

  // ============================================================
  // Events
  // ============================================================

  /// Receives platform events.
  void _onEvent(PresentationEvent event) {
    if (_disposed) {
      return;
    }

    _controller.handleEvent(event);
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationService has already been disposed.');
    }
  }

  /// Releases resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _eventSubscription?.cancel();

    await _adapter.dispose();

    await _controller.dispose();
  }
}
