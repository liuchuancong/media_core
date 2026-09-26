import 'dart:async';
import 'log_level.dart';
import 'log_category.dart';

/// Represents one diagnostic log record.
///
/// A [PlayerLogRecord] contains the information associated with one
/// diagnostic log entry.
///
/// Responsibilities:
///
/// - describe log severity
/// - describe log category
/// - store the log message
/// - optionally store an error and stack trace
/// - carry structured diagnostic fields
///
/// It does not:
///
/// - write logs to files
/// - format logs for a specific platform
/// - decide whether a log should be emitted
///
/// Those responsibilities belong to:
///
/// - [PlayerLogger]
/// - platform-specific log sinks
final class PlayerLogRecord {
  /// Creates a log record.
  PlayerLogRecord({
    required this.level,
    required this.category,
    required this.message,
    DateTime? timestamp,
    this.error,
    this.stackTrace,
    Map<String, Object?> fields = const {},
  }) : timestamp = timestamp ?? DateTime.now(),
       fields = Map<String, Object?>.unmodifiable(fields);

  /// Log severity.
  final LogLevel level;

  /// Diagnostic category.
  final LogCategory category;

  /// Human-readable log message.
  final String message;

  /// Time at which the record was created.
  final DateTime timestamp;

  /// Optional error associated with the record.
  final Object? error;

  /// Optional stack trace associated with the record.
  final StackTrace? stackTrace;

  /// Structured diagnostic fields.
  ///
  /// Fields are intended for machine-readable diagnostic information and
  /// should not be used as a replacement for the main log message.
  final Map<String, Object?> fields;

  /// Whether this record contains an error.
  bool get hasError {
    return error != null;
  }

  /// Whether this record contains a stack trace.
  bool get hasStackTrace {
    return stackTrace != null;
  }

  @override
  String toString() {
    return 'PlayerLogRecord('
        'level: $level, '
        'category: $category, '
        'message: $message, '
        'timestamp: $timestamp, '
        'error: $error'
        ')';
  }
}

/// Receives diagnostic log records.
///
/// A sink can forward records to a platform logger, file logger, console,
/// telemetry system, or another diagnostic destination.
typedef PlayerLogSink = void Function(PlayerLogRecord record);

/// Provides centralized diagnostic logging for the media core.
///
/// A [PlayerLogger] is responsible for deciding whether a log record should
/// be emitted and forwarding accepted records to the configured sink and
/// reactive log stream.
///
/// Responsibilities:
///
/// - filter logs by minimum level
/// - enable or disable logging
/// - create [PlayerLogRecord] instances
/// - forward records to a log sink
/// - expose emitted records as a stream
///
/// It does not:
///
/// - implement platform-specific logging
/// - persist diagnostic records
/// - collect performance or memory metrics
/// - decide application-specific logging policy
///
/// Those responsibilities belong to:
///
/// - [PlayerLogSink]
/// - [PerformanceMonitor]
/// - [MemoryMonitor]
/// - [DiagnosticsManager]
final class PlayerLogger {
  /// Creates a player logger.
  PlayerLogger({this.minimumLevel = LogLevel.info, this.enabled = true, PlayerLogSink? sink}) : _sink = sink;

  /// Minimum log level accepted by this logger.
  ///
  /// Records below this level are ignored.
  LogLevel minimumLevel;

  /// Whether logging is enabled.
  bool enabled;

  /// Current log sink.
  PlayerLogSink? _sink;

  /// Whether this logger has been disposed.
  bool _disposed = false;

  /// Controller for emitted diagnostic records.
  final StreamController<PlayerLogRecord> _recordsController = StreamController<PlayerLogRecord>.broadcast(sync: true);

  /// Stream of accepted diagnostic records.
  Stream<PlayerLogRecord> get records {
    return _recordsController.stream;
  }

  /// Replaces the current log sink.
  void setSink(PlayerLogSink? sink) {
    _ensureNotDisposed();

    _sink = sink;
  }

  /// Emits a diagnostic log record.
  ///
  /// The record is emitted only when logging is enabled and [level] meets
  /// [minimumLevel].
  void log(
    LogLevel level,
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    _ensureNotDisposed();

    if (!enabled || !level.isAtLeast(minimumLevel)) {
      return;
    }

    final record = PlayerLogRecord(
      level: level,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );

    _sink?.call(record);

    if (!_recordsController.isClosed) {
      _recordsController.add(record);
    }
  }

  /// Emits a trace-level diagnostic record.
  void trace(LogCategory category, String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.trace, category, message, fields: fields);
  }

  /// Emits a debug-level diagnostic record.
  void debug(LogCategory category, String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.debug, category, message, fields: fields);
  }

  /// Emits an informational diagnostic record.
  void info(LogCategory category, String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.info, category, message, fields: fields);
  }

  /// Emits a warning diagnostic record.
  void warning(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    log(LogLevel.warning, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Emits an error diagnostic record.
  void error(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    log(LogLevel.error, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Emits a critical diagnostic record.
  void critical(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    log(LogLevel.critical, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Disposes the logger.
  ///
  /// After disposal, no new records may be emitted.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _sink = null;

    await _recordsController.close();
  }

  /// Ensures the logger has not been disposed.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PlayerLogger has been disposed.');
    }
  }
}
