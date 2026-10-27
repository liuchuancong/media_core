import 'dart:async';
import 'dart:io';

import 'package:media_core_logging/src/logger/player_logger.dart';
import 'package:media_core_logging/src/policy/log_formatter.dart';

/// A sink that can be registered on the logger.
///
/// Sinks are callable so they can be passed straight to
/// `PlayerLogger.addSink(sink)` without a wrapper, and classes so a sink that
/// owns resources (a file) can expose `flush`/`close` of its own.
abstract interface class LogSink {
  /// Records one accepted record.
  void call(PlayerLogRecord record);
}

/// Writes records to a rotating file.
///
/// The sink a bug report needs: the console is gone once the app is closed, and
/// a reporter cannot copy a live log. Rotation keeps it from filling the device.
///
/// Writes are buffered and flushed on a size or time trigger, because a log line
/// per frame with a synchronous file write is a way to make the thing you are
/// debugging stutter.
final class LogFileSink implements LogSink {
  /// Creates a file sink writing to [file].
  LogFileSink(
    this.file, {
    this.formatter = const LogFormatter(),
    this.maxBytes = 2 * 1024 * 1024,
    this.maxFiles = 3,
    this.flushInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// File records are appended to.
  final File file;

  /// Line formatter.
  final LogFormatter formatter;

  /// Size at which the file rotates.
  final int maxBytes;

  /// How many rotated files are kept (`file.1`, `file.2`, ...).
  final int maxFiles;

  /// How often buffered lines are written.
  final Duration flushInterval;

  final DateTime Function() _clock;

  final List<String> _buffer = <String>[];

  /// Tail of the flush chain, so writes never interleave.
  Future<void> _pending = Future<void>.value();

  int _flushedBytes = 0;
  DateTime? _lastFlush;
  bool _closed = false;

  /// Lines handed to the file (written or buffered).
  int _lineCount = 0;

  /// Code units buffered but not yet on disk - maintained as a running total,
  /// not a fold over the buffer on every record.
  int _bufferedChars = 0;

  /// Lines written so far, including buffered ones.
  int get writtenLines => _lineCount;

  /// Buffered amount, in the same code-unit unit the flush trigger compares.
  int get bufferedBytes => _bufferedChars;

  /// Whether the sink has been closed.
  bool get isClosed => _closed;

  @override
  void call(PlayerLogRecord record) {
    if (_closed) {
      return;
    }
    final line = formatter.format(record);
    _buffer.add(line);
    _lineCount++;
    _bufferedChars += line.length;

    final now = _clock();
    final due = _lastFlush == null || now.difference(_lastFlush!) >= flushInterval;
    if (due || _bufferedChars >= 64 * 1024) {
      unawaited(flush());
    }
  }

  /// Writes the buffer and rotates the file when it grew past [maxBytes].
  ///
  /// Concurrent calls are serialized rather than run in parallel, and a call
  /// that arrives while a write is in flight waits for it. Both matters: the
  /// `unawaited(flush())` from [call] and an explicit `await flush()` from a
  /// caller must not interleave, and [close] must not return before the bytes it
  /// promised are on disk — a bug report reads the file right after it.
  Future<void> flush() {
    final next = _pending.then((_) => _writeBuffer());
    // The chain has to survive a failure, or one bad write would break every
    // later flush.
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _writeBuffer() async {
    if (_closed || _buffer.isEmpty) {
      _lastFlush = _clock();
      return;
    }

    final lines = _buffer.join('\n');
    _buffer.clear();
    _bufferedChars = 0;
    _lastFlush = _clock();

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString('$lines\n', mode: FileMode.append);
      _flushedBytes = file.existsSync() ? file.lengthSync() : 0;
      if (_flushedBytes >= maxBytes) {
        await _rotate();
      }
    } on Object catch (_) {
      // A log sink that throws would take the code being logged down with it.
      // Losing the line is the correct trade; the caller cannot fix a full disk
      // from inside a log call.
    }
  }

  /// Flushes and releases the sink.
  ///
  /// Waits for writes already in flight, not only for the buffered lines.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    // Records that raced in while the final write was in flight must not be
    // dropped by the flag below: drain until the buffer stays empty.
    while (_buffer.isNotEmpty) {
      await flush();
    }
    _closed = true;
  }

  Future<void> _rotate() async {
    if (maxFiles <= 0) {
      await file.writeAsString('', flush: true);
      _flushedBytes = 0;
      return;
    }

    for (var index = maxFiles - 1; index >= 1; index--) {
      final source = File('${file.path}.$index');
      if (!source.existsSync()) {
        continue;
      }
      await source.rename('${file.path}.${index + 1}');
    }
    if (file.existsSync()) {
      await file.rename('${file.path}.1');
    }
    _flushedBytes = 0;
  }
}
