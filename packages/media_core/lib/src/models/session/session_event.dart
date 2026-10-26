import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/models/session/session_event_type.dart';
import 'package:media_core/src/session/model/session_state.dart';

part 'session_event.g.dart';

/// Represents an event emitted by a player session.
///
/// Session events describe changes happening during
/// a session lifecycle.
///
/// They are intended for:
///
/// - event bus
/// - diagnostics
/// - coordinator
/// - logging
///
/// They do not:
///
/// - execute operations
/// - modify session state
///
/// Those belong to:
///
/// - SessionController
/// - PlayerSession
abstract class SessionEvent implements Built<SessionEvent, SessionEventBuilder> {
  /// Builds an event from a [updates] callback — the codegen entry.
  factory SessionEvent([void Function(SessionEventBuilder)? updates]) = _$SessionEvent;

  /// Creates a session event.
  factory SessionEvent.of({
    required SessionId sessionId,
    required SessionEventType type,
    required DateTime timestamp,
    SessionState? state,
    SourceId? sourceId,
    String? message,
  }) {
    return SessionEvent(
      (builder) => builder
        ..sessionId = sessionId
        ..type = type
        ..timestamp = timestamp
        ..state = state
        ..sourceId = sourceId
        ..message = message,
    );
  }

  SessionEvent._();

  /// Creates session created event.
  factory SessionEvent.created(SessionId sessionId) {
    return SessionEvent.of(sessionId: sessionId, type: SessionEventType.created, timestamp: clock.now());
  }

  /// Creates state changed event.
  factory SessionEvent.stateChanged(SessionId sessionId, SessionState state) {
    return SessionEvent.of(
      sessionId: sessionId,
      type: SessionEventType.stateChanged,
      state: state,
      timestamp: clock.now(),
    );
  }

  /// Creates source changed event.
  factory SessionEvent.sourceChanged(SessionId sessionId, SourceId sourceId) {
    return SessionEvent.of(
      sessionId: sessionId,
      type: SessionEventType.sourceChanged,
      sourceId: sourceId,
      timestamp: clock.now(),
    );
  }

  /// Creates error event.
  factory SessionEvent.error(SessionId sessionId, String message) {
    return SessionEvent.of(
      sessionId: sessionId,
      type: SessionEventType.error,
      message: message,
      timestamp: clock.now(),
    );
  }

  /// Creates disposed event.
  factory SessionEvent.disposed(SessionId sessionId) {
    return SessionEvent.of(sessionId: sessionId, type: SessionEventType.disposed, timestamp: clock.now());
  }

  /// Session identity.
  SessionId get sessionId;

  /// Event type.
  SessionEventType get type;

  /// Related session state.
  SessionState? get state;

  /// Related source.
  SourceId? get sourceId;

  /// Optional message.
  String? get message;

  /// Event timestamp.
  DateTime get timestamp;
}
