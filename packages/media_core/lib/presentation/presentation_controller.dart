import 'dart:async';
import 'presentation_mode.dart';
import 'presentation_event.dart';
import 'presentation_state.dart';
import 'presentation_request.dart';
import 'presentation_reducer.dart';
import 'presentation_snapshot.dart';
import 'package:rxdart/rxdart.dart';
import 'presentation_capabilities.dart';
import '../policy/presentation_policy.dart';

/// Controls presentation lifecycle.
///
/// PresentationController is the state owner of
/// the presentation subsystem.
///
/// Responsibilities:
///
/// - owns presentation state
/// - validates presentation requests
/// - generates lifecycle generations
/// - reduces events into state
/// - exposes state stream
///
/// Does not:
///
/// - call native APIs
/// - create windows
/// - control fullscreen
/// - enter PiP
/// - manage UI
///
/// Platform operations are handled by:
///
/// - PresentationAdapter
///
/// State transitions are handled by:
///
/// - PresentationReducer
final class PresentationController {
  /// Creates a presentation controller.
  PresentationController({
    PresentationPolicy policy = const PresentationPolicy(),

    PresentationCapabilities capabilities = const PresentationCapabilities(),

    PresentationReducer reducer = const PresentationReducer(),
  }) : _policy = policy,
       _capabilities = capabilities,
       _reducer = reducer;

  PresentationPolicy _policy;

  PresentationCapabilities _capabilities;

  final PresentationReducer _reducer;

  final BehaviorSubject<PresentationState> _stateSubject = BehaviorSubject<PresentationState>.seeded(
    PresentationState.initial(),
  );

  Future<void> _operation = Future<void>.value();

  bool _disposed = false;

  int _generation = 0;

  /// Current presentation state stream.
  ValueStream<PresentationState> get state => _stateSubject.stream;

  /// Current presentation state.
  PresentationState get current => _stateSubject.value;

  /// Current lifecycle generation.
  ///
  /// Used to ignore stale async callbacks
  /// from platform adapters.
  int get generation => _generation;

  /// Current immutable snapshot.
  PresentationSnapshot get snapshot {
    final state = current;

    return PresentationSnapshot(
      mode: state.mode,

      capabilities: _capabilities,

      transitioning: state.transitioning,

      enabled: state.enabled,

      generation: _generation,

      error: state.error,
    );
  }

  /// Whether controller is disposed.
  bool get isDisposed => _disposed;

  /// Current presentation mode.
  PresentationMode get mode => current.mode;

  /// Whether fullscreen is active.
  bool get isFullscreen => current.isFullscreen;

  /// Whether PiP is active.
  bool get isPip => current.isPip;

  /// Whether floating mode is active.
  bool get isFloating => current.isFloating;

  /// Updates presentation policy.
  ///
  /// Policy controls whether
  /// presentation requests are allowed.
  void updatePolicy(PresentationPolicy policy) {
    _ensureNotDisposed();

    _policy = policy;

    _stateSubject.add(current.copyWith(enabled: policy.enabled));
  }

  /// Updates platform capabilities.
  ///
  /// Called by PresentationService
  /// after adapter capability changes.
  void updateCapabilities(PresentationCapabilities capabilities) {
    _ensureNotDisposed();

    _capabilities = capabilities;

    _stateSubject.add(current.copyWith(capabilities: capabilities));
  }

  /// Requests a presentation transition.
  ///
  /// This only updates logical state.
  ///
  /// Real platform transition is executed by:
  ///
  /// PresentationAdapter
  ///
  /// Completion is reported through:
  ///
  /// PresentationEvent.completed
  Future<void> request(PresentationRequest request) {
    return _enqueue(() async {
      _ensureNotDisposed();

      if (!_canRequest(request.mode)) {
        throw StateError(
          'Presentation mode '
          '${request.mode} '
          'is unavailable.',
        );
      }

      final generation = ++_generation;

      handleEvent(PresentationEvent.requested(request.mode, generation: generation, source: request.source));
    });
  }

  /// Handles presentation lifecycle events.
  ///
  /// Events are produced by:
  ///
  /// - PresentationAdapter
  /// - system lifecycle
  /// - platform callbacks
  void handleEvent(PresentationEvent event) {
    _ensureNotDisposed();

    //
    // Ignore stale callbacks.
    //
    if (event.generation < _generation) {
      return;
    }

    //
    // Update generation.
    //
    if (event.generation > _generation) {
      _generation = event.generation;
    }

    final next = _reducer.reduce(current, event);

    _stateSubject.add(next);
  }

  /// Force updates current state.
  ///
  /// Usually used by adapters.
  void update(PresentationState state) {
    _ensureNotDisposed();

    if (state.generation < _generation) {
      return;
    }

    _generation = state.generation;

    _stateSubject.add(state);
  }

  /// Exit current presentation mode.
  Future<void> exit() {
    return request(PresentationRequest.normal(source: 'controller'));
  }

  /// Checks whether request is allowed.
  bool _canRequest(PresentationMode mode) {
    if (!_policy.enabled) {
      return false;
    }

    return _capabilities.supports(mode);
  }

  /// Serializes state mutations.
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operation.then((_) => action());

    _operation = next.catchError((_) {});

    return next;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationController has already been disposed.');
    }
  }

  /// Releases controller resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _operation;

    handleEvent(PresentationEvent.disposed(generation: _generation));

    await _stateSubject.close();
  }
}
