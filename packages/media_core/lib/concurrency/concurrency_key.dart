import 'dart:async';
import 'dart:collection';

/// Defines a concurrency limit.
///
/// A concurrency limit controls how many operations can run
/// at the same time.
///
/// This is useful for protecting limited resources such as:
/// - network connections
/// - IO operations
/// - background workers
class ConcurrencyLimit {
  ConcurrencyLimit(this.maxConcurrent) : assert(maxConcurrent > 0);

  /// Maximum number of concurrent operations.
  final int maxConcurrent;

  int _active = 0;

  final Queue<Completer<void>> _queue = Queue<Completer<void>>();

  /// Current running operation count.
  int get activeCount => _active;

  /// Waiting operation count.
  int get pendingCount => _queue.length;

  /// Remaining available slots.
  int get availableCount => maxConcurrent - _active;

  /// Acquires one execution slot.
  Future<void> acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }

    final completer = Completer<void>();

    _queue.add(completer);

    await completer.future;
  }

  /// Releases one execution slot.
  void release() {
    if (_queue.isNotEmpty) {
      final completer = _queue.removeFirst();

      if (!completer.isCompleted) {
        completer.complete();
      }

      return;
    }

    if (_active > 0) {
      _active--;
    }
  }

  /// Runs [action] within the concurrency limit.
  Future<T> execute<T>(Future<T> Function() action) async {
    await acquire();

    try {
      return await action();
    } finally {
      release();
    }
  }

  /// Clears all waiting operations.
  void clear() {
    while (_queue.isNotEmpty) {
      final completer = _queue.removeFirst();

      if (!completer.isCompleted) {
        completer.completeError(StateError('Concurrency limit cleared'));
      }
    }
  }
}
