import 'dart:async';
import 'state.dart';
import 'dart:collection';
import 'state_machine.dart';
import 'state_machine_event.dart';
import 'state_machine_context.dart';
import 'state_transition_result.dart';

/// Runtime controller for a StateMachine.
///
/// StateMachineController is the lifecycle and execution
/// coordinator around the pure StateMachine engine.
///
/// Responsibilities:
///
/// - serialize event execution
/// - maintain pending event queue
/// - expose transition result stream
/// - coordinate asynchronous dispatch
/// - manage controller lifecycle
///
/// Does not:
///
/// - define state transition rules
/// - contain domain business logic
/// - replace StateMachine
/// - persist state
/// - implement retry policy
///
/// StateMachine owns transition execution.
/// Controller owns runtime orchestration.
final class StateMachineController<S extends StateMachineState> {
  /// Creates a state machine controller.
  StateMachineController({required StateMachine<S> machine, StateMachineContext? context})
    : _machine = machine,
      _context = context ?? machine.context;

  /// Underlying state machine engine.
  final StateMachine<S> _machine;

  /// Runtime execution context.
  final StateMachineContext _context;

  /// Pending event queue.
  final Queue<StateMachineEvent> _queue = Queue<StateMachineEvent>();

  /// Transition result stream.
  final StreamController<StateTransitionResult<S>> _resultController =
      StreamController<StateTransitionResult<S>>.broadcast();

  /// Whether events are currently being processed.
  bool _processing = false;

  /// Whether controller has been disposed.
  bool _disposed = false;

  /// Current machine state.
  S get state => _machine.state;

  /// Current state identifier.
  String get stateId => _machine.stateId;

  /// Runtime execution context.
  StateMachineContext get context => _context;

  /// Whether controller is processing events.
  bool get processing => _processing;

  /// Whether controller has been disposed.
  bool get disposed => _disposed;

  /// Number of queued events.
  int get queueLength => _queue.length;

  /// Stream of transition results.
  ///
  /// Every dispatched event produces one result.
  Stream<StateTransitionResult<S>> get results => _resultController.stream;

  /// Dispatches an event.
  ///
  /// Events are queued and processed sequentially.
  ///
  /// The controller guarantees that only one event
  /// is executing at a time.
  Future<void> dispatch(StateMachineEvent event) async {
    if (_disposed) {
      return;
    }

    _queue.add(event);

    await _processQueue();
  }

  /// Processes pending events.
  ///
  /// Internal serial execution loop.
  Future<void> _processQueue() async {
    if (_processing) {
      return;
    }

    _processing = true;

    try {
      while (_queue.isNotEmpty) {
        final event = _queue.removeFirst();

        final result = await _machine.dispatch(event);

        if (!_resultController.isClosed) {
          _resultController.add(result);
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Checks whether an event can currently execute.
  Future<bool> canHandle(StateMachineEvent event) {
    if (_disposed) {
      return Future.value(false);
    }

    return _machine.canHandle(event);
  }

  /// Forces current machine state.
  ///
  /// Intended for:
  ///
  /// - initialization
  /// - restore
  /// - testing
  void setState(S state) {
    if (_disposed) {
      return;
    }

    _machine.setState(state);
  }

  /// Removes all pending events.
  void clearQueue() {
    _queue.clear();
  }

  /// Disposes controller resources.
  ///
  /// After disposal:
  ///
  /// - events are ignored
  /// - result stream is closed
  /// - queue is cleared
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _queue.clear();

    await _resultController.close();
  }

  @override
  String toString() {
    return '$runtimeType('
        'state=${state.id}, '
        'queue=${_queue.length}, '
        'processing=$_processing, '
        'disposed=$_disposed'
        ')';
  }
}
