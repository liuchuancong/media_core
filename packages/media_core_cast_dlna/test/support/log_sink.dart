import 'package:media_core_cast_dlna/src/logging/dlna_log.dart';

export 'package:media_core_cast_dlna/src/logging/dlna_log.dart'
    show DlnaLog, DlnaLogCategory, DlnaLogEvent, DlnaLogLevel;

/// A logging destination scripted by tests.
final class CapturingLogSink {
  /// Every event delivered, in order.
  final List<DlnaLogEvent> events = <DlnaLogEvent>[];

  /// Installs this sink into the package hub.
  void install() {
    DlnaLog.sink = add;
  }

  /// Removes this sink from the package hub.
  void uninstall() {
    DlnaLog.sink = null;
  }

  /// The sink function.
  void add(DlnaLogEvent event) {
    events.add(event);
  }

  /// The first event matching category and level, or null.
  DlnaLogEvent? find(DlnaLogCategory category, DlnaLogLevel level, {String? messageContains}) {
    for (final event in events.reversed) {
      if (event.category == category && event.level == level) {
        if (messageContains != null && !event.message.contains(messageContains)) {
          continue;
        }
        return event;
      }
    }
    return null;
  }

  /// Whether any event matches category and level.
  bool has(DlnaLogCategory category, DlnaLogLevel level, {String? messageContains}) =>
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
