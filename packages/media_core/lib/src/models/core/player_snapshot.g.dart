// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSnapshot extends PlayerSnapshot {
  @override
  final PlayerId playerId;
  @override
  final SessionId? sessionId;
  @override
  final RequestId? requestId;
  @override
  final GenerationId? generationId;
  @override
  final SourceId? sourceId;
  @override
  final PlayerMediaType? mediaType;
  @override
  final MediaCapabilities? mediaCapabilities;
  @override
  final PlayerCoreState state;
  @override
  final PlayerOptions options;
  @override
  final PlayerCapabilities capabilities;
  @override
  final PlayerMetrics? metrics;
  @override
  final DateTime? timestamp;

  factory _$PlayerSnapshot([void Function(PlayerSnapshotBuilder)? updates]) =>
      (PlayerSnapshotBuilder()..update(updates))._build();

  _$PlayerSnapshot._({
    required this.playerId,
    this.sessionId,
    this.requestId,
    this.generationId,
    this.sourceId,
    this.mediaType,
    this.mediaCapabilities,
    required this.state,
    required this.options,
    required this.capabilities,
    this.metrics,
    this.timestamp,
  }) : super._();
  @override
  PlayerSnapshot rebuild(void Function(PlayerSnapshotBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerSnapshotBuilder toBuilder() => PlayerSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSnapshot &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        requestId == other.requestId &&
        generationId == other.generationId &&
        sourceId == other.sourceId &&
        mediaType == other.mediaType &&
        mediaCapabilities == other.mediaCapabilities &&
        state == other.state &&
        options == other.options &&
        capabilities == other.capabilities &&
        metrics == other.metrics &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, generationId.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, mediaType.hashCode);
    _$hash = $jc(_$hash, mediaCapabilities.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, options.hashCode);
    _$hash = $jc(_$hash, capabilities.hashCode);
    _$hash = $jc(_$hash, metrics.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSnapshot')
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('requestId', requestId)
          ..add('generationId', generationId)
          ..add('sourceId', sourceId)
          ..add('mediaType', mediaType)
          ..add('mediaCapabilities', mediaCapabilities)
          ..add('state', state)
          ..add('options', options)
          ..add('capabilities', capabilities)
          ..add('metrics', metrics)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class PlayerSnapshotBuilder
    implements Builder<PlayerSnapshot, PlayerSnapshotBuilder> {
  _$PlayerSnapshot? _$v;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  RequestId? _requestId;
  RequestId? get requestId => _$this._requestId;
  set requestId(RequestId? requestId) => _$this._requestId = requestId;

  GenerationId? _generationId;
  GenerationId? get generationId => _$this._generationId;
  set generationId(GenerationId? generationId) =>
      _$this._generationId = generationId;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  PlayerMediaType? _mediaType;
  PlayerMediaType? get mediaType => _$this._mediaType;
  set mediaType(PlayerMediaType? mediaType) => _$this._mediaType = mediaType;

  MediaCapabilities? _mediaCapabilities;
  MediaCapabilities? get mediaCapabilities => _$this._mediaCapabilities;
  set mediaCapabilities(MediaCapabilities? mediaCapabilities) =>
      _$this._mediaCapabilities = mediaCapabilities;

  PlayerCoreState? _state;
  PlayerCoreState? get state => _$this._state;
  set state(PlayerCoreState? state) => _$this._state = state;

  PlayerOptionsBuilder? _options;
  PlayerOptionsBuilder get options =>
      _$this._options ??= PlayerOptionsBuilder();
  set options(PlayerOptionsBuilder? options) => _$this._options = options;

  PlayerCapabilitiesBuilder? _capabilities;
  PlayerCapabilitiesBuilder get capabilities =>
      _$this._capabilities ??= PlayerCapabilitiesBuilder();
  set capabilities(PlayerCapabilitiesBuilder? capabilities) =>
      _$this._capabilities = capabilities;

  PlayerMetrics? _metrics;
  PlayerMetrics? get metrics => _$this._metrics;
  set metrics(PlayerMetrics? metrics) => _$this._metrics = metrics;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  PlayerSnapshotBuilder() {
    PlayerSnapshot._initialize(this);
  }

  PlayerSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _requestId = $v.requestId;
      _generationId = $v.generationId;
      _sourceId = $v.sourceId;
      _mediaType = $v.mediaType;
      _mediaCapabilities = $v.mediaCapabilities;
      _state = $v.state;
      _options = $v.options.toBuilder();
      _capabilities = $v.capabilities.toBuilder();
      _metrics = $v.metrics;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSnapshot other) {
    _$v = other as _$PlayerSnapshot;
  }

  @override
  void update(void Function(PlayerSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSnapshot build() => _build();

  _$PlayerSnapshot _build() {
    _$PlayerSnapshot _$result;
    try {
      _$result =
          _$v ??
          _$PlayerSnapshot._(
            playerId: BuiltValueNullFieldError.checkNotNull(
              playerId,
              r'PlayerSnapshot',
              'playerId',
            ),
            sessionId: sessionId,
            requestId: requestId,
            generationId: generationId,
            sourceId: sourceId,
            mediaType: mediaType,
            mediaCapabilities: mediaCapabilities,
            state: BuiltValueNullFieldError.checkNotNull(
              state,
              r'PlayerSnapshot',
              'state',
            ),
            options: options.build(),
            capabilities: capabilities.build(),
            metrics: metrics,
            timestamp: timestamp,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'options';
        options.build();
        _$failedField = 'capabilities';
        capabilities.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlayerSnapshot',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
