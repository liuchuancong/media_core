// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_operation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SessionOperation extends SessionOperation {
  @override
  final OperationId id;
  @override
  final SessionId sessionId;
  @override
  final SessionOperationType type;
  @override
  final SessionOperationState state;
  @override
  final String? error;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;

  factory _$SessionOperation([
    void Function(SessionOperationBuilder)? updates,
  ]) => (SessionOperationBuilder()..update(updates))._build();

  _$SessionOperation._({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.state,
    this.error,
    this.startedAt,
    this.completedAt,
  }) : super._();
  @override
  SessionOperation rebuild(void Function(SessionOperationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SessionOperationBuilder toBuilder() =>
      SessionOperationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SessionOperation &&
        id == other.id &&
        sessionId == other.sessionId &&
        type == other.type &&
        state == other.state &&
        error == other.error &&
        startedAt == other.startedAt &&
        completedAt == other.completedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jc(_$hash, startedAt.hashCode);
    _$hash = $jc(_$hash, completedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SessionOperation')
          ..add('id', id)
          ..add('sessionId', sessionId)
          ..add('type', type)
          ..add('state', state)
          ..add('error', error)
          ..add('startedAt', startedAt)
          ..add('completedAt', completedAt))
        .toString();
  }
}

class SessionOperationBuilder
    implements Builder<SessionOperation, SessionOperationBuilder> {
  _$SessionOperation? _$v;

  OperationId? _id;
  OperationId? get id => _$this._id;
  set id(OperationId? id) => _$this._id = id;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  SessionOperationType? _type;
  SessionOperationType? get type => _$this._type;
  set type(SessionOperationType? type) => _$this._type = type;

  SessionOperationState? _state;
  SessionOperationState? get state => _$this._state;
  set state(SessionOperationState? state) => _$this._state = state;

  String? _error;
  String? get error => _$this._error;
  set error(String? error) => _$this._error = error;

  DateTime? _startedAt;
  DateTime? get startedAt => _$this._startedAt;
  set startedAt(DateTime? startedAt) => _$this._startedAt = startedAt;

  DateTime? _completedAt;
  DateTime? get completedAt => _$this._completedAt;
  set completedAt(DateTime? completedAt) => _$this._completedAt = completedAt;

  SessionOperationBuilder() {
    SessionOperation._initialize(this);
  }

  SessionOperationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _sessionId = $v.sessionId;
      _type = $v.type;
      _state = $v.state;
      _error = $v.error;
      _startedAt = $v.startedAt;
      _completedAt = $v.completedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SessionOperation other) {
    _$v = other as _$SessionOperation;
  }

  @override
  void update(void Function(SessionOperationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SessionOperation build() => _build();

  _$SessionOperation _build() {
    final _$result =
        _$v ??
        _$SessionOperation._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'SessionOperation',
            'id',
          ),
          sessionId: BuiltValueNullFieldError.checkNotNull(
            sessionId,
            r'SessionOperation',
            'sessionId',
          ),
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'SessionOperation',
            'type',
          ),
          state: BuiltValueNullFieldError.checkNotNull(
            state,
            r'SessionOperation',
            'state',
          ),
          error: error,
          startedAt: startedAt,
          completedAt: completedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
