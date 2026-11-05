import 'package:media_core_logging/media_core_logging.dart';

/// A logging destination scripted by tests: captures the
/// [PlayerLogRecord]s the package emits through `MediaCoreLog`.
final class CapturingLogSink {
  /// Every record delivered, in order.
  final List<PlayerLogRecord> records = <PlayerLogRecord>[];

  /// Installs this sink into the logging hub.
  ///
  /// Logging is opt-in in media_core_logging, so installing also turns
  /// the level up; [uninstall] restores the default configuration via
  /// `MediaCoreLog.reset`.
  void install() {
    MediaCoreLog.reset();
    MediaCoreLog.level = LogLevel.trace;
    MediaCoreLog.addSink(add);
  }

  /// Removes this sink from the logging hub.
  void uninstall() {
    MediaCoreLog.reset();
  }

  /// The sink function.
  void add(PlayerLogRecord record) {
    records.add(record);
  }

  /// The first record matching category and level, or null.
  PlayerLogRecord? find(LogCategory category, LogLevel level, {String? messageContains}) {
    for (final record in records.reversed) {
      if (record.category == category && record.level == level) {
        if (messageContains != null && !record.message.contains(messageContains)) {
          continue;
        }
        return record;
      }
    }
    return null;
  }

  /// Whether any record matches category and level.
  bool has(LogCategory category, LogLevel level, {String? messageContains}) =>
      find(category, level, messageContains: messageContains) != null;
}

/// Runs [body] with a capturing sink installed.
Future<T> withLogSink<T>(Future<T> Function(CapturingLogSink sink) body) async {
  final sink = CapturingLogSink()..install();
  try {
    return await body(sink);
  } finally {
    sink.uninstall();
  }
}

/// Wraps a synchronous body with a capturing sink.
T withLogSinkSync<T>(T Function(CapturingLogSink sink) body) {
  final sink = CapturingLogSink()..install();
  try {
    return body(sink);
  } finally {
    sink.uninstall();
  }
}
