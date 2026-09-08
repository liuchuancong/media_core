import 'dart:async';

/// A simple asynchronous mutex.
///
/// Operations submitted to the same mutex are executed serially.
///
/// Example:
/// ```dart
/// final mutex = StreamMutex();
///
/// await mutex.run(() async {
///   await stopPlayer();
///   await openPlayer();
/// });
///
/// await mutex.run(() async {
///   await stopPlayer();
///   await openPlayer();
/// });
/// ```
///
/// The second operation will not start until the first operation completes.
class StreamMutex {
  StreamMutex();

  Future<void> _tail = Future<void>.value();

  bool _disposed = false;

  /// Whether this mutex has been disposed.
  bool get isDisposed => _disposed;

  /// Whether this mutex is still usable.
  bool get isAlive => !_disposed;

  /// Execute [action] exclusively.
  ///
  /// The next operation starts only after the previous operation has
  /// completed, regardless of whether it succeeds or throws.
  ///
  /// The lock is always released in a `finally` block.
  Future<T> run<T>(Future<T> Function() action) async {
    if (_disposed) {
      throw StateError('StreamMutex has been disposed.');
    }

    final previous = _tail;

    final completer = Completer<void>();

    _tail = completer.future;

    try {
      await previous;

      if (_disposed) {
        throw StateError('StreamMutex has been disposed.');
      }

      return await action();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Try to execute [action].
  ///
  /// Returns `null` when the mutex is currently busy.
  ///
  /// Note:
  /// This does not wait for the current operation.
  Future<T?> tryRun<T>(Future<T> Function() action) async {
    if (_disposed) {
      return null;
    }

    if (isLocked) {
      return null;
    }

    return run(action);
  }

  /// Whether there are operations waiting or running.
  ///
  /// This is a lightweight state indicator. It should not be used as a
  /// synchronization primitive by itself.
  bool get isLocked {
    return !_tailIsComplete;
  }

  bool get _tailIsComplete {
    var complete = false;

    _tail.then(
      (_) {
        complete = true;
      },
      onError: (_, _) {
        complete = true;
      },
    );

    return complete;
  }

  /// Wait until all operations currently queued before this call finish.
  Future<void> wait() {
    return _tail;
  }

  /// Dispose the mutex.
  ///
  /// Already queued operations are not forcibly cancelled because Dart
  /// Futures cannot generally be cancelled.
  ///
  /// New operations will be rejected.
  void dispose() {
    _disposed = true;
  }
}

/// A mutex that serializes operations by key.
///
/// Different keys can execute concurrently, while operations using the same
/// key are serialized.
///
/// Example:
/// ```dart
/// final mutex = KeyedStreamMutex();
///
/// await mutex.run('channel-a', () async {
///   await resolveChannelA();
/// });
///
/// await mutex.run('channel-b', () async {
///   await resolveChannelB();
/// });
/// ```
///
/// `channel-a` and `channel-b` do not block each other.
class KeyedStreamMutex {
  final Map<String, StreamMutex> _mutexes = <String, StreamMutex>{};

  bool _disposed = false;

  /// Number of currently registered mutexes.
  int get length => _mutexes.length;

  /// Whether this object has been disposed.
  bool get isDisposed => _disposed;

  /// Execute [action] exclusively for [key].
  ///
  /// Operations using different keys can run concurrently.
  Future<T> run<T>(String key, Future<T> Function() action) {
    if (_disposed) {
      throw StateError('KeyedStreamMutex has been disposed.');
    }

    final mutex = _mutexes.putIfAbsent(key, StreamMutex.new);

    return mutex.run(action);
  }

  /// Wait for all operations associated with [key].
  Future<void> wait(String key) {
    final mutex = _mutexes[key];

    if (mutex == null) {
      return Future<void>.value();
    }

    return mutex.wait();
  }

  /// Remove a key when no further operations are expected.
  ///
  /// This does not cancel a currently running operation.
  Future<void> remove(String key) async {
    final mutex = _mutexes.remove(key);

    if (mutex == null) {
      return;
    }

    await mutex.wait();
    mutex.dispose();
  }

  /// Dispose all mutexes.
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    for (final mutex in _mutexes.values) {
      mutex.dispose();
    }

    _mutexes.clear();
  }
}
