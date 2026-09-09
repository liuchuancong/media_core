import 'dart:async';
import 'reconcile_plan.dart';
import 'reconcile_queue.dart';
import 'reconcile_state.dart';
import 'package:rxdart/rxdart.dart';

/// Schedules reconciliation plans.
///
/// ReconcileScheduler only manages execution order.
/// It does not execute actions.
///
/// Execution belongs to:
///
/// - Coordinator
/// - Controller
/// - SessionManager
final class ReconcileScheduler {
  ReconcileScheduler();

  final ReconcileQueue _queue = ReconcileQueue();

  final BehaviorSubject<ReconcileState> _stateSubject = BehaviorSubject.seeded(const ReconcileState());

  /// Current scheduler state.
  Stream<ReconcileState> get state {
    return _stateSubject.stream;
  }

  /// Current state value.
  ReconcileState get currentState {
    return _stateSubject.value;
  }

  /// Number of queued plans.
  int get length {
    return _queue.length;
  }

  /// Whether scheduler has pending work.
  bool get hasPending {
    return _queue.isNotEmpty;
  }

  /// Adds a reconcile plan.
  void schedule(ReconcilePlan plan) {
    if (plan.isEmpty) {
      return;
    }

    _queue.add(plan);

    _update(currentState.copyWith(pendingActions: _queue.length));
  }

  /// Takes next plan.
  ReconcilePlan? next() {
    final plan = _queue.poll();

    _update(currentState.copyWith(pendingActions: _queue.length));

    return plan;
  }

  /// Marks reconciliation started.
  void start(ReconcilePlan plan) {
    _update(currentState.start(plan.length));
  }

  /// Marks reconciliation completed.
  void complete() {
    _update(currentState.finish());
  }

  /// Marks reconciliation failed.
  void fail() {
    _update(currentState.fail());
  }

  /// Clears pending plans.
  void clear() {
    _queue.clear();

    _update(const ReconcileState());
  }

  int _pendingActionCount() {
    var count = 0;

    while (true) {
      final plan = _queue.poll();

      if (plan == null) {
        break;
      }

      count += plan.length;
    }

    return count;
  }

  void _update(ReconcileState value) {
    if (!_stateSubject.isClosed) {
      _stateSubject.add(value);
    }
  }

  /// Releases resources.
  Future<void> dispose() async {
    _queue.clear();

    await _stateSubject.close();
  }
}
