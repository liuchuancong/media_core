import 'dart:async';

/// A simple asynchronous lock.
///
/// Only one async task can hold the lock at a time.
/// Other tasks wait until the current holder releases it.
///
/// Example:
/// ```dart
/// final lock = AsyncLock();
///
/// await lock.synchronized(() async {
///   // protected critical section
/// });
/// ```
class AsyncLock {
  Completer<void>? _completer;

  /// Whether the lock is currently held.
  bool get locked => _completer != null;

  /// Acquires the lock.
  ///
  /// This method waits until the previous holder releases the lock.
  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }

    _completer = Completer<void>();
  }

  /// Releases the lock.
  ///
  /// Calling release without holding the lock is ignored.
  void release() {
    final completer = _completer;
    if (completer == null) {
      return;
    }

    _completer = null;

    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  /// Runs [action] exclusively.
  ///
  /// The lock is automatically released after [action] completes,
  /// even when it throws.
  Future<T> synchronized<T>(Future<T> Function() action) async {
    await acquire();

    try {
      return await action();
    } finally {
      release();
    }
  }
}

/// A keyed async lock.
///
/// Useful when different resources need independent locks.
///
/// Example:
/// ```dart
/// final locks = KeyedAsyncLock<String>();
///
/// await locks.synchronized('player-1', () async {
///   await initializePlayer();
/// });
/// ```
class KeyedAsyncLock<K> {
  final Map<K, AsyncLock> _locks = {};

  /// Executes [action] while holding the lock associated with [key].
  Future<T> synchronized<T>(K key, Future<T> Function() action) async {
    final lock = _locks.putIfAbsent(key, AsyncLock.new);

    try {
      return await lock.synchronized(action);
    } finally {
      if (!lock.locked) {
        _locks.remove(key);
      }
    }
  }

  /// Removes all idle locks.
  void cleanup() {
    _locks.removeWhere((_, lock) => !lock.locked);
  }

  /// Clears all locks.
  ///
  /// Existing running operations are not interrupted.
  void clear() {
    _locks.clear();
  }

  /// Number of tracked locks.
  int get length => _locks.length;
}
