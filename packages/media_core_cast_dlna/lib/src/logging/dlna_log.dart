/// Package-side structured logging (§25).
///
/// The protocol layers are pure Dart and must not reach into any host
/// logging framework, so they emit neutral [DlnaLogEvent]s into a
/// process-wide [DlnaLog.sink]. Whoever composes the package picks the
/// destination: `DlnaCastBackend` bridges the sink into media_core's
/// `MediaCoreLog` automatically; standalone hosts assign their own
/// sink (or nothing — the default drops every record).
///
/// Categories mirror §25.1 (discovery, ssdp, description, soap, gena,
/// media selection, media server, playback, session, network,
/// compatibility); levels mirror §25.2: debug for wire noise, info for
/// lifecycle, warning for degradation that has a fallback, error for
/// failures a host must see.
///
/// Privacy rules (§22.5, §25.3): never log tokens, credentials, or
/// local file paths; media URLs are logged with their query stripped
/// by the emitters, not by the sink.
library;

/// Severity of a [DlnaLogEvent].
///
/// Mirrors §25.2: debug for wire noise, info for lifecycle milestones,
/// warning for degradation that has a fallback, error for failures a
/// host must see.
enum DlnaLogLevel {
  /// Wire-level noise and internal state transitions.
  debug,

  /// Lifecycle milestones (device found, session connected, ...).
  info,

  /// Degradation with a fallback (GENA lost, retry scheduled, ...).
  warning,

  /// Failures a host must see (recovery exhausted, bind failed).
  error,
}

/// Functional area a [DlnaLogEvent] came from (§25.1).
///
/// Categories let a sink filter or route by subsystem without parsing
/// message text.
enum DlnaLogCategory {
  /// Discovery pipeline (manager-level lifecycle).
  discovery,

  /// SSDP wire layer (socket, M-SEARCH, NOTIFY).
  ssdp,

  /// Device/SCPD description fetching and parsing.
  deviceDescription,

  /// SOAP control exchanges.
  soap,

  /// GENA eventing.
  gena,

  /// Capability probing and media selection.
  mediaSelection,

  /// The local media HTTP server.
  mediaServer,

  /// Cast playback commands and state.
  playback,

  /// Session lifecycle, recovery, volume.
  session,

  /// Compatibility profile resolution.
  compatibility,
}

/// One structured record.
final class DlnaLogEvent {
  /// Creates an event.
  const DlnaLogEvent({
    required this.time,
    required this.category,
    required this.level,
    required this.message,
    this.error,
    this.fields = const <String, Object?>{},
  });

  /// The area the record came from.
  final DlnaLogCategory category;

  /// The severity.
  final DlnaLogLevel level;

  /// Human-readable summary (stable phrasing, not prose for users).
  final String message;

  /// The underlying error, when one exists.
  final Object? error;

  /// Structured context; emitters keep it free of secrets and paths.
  final Map<String, Object?> fields;

  /// When the record was created.
  final DateTime time;

  @override
  String toString() =>
      'DlnaLog(${level.name}, ${category.name}, $message'
      '${fields.isEmpty ? '' : ', $fields'})';
}

/// A log destination: one call per record, never throwing into the
/// emitter (implementations must swallow their own errors).
typedef DlnaLogSink = void Function(DlnaLogEvent event);

/// The package's log hub.
abstract final class DlnaLog {
  /// The current destination; null (the default) drops every record.
  /// Assign once at composition time; reads are unsynchronized, so
  /// swapping sinks while sessions run is not supported.
  static DlnaLogSink? sink;

  /// Emits [level] record into the sink, if one is installed. Sink
  /// errors are swallowed: a broken logger must never break casting.
  static void emit(
    DlnaLogCategory category, {
    required DlnaLogLevel level,
    required String message,
    Object? error,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    final destination = sink;
    if (destination == null) {
      return;
    }
    try {
      destination(
        DlnaLogEvent(
          category: category,
          level: level,
          message: message,
          error: error,
          fields: fields,
          time: DateTime.now(),
        ),
      );
    } on Object {
      // A logging framework that throws would otherwise take the cast
      // down with it.
    }
  }

  /// Debug-severity convenience.
  static void debug(
    DlnaLogCategory category,
    String message, {
    Object? error,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    emit(category, level: DlnaLogLevel.debug, message: message, error: error, fields: fields);
  }

  /// Info-severity convenience.
  static void info(
    DlnaLogCategory category,
    String message, {
    Object? error,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    emit(category, level: DlnaLogLevel.info, message: message, error: error, fields: fields);
  }

  /// Warning-severity convenience.
  static void warning(
    DlnaLogCategory category,
    String message, {
    Object? error,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    emit(category, level: DlnaLogLevel.warning, message: message, error: error, fields: fields);
  }

  /// Error-severity convenience.
  static void error(
    DlnaLogCategory category,
    String message, {
    Object? error,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    emit(category, level: DlnaLogLevel.error, message: message, error: error, fields: fields);
  }
}

/// Strip query/fragment from a media URL before logging it: cast URLs
/// carry the media server's access token (§22.3), and tokens never
/// belong in logs.
String loggableUrl(Uri url) {
  final withoutQuery = url.removeFragment().replace(query: '');
  var text = withoutQuery.toString();
  if (text.endsWith('?')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
