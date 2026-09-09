import 'dart:async';
import 'presentation_mode.dart';
import 'presentation_state.dart';
import 'presentation_request.dart';
import 'package:rxdart/rxdart.dart';
import 'presentation_snapshot.dart';

/// Coordinates presentation-mode transitions for the media core.
///
/// [PresentationController] is intentionally platform-agnostic. It does not
/// know how fullscreen, picture-in-picture, or floating presentation is
/// implemented by a particular platform.
///
/// Its responsibilities are limited to:
///
/// - accepting presentation requests;
/// - serializing asynchronous transitions;
/// - maintaining the current presentation state;
/// - publishing state changes reactively;
/// - preventing stale asynchronous transitions from overwriting newer state;
/// - exposing a stable snapshot for synchronous inspection.
///
/// Platform-specific controllers such as a fullscreen or PiP controller should
/// perform the actual native operation and report the resulting state back to
/// this controller.
///
/// The controller does not own any platform resource.
final class PresentationController {
  /// Creates a presentation controller.
  ///
  /// [initialState] can be supplied by a higher-level restoration or session
  /// layer when presentation state needs to be restored.
  PresentationController({PresentationState initialState = const PresentationState.idle()})
    : _stateSubject = BehaviorSubject<PresentationState>.seeded(initialState);

  final BehaviorSubject<PresentationState> _stateSubject;

  /// Serializes presentation operations.
  ///
  /// Presentation transitions must not overlap. For example, a fullscreen
  /// request immediately followed by a PiP request must be processed in a
  /// deterministic order.
  Future<void> _operation = Future<void>.value();

  bool _disposed = false;

  /// Monotonically increasing request generation.
  ///
  /// Each accepted transition receives a new generation. Platform callbacks
  /// carrying an older generation can therefore be ignored safely.
  int _generation = 0;

  /// Current presentation state.
  ValueStream<PresentationState> get state => _stateSubject.stream;

  /// Current immutable presentation snapshot.
  PresentationSnapshot get snapshot {
    _ensureNotDisposed();
    return PresentationSnapshot.fromState(_stateSubject.value);
  }

  /// Returns the current presentation mode.
  PresentationMode get mode => _stateSubject.value.mode;

  /// Returns the current lifecycle generation.
  int get generation => _generation;

  /// Whether a presentation transition is currently in progress.
  bool get isTransitioning => _stateSubject.value.isTransitioning;

  /// Whether the current presentation mode is fullscreen.
  bool get isFullscreen => _stateSubject.value.isFullscreen;

  /// Whether the current presentation mode is picture-in-picture.
  bool get isPip => _stateSubject.value.isPip;

  /// Whether the current presentation mode is floating.
  bool get isFloating => _stateSubject.value.isFloating;

  /// Whether the presentation controller is in its normal mode.
  bool get isNormal => _stateSubject.value.isNormal;

  /// Whether the controller has been disposed.
  bool get isDisposed => _disposed;

  /// Requests a presentation-mode transition.
  ///
  /// Requests are serialized so that only one asynchronous transition is
  /// processed at a time.
  ///
  /// The controller itself does not perform platform operations. It records
  /// the requested transition and publishes the corresponding lifecycle
  /// state. A platform-specific presentation controller can subsequently
  /// reconcile the actual result through [updateState].
  Future<void> request(PresentationRequest request) {
    return _enqueue(() async {
      _ensureNotDisposed();

      final int generation = ++_generation;

      final PresentationState current = _stateSubject.value;

      if (request.mode == current.mode && !current.isTransitioning) {
        return;
      }

      _emit(
        current.copyWith(
          mode: request.mode,
          status: PresentationStatus.transitioning,
          generation: generation,
          request: request,
          error: null,
        ),
      );
    });
  }

  /// Requests normal presentation mode.
  Future<void> enterNormal() {
    return request(const PresentationRequest.enter(PresentationMode.normal));
  }

  /// Requests fullscreen presentation.
  Future<void> enterFullscreen() {
    return request(const PresentationRequest.enter(PresentationMode.fullscreen));
  }

  /// Requests picture-in-picture presentation.
  Future<void> enterPip() {
    return request(const PresentationRequest.enter(PresentationMode.pip));
  }

  /// Requests floating presentation.
  Future<void> enterFloating() {
    return request(const PresentationRequest.enter(PresentationMode.floating));
  }

  /// Updates the presentation state after a platform operation completes.
  ///
  /// This method is intended for platform-specific presentation controllers.
  /// It does not initiate another platform operation.
  ///
  /// States belonging to an older generation are ignored. This prevents a
  /// delayed native callback from restoring an obsolete presentation mode.
  void updateState(PresentationState state) {
    _ensureNotDisposed();

    if (state.generation < _generation) {
      return;
    }

    if (state.generation > _generation) {
      _generation = state.generation;
    }

    _emit(state);
  }

  /// Marks the current presentation transition as completed.
  ///
  /// The supplied [mode] becomes the authoritative presentation mode.
  /// This is useful when a platform implementation reports success without
  /// constructing a complete [PresentationState] itself.
  void complete({required PresentationMode mode, int? generation}) {
    _ensureNotDisposed();

    final int resolvedGeneration = generation ?? _generation;

    if (resolvedGeneration < _generation) {
      return;
    }

    if (resolvedGeneration > _generation) {
      _generation = resolvedGeneration;
    }

    final PresentationState current = _stateSubject.value;

    _emit(current.copyWith(mode: mode, status: PresentationStatus.active, generation: resolvedGeneration, error: null));
  }

  /// Marks the current presentation transition as failed.
  ///
  /// The controller retains the previous stable mode when possible and
  /// exposes the failure through [PresentationState].
  void fail(Object error, {StackTrace? stackTrace, int? generation}) {
    _ensureNotDisposed();

    final int resolvedGeneration = generation ?? _generation;

    if (resolvedGeneration < _generation) {
      return;
    }

    if (resolvedGeneration > _generation) {
      _generation = resolvedGeneration;
    }

    final PresentationState current = _stateSubject.value;

    _emit(
      current.copyWith(
        status: PresentationStatus.error,
        generation: resolvedGeneration,
        error: error,
        errorStackTrace: stackTrace,
      ),
    );
  }

  /// Resets presentation state to normal mode.
  ///
  /// Unlike [enterNormal], this method represents reconciliation with an
  /// already-normal platform state and therefore does not create a
  /// transition request.
  void reset() {
    _ensureNotDisposed();

    final int generation = ++_generation;

    _emit(PresentationState.normal(generation: generation));
  }

  /// Serializes asynchronous presentation operations.
  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> next = _operation.then((_) => operation());

    // Keep the queue alive after an individual operation fails. The returned
    // future still exposes the original failure to the caller.
    _operation = next.catchError((Object _) {});

    return next;
  }

  /// Publishes a new state.
  void _emit(PresentationState state) {
    if (_disposed) {
      return;
    }

    _stateSubject.add(state);
  }

  /// Ensures that the controller is still usable.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PresentationController has already been disposed.');
    }
  }

  /// Disposes the controller.
  ///
  /// Disposal is idempotent. Pending presentation operations are allowed to
  /// finish before the state stream is closed.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    Object? firstError;
    StackTrace? firstStackTrace;

    try {
      await _operation;
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    if (!_stateSubject.isClosed) {
      _stateSubject.add(PresentationState.disposed(generation: _generation));

      await _stateSubject.close();
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}
