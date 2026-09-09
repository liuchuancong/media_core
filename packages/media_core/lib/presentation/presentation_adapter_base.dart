import 'dart:async';
import 'presentation_event.dart';
import 'presentation_adapter.dart';
import 'presentation_request.dart';
import 'presentation_capabilities.dart';

/// Base implementation of [PresentationAdapter].
///
/// Provides:
///
/// - event stream management
/// - capability storage
/// - lifecycle management
/// - common adapter behavior
///
/// Subclasses only implement:
///
/// - platform operations
///
/// Example:
///
/// Android:
/// - enter PiP
/// - exit PiP
///
/// Windows:
/// - fullscreen window
/// - floating window
///
/// This class does not:
///
/// - own presentation state
/// - reduce events
/// - decide transitions
abstract class PresentationAdapterBase implements PresentationAdapter {
  PresentationAdapterBase({PresentationCapabilities initialCapabilities = const PresentationCapabilities()})
    : _capabilities = initialCapabilities;

  PresentationCapabilities _capabilities;

  final StreamController<PresentationEvent> _eventController = StreamController<PresentationEvent>.broadcast();

  final StreamController<PresentationCapabilities> _capabilityController =
      StreamController<PresentationCapabilities>.broadcast();

  bool _disposed = false;

  int _generation = 0;

  // ---------------------------------------------------------------------------
  // Capability
  // ---------------------------------------------------------------------------

  @override
  PresentationCapabilities get capabilities => _capabilities;

  @override
  Stream<PresentationCapabilities> get capabilityChanges => _capabilityController.stream;

  /// Updates platform capability.
  ///
  /// Called by subclasses when:
  ///
  /// - permission changes
  /// - window mode changes
  /// - device configuration changes
  void updateCapabilities(PresentationCapabilities capabilities) {
    _ensureNotDisposed();

    _capabilities = capabilities;

    _capabilityController.add(capabilities);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  @override
  Stream<PresentationEvent> get events => _eventController.stream;

  /// Sends presentation event to controller.
  ///
  /// Platform implementations should call this
  /// after native operation result.
  void emit(PresentationEvent event) {
    if (_disposed) {
      return;
    }

    _eventController.add(event);
  }

  /// Creates next lifecycle generation.
  int nextGeneration() {
    return ++_generation;
  }

  int get generation => _generation;

  // ---------------------------------------------------------------------------
  // Adapter operations
  // ---------------------------------------------------------------------------

  @override
  Future<void> apply(PresentationRequest request) async {
    _ensureNotDisposed();

    final generation = nextGeneration();

    emit(PresentationEvent.started(request.mode, generation: generation, source: 'adapter'));

    try {
      await onApply(request);

      emit(PresentationEvent.completed(request.mode, generation: generation, source: 'adapter'));
    } catch (error) {
      emit(PresentationEvent.failed(request.mode, error: error.toString(), generation: generation, source: 'adapter'));

      rethrow;
    }
  }

  /// Platform implementation.
  ///
  /// Subclasses override this.
  Future<void> onApply(PresentationRequest request);

  @override
  Future<void> refreshCapabilities() async {
    _ensureNotDisposed();

    await onRefreshCapabilities();
  }

  /// Platform capability refresh.
  ///
  /// Example:
  ///
  /// Android:
  /// check PiP permission
  ///
  /// Windows:
  /// check window support
  Future<void> onRefreshCapabilities() async {}

  @override
  Future<void> exit() async {
    await apply(PresentationRequest.normal(source: 'adapter'));
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationAdapter has already been disposed.');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await onDispose();

    await _eventController.close();

    await _capabilityController.close();
  }

  /// Platform cleanup.
  Future<void> onDispose() async {}
}
