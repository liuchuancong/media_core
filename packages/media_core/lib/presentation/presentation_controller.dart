import 'dart:async';
import 'presentation_mode.dart';
import 'presentation_event.dart';
import 'presentation_state.dart';
import 'presentation_request.dart';
import 'package:rxdart/rxdart.dart';
import 'presentation_snapshot.dart';
import 'presentation_capabilities.dart';
import '../policy/presentation_policy.dart';

/// Controls player presentation lifecycle.
///
/// Central logical controller for:
///
/// - fullscreen
/// - picture-in-picture
/// - floating window
///
/// Does not:
///
/// - call native APIs
/// - create windows
/// - control system UI
///
/// Platform adapters are responsible for
/// executing requests and reporting events.
final class PresentationController {
  PresentationController({
    PresentationPolicy policy = const PresentationPolicy(),

    PresentationCapabilities capabilities = const PresentationCapabilities(),
  }) : _policy = policy,
       _capabilities = capabilities;

  PresentationPolicy _policy;

  PresentationCapabilities _capabilities;

  final BehaviorSubject<PresentationState> _stateSubject = BehaviorSubject<PresentationState>.seeded(
    PresentationState.initial(),
  );

  Future<void> _operation = Future<void>.value();

  bool _disposed = false;

  int _generation = 0;

  /// Current state stream.
  ValueStream<PresentationState> get state => _stateSubject.stream;

  /// Current state.
  PresentationState get current => _stateSubject.value;

  /// Snapshot.
  PresentationSnapshot get snapshot => PresentationSnapshot(
    mode: current.mode,
    capabilities: _capabilities,
    transitioning: current.transitioning,
    enabled: current.enabled,
    generation: _generation,
    error: current.error,
  );

  bool get isDisposed => _disposed;

  PresentationMode get mode => current.mode;

  bool get isFullscreen => current.isFullscreen;

  bool get isPip => current.isPip;

  bool get isFloating => current.isFloating;

  /// Update policy.
  void updatePolicy(PresentationPolicy policy) {
    _ensureNotDisposed();

    _policy = policy;

    _stateSubject.add(current.copyWith(enabled: policy.enabled));
  }

  /// Update platform capability.
  void updateCapabilities(PresentationCapabilities capabilities) {
    _ensureNotDisposed();

    _capabilities = capabilities;

    _stateSubject.add(current.copyWith(capabilities: capabilities));
  }

  /// Request presentation change.
  ///
  /// Only creates transition state.
  ///
  /// Platform adapter must execute
  /// the real operation.
  Future<void> request(PresentationRequest request) {
    return _enqueue(() async {
      _ensureNotDisposed();

      if (!_canRequest(request.mode)) {
        throw StateError('Presentation mode ${request.mode} is unavailable.');
      }

      final generation = ++_generation;

      _stateSubject.add(current.copyWith(mode: request.mode, transitioning: true, generation: generation, error: null));
    });
  }

  /// Handles events from platform adapter.
  void handleEvent(PresentationEvent event) {
    _ensureNotDisposed();

    if (event.generation < _generation) {
      return;
    }

    if (event.generation > _generation) {
      _generation = event.generation;
    }

    switch (event.type) {
      case PresentationEventType.started:
        _stateSubject.add(current.copyWith(transitioning: true, generation: _generation));

        break;

      case PresentationEventType.completed:
        _stateSubject.add(
          current.copyWith(
            mode: event.mode ?? PresentationMode.normal,

            transitioning: false,

            generation: _generation,

            error: null,
          ),
        );

        break;

      case PresentationEventType.failed:
        _stateSubject.add(current.copyWith(transitioning: false, generation: _generation, error: event.error));

        break;

      case PresentationEventType.updated:
        _stateSubject.add(current.copyWith(mode: event.mode ?? current.mode, generation: _generation));

        break;

      case PresentationEventType.requested:
        break;

      case PresentationEventType.disposed:
        break;
    }
  }

  /// External state update.
  void update(PresentationState state) {
    _ensureNotDisposed();

    if (state.generation < _generation) {
      return;
    }

    if (state.generation > _generation) {
      _generation = state.generation;
    }

    _stateSubject.add(state);
  }

  /// Exit presentation.
  Future<void> exit() {
    return request(PresentationRequest.normal(source: 'controller'));
  }

  bool _canRequest(PresentationMode mode) {
    if (!_policy.enabled) {
      return false;
    }

    return _capabilities.supports(mode);
  }

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

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _operation;

    await _stateSubject.close();
  }
}
