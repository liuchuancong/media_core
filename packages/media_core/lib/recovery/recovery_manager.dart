import 'dart:async';
import 'recovery_state.dart';
import 'recovery_action.dart';
import 'retry_scheduler.dart';
import 'recovery_context.dart';
import 'recovery_snapshot.dart';

/// Coordinates the recovery lifecycle.
///
/// [RecoveryManager] owns recovery state and retry scheduling.
///
/// It does not perform backend-specific recovery itself. The actual recovery
/// operation is supplied by the caller through a callback.
///
/// Responsibilities:
///
/// - start recovery
/// - track recovery context
/// - track recovery attempts
/// - schedule retries
/// - complete or exhaust recovery
/// - expose a consistent recovery snapshot
final class RecoveryManager {
  RecoveryManager({RecoveryState initialState = const RecoveryState.initial(), RetryScheduler? retryScheduler})
    : _state = initialState,
      _retryScheduler = retryScheduler ?? RetryScheduler();

  RecoveryState _state;
  RecoveryContext? _context;
  final RetryScheduler _retryScheduler;

  bool _disposed = false;

  RecoveryState get state => _state;

  RecoveryContext? get context => _context;

  RetryScheduler get retryScheduler => _retryScheduler;

  RecoverySnapshot get snapshot {
    return RecoverySnapshot(state: _state, context: _context);
  }

  bool get isActive => _state.active;

  bool get isCompleted => _state.completed;

  bool get isExhausted => _state.exhausted;

  bool get isIdle => _state.isIdle;

  /// Starts a recovery lifecycle.
  void start(RecoveryContext context, {RecoveryAction action = const RecoveryAction.retry()}) {
    _ensureNotDisposed();

    _cancelScheduledRetry();

    _context = context;
    _state = _state.start(action: action);
  }

  /// Schedules a retry for the current recovery lifecycle.
  ///
  /// The recovery state attempt counter is updated when the scheduled retry
  /// actually begins, rather than when the timer is created.
  bool scheduleRetry(Duration delay, FutureOr<void> Function() callback) {
    _ensureNotDisposed();

    if (!_state.active) {
      return false;
    }

    return _retryScheduler.schedule(delay, () async {
      if (_disposed) {
        return;
      }

      _state = _state.recordAttempt();

      await callback();
    });
  }

  /// Starts an immediate retry without waiting for a timer.
  void recordAttempt() {
    _ensureNotDisposed();

    if (!_state.active) {
      return;
    }

    _state = _state.recordAttempt();
    _retryScheduler.recordAttempt();
  }

  /// Marks recovery as successfully completed.
  void complete() {
    _ensureNotDisposed();

    _cancelScheduledRetry();

    _state = _state.complete();
    _retryScheduler.complete();
  }

  /// Marks recovery as exhausted.
  void exhaust() {
    _ensureNotDisposed();

    _cancelScheduledRetry();

    _state = _state.exhaust();
    _retryScheduler.cancel();
  }

  /// Cancels the active recovery lifecycle.
  void cancel() {
    _ensureNotDisposed();

    _cancelScheduledRetry();

    _state = _state.cancel();
    _context = null;
  }

  /// Resets recovery state and context.
  void reset() {
    _ensureNotDisposed();

    _cancelScheduledRetry();

    _state = _state.reset();
    _context = null;
    _retryScheduler.reset();
  }

  /// Replaces the current recovery context.
  void updateContext(RecoveryContext context) {
    _ensureNotDisposed();

    _context = context;
  }

  /// Releases all resources owned by the manager.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _retryScheduler.dispose();

    _context = null;
  }

  void _cancelScheduledRetry() {
    if (_retryScheduler.isScheduled) {
      _retryScheduler.cancel();
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('RecoveryManager has been disposed.');
    }
  }
}
