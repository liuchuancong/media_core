import 'dart:async';
import 'retry_state.dart';

/// Schedules delayed recovery retries.
///
/// The scheduler owns only timing.
///
/// It does not:
///
/// - decide whether a retry is allowed
/// - select a recovery action
/// - mutate [RecoveryState]
/// - perform the actual recovery operation
///
/// The caller remains responsible for interpreting the retry callback.
final class RetryScheduler {
  RetryScheduler({RetryState initialState = const RetryState.initial()}) : _state = initialState;

  RetryState _state;
  Timer? _timer;
  bool _disposed = false;

  RetryState get state => _state;

  bool get isScheduled => _timer != null;

  /// Schedules a callback after [delay].
  ///
  /// Returns `false` when the scheduler cannot schedule another retry.
  bool schedule(Duration delay, FutureOr<void> Function() callback) {
    _ensureNotDisposed();

    if (!_state.canRetry) {
      return false;
    }

    cancel();

    _state = _state.schedule(delay);

    _timer = Timer(delay, () async {
      _timer = null;

      if (_disposed) {
        return;
      }

      _state = _state.recordAttempt();

      try {
        await callback();
      } catch (_) {
        if (_disposed) {
          return;
        }

        _state = _state.cancel();
        rethrow;
      }
    });

    return true;
  }

  /// Records a retry attempt without scheduling a timer.
  ///
  /// This is useful when the retry operation is triggered immediately.
  void recordAttempt() {
    _ensureNotDisposed();

    _state = _state.recordAttempt();
  }

  /// Marks the scheduler as actively executing a retry.
  void start() {
    _ensureNotDisposed();

    _state = _state.start();
  }

  /// Marks the current retry lifecycle as completed.
  void complete() {
    _ensureNotDisposed();

    _cancelTimer();
    _state = _state.complete();
  }

  /// Cancels a scheduled retry.
  void cancel() {
    _ensureNotDisposed();

    _cancelTimer();
    _state = _state.cancel();
  }

  /// Resets the scheduler to its initial state.
  void reset() {
    _ensureNotDisposed();

    _cancelTimer();
    _state = _state.reset();
  }

  /// Releases scheduler resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('RetryScheduler has been disposed.');
    }
  }
}
