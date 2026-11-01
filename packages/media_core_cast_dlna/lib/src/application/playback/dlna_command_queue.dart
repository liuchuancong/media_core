import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';

/// Serializes a session's control commands (§18.5).
///
/// Commands run one at a time, in submission order — `SetAVTransportURI`
/// completes before `Play` starts, a burst of `seek`s plays out serially
/// (the spec allows merging or serializing; serializing is simpler and
/// never wrong). [cancelPending] drops everything that has not started
/// yet: a `stop` clears the pending backlog first so a stopped session
/// does not keep playing a queued `play`.
///
/// A dropped command's future completes with [DlnaSessionException] —
/// an awaited caller learns the truth instead of waiting forever.
final class DlnaCommandQueue {
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  bool _disposed = false;

  /// How many commands are queued but not started.
  int get queued => _generation - _finished;

  int _finished = 0;

  /// Submits [action] to run after everything before it.
  ///
  /// Throws [DlnaSessionException] when the queue is disposed. The
  /// returned future completes with [DlnaSessionException] when the
  /// command was cancelled before it started, and with the action's own
  /// error when it failed while running.
  Future<T> submit<T>(Future<T> Function() action) {
    if (_disposed) {
      throw const DlnaSessionException('session queue is disposed');
    }
    final generation = _generation;
    final run = _tail.then((_) {
      if (generation != _generation) {
        throw const DlnaSessionException('command cancelled');
      }
      return action();
    });
    _tail = run.then(
      (_) {
        _finished++;
      },
      onError: (_) {
        _finished++;
      },
    );
    return run;
  }

  /// Drops every queued-but-not-started command. Running commands run
  /// to completion: a `SetAVTransportURI` already on the wire is not
  /// interruptible from here.
  void cancelPending() {
    _generation++;
  }

  /// Rejects all future submissions and waits for the in-flight tail.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    cancelPending();
    await _tail;
  }
}
