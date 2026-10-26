// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_error.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerError extends PlayerError {
  @override
  final PlayerErrorCode code;
  @override
  final String message;
  @override
  final PlayerErrorCategory? category;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;
  @override
  final PlayerId? playerId;
  @override
  final SessionId? sessionId;
  @override
  final SourceId? sourceId;
  @override
  final RequestId? requestId;
  @override
  final GenerationId? generationId;
  @override
  final DateTime? timestamp;
  @override
  final Map<String, Object?> metadata;

  factory _$PlayerError([void Function(PlayerErrorBuilder)? updates]) =>
      (PlayerErrorBuilder()..update(updates))._build();

  _$PlayerError._({
    required this.code,
    required this.message,
    this.category,
    this.cause,
    this.stackTrace,
    this.playerId,
    this.sessionId,
    this.sourceId,
    this.requestId,
    this.generationId,
    this.timestamp,
    required this.metadata,
  }) : super._();
  @override
  PlayerError rebuild(void Function(PlayerErrorBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerErrorBuilder toBuilder() => PlayerErrorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerError &&
        code == other.code &&
        message == other.message &&
        category == other.category &&
        cause == other.cause &&
        stackTrace == other.stackTrace &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        sourceId == other.sourceId &&
        requestId == other.requestId &&
        generationId == other.generationId &&
        timestamp == other.timestamp &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, category.hashCode);
    _$hash = $jc(_$hash, cause.hashCode);
    _$hash = $jc(_$hash, stackTrace.hashCode);
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, generationId.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerError')
          ..add('code', code)
          ..add('message', message)
          ..add('category', category)
          ..add('cause', cause)
          ..add('stackTrace', stackTrace)
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('sourceId', sourceId)
          ..add('requestId', requestId)
          ..add('generationId', generationId)
          ..add('timestamp', timestamp)
          ..add('metadata', metadata))
        .toString();
  }
}

class PlayerErrorBuilder implements Builder<PlayerError, PlayerErrorBuilder> {
  _$PlayerError? _$v;

  PlayerErrorCode? _code;
  PlayerErrorCode? get code => _$this._code;
  set code(PlayerErrorCode? code) => _$this._code = code;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  PlayerErrorCategory? _category;
  PlayerErrorCategory? get category => _$this._category;
  set category(PlayerErrorCategory? category) => _$this._category = category;

  Object? _cause;
  Object? get cause => _$this._cause;
  set cause(Object? cause) => _$this._cause = cause;

  StackTrace? _stackTrace;
  StackTrace? get stackTrace => _$this._stackTrace;
  set stackTrace(StackTrace? stackTrace) => _$this._stackTrace = stackTrace;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  RequestId? _requestId;
  RequestId? get requestId => _$this._requestId;
  set requestId(RequestId? requestId) => _$this._requestId = requestId;

  GenerationId? _generationId;
  GenerationId? get generationId => _$this._generationId;
  set generationId(GenerationId? generationId) =>
      _$this._generationId = generationId;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  PlayerErrorBuilder() {
    PlayerError._initialize(this);
  }

  PlayerErrorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _message = $v.message;
      _category = $v.category;
      _cause = $v.cause;
      _stackTrace = $v.stackTrace;
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _sourceId = $v.sourceId;
      _requestId = $v.requestId;
      _generationId = $v.generationId;
      _timestamp = $v.timestamp;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerError other) {
    _$v = other as _$PlayerError;
  }

  @override
  void update(void Function(PlayerErrorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerError build() => _build();

  _$PlayerError _build() {
    final _$result =
        _$v ??
        _$PlayerError._(
          code: BuiltValueNullFieldError.checkNotNull(
            code,
            r'PlayerError',
            'code',
          ),
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'PlayerError',
            'message',
          ),
          category: category,
          cause: cause,
          stackTrace: stackTrace,
          playerId: playerId,
          sessionId: sessionId,
          sourceId: sourceId,
          requestId: requestId,
          generationId: generationId,
          timestamp: timestamp,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'PlayerError',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
