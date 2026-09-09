import 'dart:async';
import 'presentation_mode.dart';
import 'presentation_event.dart';
import 'presentation_state.dart';
import 'presentation_reducer.dart';
import 'presentation_request.dart';
import 'package:rxdart/rxdart.dart';
import 'presentation_capabilities.dart';

/// Controls presentation lifecycle state.
///
/// PresentationController is the core state machine
/// of presentation subsystem.
///
/// Responsibilities:
///
/// - own presentation state
/// - receive requests
/// - generate lifecycle events
/// - reduce events into state
/// - synchronize generations
///
/// Does not:
///
/// - call native APIs
/// - execute platform operations
/// - manage windows
/// - know Android/iOS/Desktop APIs
///
/// Platform operations are handled by:
///
/// PresentationAdapter
///
final class PresentationController {
  PresentationController({
    PresentationReducer reducer = const PresentationReducer(),
    PresentationCapabilities capabilities = const PresentationCapabilities(),
  }) : _reducer = reducer,
       _capabilities = capabilities;

  final PresentationReducer _reducer;

  PresentationCapabilities _capabilities;

  final BehaviorSubject<PresentationState> _stateSubject = BehaviorSubject.seeded(PresentationState.initial());

  Future<void> _operation = Future<void>.value();

  bool _disposed = false;

  int _generation = 0;

  // ============================================================
  // State
  // ============================================================

  /// Current presentation state stream.
  ValueStream<PresentationState> get state => _stateSubject.stream;

  /// Current state.
  PresentationState get current => _stateSubject.value;

  /// Current presentation mode.
  PresentationMode get mode => current.mode;

  /// Current capabilities.
  PresentationCapabilities get capabilities => _capabilities;

  /// Whether fullscreen active.
  bool get isFullscreen => current.isFullscreen;

  /// Whether PiP active.
  bool get isPip => current.isPip;

  /// Whether floating active.
  bool get isFloating => current.isFloating;

  // ============================================================
  // Capability
  // ============================================================

  /// Updates platform capabilities.
  ///
  /// Called by PresentationService
  /// when adapter reports changes.
  void updateCapabilities(PresentationCapabilities capabilities) {
    _ensureNotDisposed();

    _capabilities = capabilities;

    _stateSubject.add(current.copyWith(capabilities: capabilities));
  }

  // ============================================================
  // Request
  // ============================================================

  /// Accepts a presentation request.
  ///
  /// This only changes logical state.
  ///
  /// Actual platform execution is performed
  /// by PresentationAdapter.
  Future<void> request(PresentationRequest request) {
    return _enqueue(() {
      _ensureNotDisposed();

      final generation = ++_generation;

      handleEvent(PresentationEvent.started(mode: request.mode, generation: generation, source: request.source));
    });
  }

  // ============================================================
  // Events
  // ============================================================

  /// Handles lifecycle events.
  void handleEvent(PresentationEvent event) {
    _ensureNotDisposed();

    if (event.generation < current.generation) {
      return;
    }

    if (event.generation > _generation) {
      _generation = event.generation;
    }

    final next = _reducer.reduce(current, event);

    _stateSubject.add(next);
  }

  /// Force update state.
  ///
  /// Used by:
  ///
  /// - restore
  /// - persistence
  /// - external lifecycle
  void update(PresentationState state) {
    _ensureNotDisposed();

    if (state.generation < _generation) {
      return;
    }

    _generation = state.generation;

    _stateSubject.add(state);
  }

  /// Exit presentation.
  Future<void> exit() {
    return request(PresentationRequest.normal(source: 'controller'));
  }

  // ============================================================
  // Internal
  // ============================================================

  Future<void> _enqueue(FutureOr<void> Function() action) {
    final next = _operation.then((_) => action());

    _operation = next.catchError((_) {});

    return next;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationController has already been disposed.');
    }
  }

  // ============================================================
  // Dispose
  // ============================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _operation;

    await _stateSubject.close();
  }
}
