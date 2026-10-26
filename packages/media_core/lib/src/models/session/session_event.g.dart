// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SessionEvent extends SessionEvent {
  @override
  final SessionId sessionId;
  @override
  final SessionEventType type;
  @override
  final SessionState? state;
  @override
  final SourceId? sourceId;
  @override
  final String? message;
  @override
  final DateTime timestamp;

  factory _$SessionEvent([void Function(SessionEventBuilder)? updates]) =>
      (SessionEventBuilder()..update(updates))._build();

  _$SessionEvent._({
    required this.sessionId,
    required this.type,
    this.state,
    this.sourceId,
    this.message,
    required this.timestamp,
  }) : super._();
  @override
  SessionEvent rebuild(void Function(SessionEventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SessionEventBuilder toBuilder() => SessionEventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SessionEvent &&
        sessionId == other.sessionId &&
        type == other.type &&
        state == other.state &&
        sourceId == other.sourceId &&
        message == other.message &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SessionEvent')
          ..add('sessionId', sessionId)
          ..add('type', type)
          ..add('state', state)
          ..add('sourceId', sourceId)
          ..add('message', message)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class SessionEventBuilder
    implements Builder<SessionEvent, SessionEventBuilder> {
  _$SessionEvent? _$v;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  SessionEventType? _type;
  SessionEventType? get type => _$this._type;
  set type(SessionEventType? type) => _$this._type = type;

  SessionState? _state;
  SessionState? get state => _$this._state;
  set state(SessionState? state) => _$this._state = state;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  SessionEventBuilder();

  SessionEventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _sessionId = $v.sessionId;
      _type = $v.type;
      _state = $v.state;
      _sourceId = $v.sourceId;
      _message = $v.message;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SessionEvent other) {
    _$v = other as _$SessionEvent;
  }

  @override
  void update(void Function(SessionEventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SessionEvent build() => _build();

  _$SessionEvent _build() {
    final _$result =
        _$v ??
        _$SessionEvent._(
          sessionId: BuiltValueNullFieldError.checkNotNull(
            sessionId,
            r'SessionEvent',
            'sessionId',
          ),
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'SessionEvent',
            'type',
          ),
          state: state,
          sourceId: sourceId,
          message: message,
          timestamp: BuiltValueNullFieldError.checkNotNull(
            timestamp,
            r'SessionEvent',
            'timestamp',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
