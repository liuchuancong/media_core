import 'dart:async';

/// A mutual exclusion lock.
///
/// A Mutex allows only one asynchronous operation to enter
/// the critical section at a time.
///
/// Difference from [AsyncLock]:
/// - Mutex exposes a more traditional lock/unlock API.
/// - Designed for protecting shared state.
///
/// Example:
/// ```dart
/// final mutex = Mutex();
///
/// await mutex.protect(() async {
///   counter++;
/// });
/// ```
class Mutex {
  Completer<void>? _owner;

  /// Whether the mutex is currently locked.
  bool get locked => _owner != null;

  /// Acquires the mutex.
  Future<void> acquire() async {
    while (_owner != null) {
      await _owner!.future;
    }

    _owner = Completer<void>();
  }

  /// Releases the mutex.
  void release() {
    final owner = _owner;

    if (owner == null) {
      return;
    }

    _owner = null;

    if (!owner.isCompleted) {
      owner.complete();
    }
  }

  /// Executes [action] while holding the mutex.
  Future<T> protect<T>(Future<T> Function() action) async {
    await acquire();

    try {
      return await action();
    } finally {
      release();
    }
  }

  /// Executes a synchronous action while holding the mutex.
  T protectSync<T>(T Function() action) {
    if (locked) {
      throw StateError('Mutex is already locked');
    }

    _owner = Completer<void>();

    try {
      return action();
    } finally {
      release();
    }
  }
}

/// A reentrant-style mutex with ownership tracking.
///
/// Allows nested calls from the same async scope.
///
/// Note:
/// Dart does not provide true async execution identity,
/// so this implementation tracks nesting manually.
class ReentrantMutex {
  Completer<void>? _owner;

  int _depth = 0;

  bool get locked => _owner != null;

  int get depth => _depth;

  Future<void> acquire() async {
    if (_owner != null) {
      await _owner!.future;
    }

    _owner = Completer<void>();
    _depth = 1;
  }

  void release() {
    final owner = _owner;

    if (owner == null) {
      return;
    }

    _depth--;

    if (_depth > 0) {
      return;
    }

    _owner = null;

    if (!owner.isCompleted) {
      owner.complete();
    }
  }

  Future<T> protect<T>(Future<T> Function() action) async {
    await acquire();

    try {
      return await action();
    } finally {
      release();
    }
  }
}

/// Key based mutex.
///
/// Each key has an independent mutex.
///
/// Example:
/// ```dart
/// final mutex = KeyedMutex<String>();
///
/// await mutex.protect(
///   'epg',
///   () async {
///     await syncEpg();
///   },
/// );
/// ```
class KeyedMutex<K> {
  final Map<K, Mutex> _mutexes = {};

  Future<T> protect<T>(K key, Future<T> Function() action) async {
    final mutex = _mutexes.putIfAbsent(key, Mutex.new);

    try {
      return await mutex.protect(action);
    } finally {
      if (!mutex.locked) {
        _mutexes.remove(key);
      }
    }
  }

  int get length => _mutexes.length;

  void cleanup() {
    _mutexes.removeWhere((_, mutex) => !mutex.locked);
  }

  void clear() {
    _mutexes.clear();
  }
}
