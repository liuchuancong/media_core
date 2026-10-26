// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_context.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SessionContext extends SessionContext {
  @override
  final PlayerId playerId;
  @override
  final SessionId sessionId;
  @override
  final GenerationId generationId;
  @override
  final SourceId sourceId;
  @override
  final PlayerSource source;
  @override
  final PlayerPolicy policy;
  @override
  final PlatformCapabilities platform;

  factory _$SessionContext([void Function(SessionContextBuilder)? updates]) =>
      (SessionContextBuilder()..update(updates))._build();

  _$SessionContext._({
    required this.playerId,
    required this.sessionId,
    required this.generationId,
    required this.sourceId,
    required this.source,
    required this.policy,
    required this.platform,
  }) : super._();
  @override
  SessionContext rebuild(void Function(SessionContextBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SessionContextBuilder toBuilder() => SessionContextBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SessionContext &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        generationId == other.generationId &&
        sourceId == other.sourceId &&
        source == other.source &&
        policy == other.policy &&
        platform == other.platform;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, generationId.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, source.hashCode);
    _$hash = $jc(_$hash, policy.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SessionContext')
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('generationId', generationId)
          ..add('sourceId', sourceId)
          ..add('source', source)
          ..add('policy', policy)
          ..add('platform', platform))
        .toString();
  }
}

class SessionContextBuilder
    implements Builder<SessionContext, SessionContextBuilder> {
  _$SessionContext? _$v;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  GenerationId? _generationId;
  GenerationId? get generationId => _$this._generationId;
  set generationId(GenerationId? generationId) =>
      _$this._generationId = generationId;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  PlayerSource? _source;
  PlayerSource? get source => _$this._source;
  set source(PlayerSource? source) => _$this._source = source;

  PlayerPolicy? _policy;
  PlayerPolicy? get policy => _$this._policy;
  set policy(PlayerPolicy? policy) => _$this._policy = policy;

  PlatformCapabilities? _platform;
  PlatformCapabilities? get platform => _$this._platform;
  set platform(PlatformCapabilities? platform) => _$this._platform = platform;

  SessionContextBuilder() {
    SessionContext._initialize(this);
  }

  SessionContextBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _generationId = $v.generationId;
      _sourceId = $v.sourceId;
      _source = $v.source;
      _policy = $v.policy;
      _platform = $v.platform;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SessionContext other) {
    _$v = other as _$SessionContext;
  }

  @override
  void update(void Function(SessionContextBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SessionContext build() => _build();

  _$SessionContext _build() {
    final _$result =
        _$v ??
        _$SessionContext._(
          playerId: BuiltValueNullFieldError.checkNotNull(
            playerId,
            r'SessionContext',
            'playerId',
          ),
          sessionId: BuiltValueNullFieldError.checkNotNull(
            sessionId,
            r'SessionContext',
            'sessionId',
          ),
          generationId: BuiltValueNullFieldError.checkNotNull(
            generationId,
            r'SessionContext',
            'generationId',
          ),
          sourceId: BuiltValueNullFieldError.checkNotNull(
            sourceId,
            r'SessionContext',
            'sourceId',
          ),
          source: BuiltValueNullFieldError.checkNotNull(
            source,
            r'SessionContext',
            'source',
          ),
          policy: BuiltValueNullFieldError.checkNotNull(
            policy,
            r'SessionContext',
            'policy',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'SessionContext',
            'platform',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
