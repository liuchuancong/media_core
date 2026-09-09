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
/// Connects application layer with
/// presentation subsystem.
///
/// Responsibilities:
///
/// - expose presentation API
/// - forward requests
/// - execute platform operations
/// - synchronize platform events
/// - synchronize capability changes
///
/// Does not:
///
/// - own presentation state
/// - render UI
/// - implement native APIs
final class PresentationService {
  PresentationService({required PresentationController controller, required PresentationAdapter adapter})
    : _controller = controller,
      _adapter = adapter {
    _eventSubscription = _adapter.events.listen(_onEvent);

    _capabilitySubscription = _adapter.capabilityChanges.listen(_onCapabilityChanged);

    // initialize current capability
    _controller.updateCapabilities(_adapter.capabilities);
  }

  final PresentationController _controller;

  final PresentationAdapter _adapter;

  StreamSubscription<PresentationEvent>? _eventSubscription;

  StreamSubscription<PresentationCapabilities>? _capabilitySubscription;

  bool _disposed = false;

  /// Current presentation state.
  ValueStream<PresentationState> get state => _controller.state;

  /// Current state snapshot.
  PresentationState get current => _controller.current;

  /// Current platform capability.
  PresentationCapabilities get capabilities => _adapter.capabilities;

  /// Sends presentation request.
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

    try {
      await _adapter.apply(request);
    } catch (error) {
      _controller.handleEvent(PresentationEvent.failed(request.mode, error: error.toString(), source: 'adapter'));

      rethrow;
    }
  }

  /// Enter fullscreen.
  Future<void> enterFullscreen() {
    return request(PresentationRequest.fullscreen());
  }

  /// Exit fullscreen.
  Future<void> exitFullscreen() {
    return request(PresentationRequest.normal());
  }

  /// Enter PiP.
  Future<void> enterPip() {
    return request(PresentationRequest.pip());
  }

  /// Exit PiP.
  Future<void> exitPip() {
    return request(PresentationRequest.normal());
  }

  /// Enter floating window.
  Future<void> enterFloating() {
    return request(PresentationRequest.floating());
  }

  /// Refresh platform capability.
  Future<void> refreshCapabilities() async {
    _ensureNotDisposed();

    await _adapter.refreshCapabilities();

    _controller.updateCapabilities(_adapter.capabilities);
  }

  /// Receives platform lifecycle events.
  void _onEvent(PresentationEvent event) {
    if (_disposed) {
      return;
    }

    _controller.handleEvent(event);
  }

  /// Receives capability changes.
  void _onCapabilityChanged(PresentationCapabilities capabilities) {
    if (_disposed) {
      return;
    }

    _controller.updateCapabilities(capabilities);
  }

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

    await _capabilitySubscription?.cancel();

    await _adapter.dispose();

    await _controller.dispose();
  }
}
