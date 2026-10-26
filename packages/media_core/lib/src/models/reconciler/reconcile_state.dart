import 'package:built_value/built_value.dart';

part 'reconcile_state.g.dart';

/// Runtime state of reconciliation process.
abstract class ReconcileState implements Built<ReconcileState, ReconcileStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory ReconcileState([void Function(ReconcileStateBuilder)? updates]) = _$ReconcileState;

  /// Creates a reconciliation state from its phase flags and pending count.
  factory ReconcileState.of({bool running = false, bool completed = false, bool failed = false, int pendingActions = 0}) {
    return ReconcileState(
      (builder) => builder
        ..running = running
        ..completed = completed
        ..failed = failed
        ..pendingActions = pendingActions,
    );
  }

  ReconcileState._();

  /// A scheduler that has not started is idle: no phase set, nothing
  /// pending.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ReconcileStateBuilder builder) => builder
    ..running = false
    ..completed = false
    ..failed = false
    ..pendingActions = 0;

  /// Whether reconciliation is running.
  bool get running;

  /// Whether reconciliation completed.
  bool get completed;

  /// Whether reconciliation failed.
  bool get failed;

  /// Number of pending actions.
  int get pendingActions;

  /// Whether no reconciliation phase is active and nothing is pending.
  bool get isIdle {
    return !running && !completed && !failed && pendingActions == 0;
  }

  /// Whether reconciliation is currently running.
  bool get isProcessing {
    return running;
  }

  /// Whether reconciliation ended in failure.
  bool get hasFailure {
    return failed;
  }

  /// Returns the running state with [count] actions pending.
  ReconcileState start(int count) {
    return ReconcileState.of(running: true, pendingActions: count);
  }

  /// Returns the completed state.
  ReconcileState finish() {
    return ReconcileState.of(completed: true);
  }

  /// Returns the failed state.
  ReconcileState fail() {
    return ReconcileState.of(failed: true);
  }
}
