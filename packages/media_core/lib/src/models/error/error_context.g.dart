// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_context.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ErrorContext extends ErrorContext {
  @override
  final PlayerId? playerId;
  @override
  final SessionId? sessionId;
  @override
  final SlotId? slotId;
  @override
  final SourceId? sourceId;
  @override
  final RequestId? requestId;
  @override
  final OperationId? operationId;
  @override
  final GenerationId? generationId;
  @override
  final String? operation;
  @override
  final String? lineId;
  @override
  final String? quality;
  @override
  final String? uri;
  @override
  final String? platform;
  @override
  final String? backend;
  @override
  final String? adapter;
  @override
  final String? state;
  @override
  final Map<String, Object?> metadata;

  factory _$ErrorContext([void Function(ErrorContextBuilder)? updates]) =>
      (ErrorContextBuilder()..update(updates))._build();

  _$ErrorContext._({
    this.playerId,
    this.sessionId,
    this.slotId,
    this.sourceId,
    this.requestId,
    this.operationId,
    this.generationId,
    this.operation,
    this.lineId,
    this.quality,
    this.uri,
    this.platform,
    this.backend,
    this.adapter,
    this.state,
    required this.metadata,
  }) : super._();
  @override
  ErrorContext rebuild(void Function(ErrorContextBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ErrorContextBuilder toBuilder() => ErrorContextBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ErrorContext &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        slotId == other.slotId &&
        sourceId == other.sourceId &&
        requestId == other.requestId &&
        operationId == other.operationId &&
        generationId == other.generationId &&
        operation == other.operation &&
        lineId == other.lineId &&
        quality == other.quality &&
        uri == other.uri &&
        platform == other.platform &&
        backend == other.backend &&
        adapter == other.adapter &&
        state == other.state &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, slotId.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, generationId.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, lineId.hashCode);
    _$hash = $jc(_$hash, quality.hashCode);
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, backend.hashCode);
    _$hash = $jc(_$hash, adapter.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ErrorContext')
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('slotId', slotId)
          ..add('sourceId', sourceId)
          ..add('requestId', requestId)
          ..add('operationId', operationId)
          ..add('generationId', generationId)
          ..add('operation', operation)
          ..add('lineId', lineId)
          ..add('quality', quality)
          ..add('uri', uri)
          ..add('platform', platform)
          ..add('backend', backend)
          ..add('adapter', adapter)
          ..add('state', state)
          ..add('metadata', metadata))
        .toString();
  }
}

class ErrorContextBuilder
    implements Builder<ErrorContext, ErrorContextBuilder> {
  _$ErrorContext? _$v;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  SlotId? _slotId;
  SlotId? get slotId => _$this._slotId;
  set slotId(SlotId? slotId) => _$this._slotId = slotId;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  RequestId? _requestId;
  RequestId? get requestId => _$this._requestId;
  set requestId(RequestId? requestId) => _$this._requestId = requestId;

  OperationId? _operationId;
  OperationId? get operationId => _$this._operationId;
  set operationId(OperationId? operationId) =>
      _$this._operationId = operationId;

  GenerationId? _generationId;
  GenerationId? get generationId => _$this._generationId;
  set generationId(GenerationId? generationId) =>
      _$this._generationId = generationId;

  String? _operation;
  String? get operation => _$this._operation;
  set operation(String? operation) => _$this._operation = operation;

  String? _lineId;
  String? get lineId => _$this._lineId;
  set lineId(String? lineId) => _$this._lineId = lineId;

  String? _quality;
  String? get quality => _$this._quality;
  set quality(String? quality) => _$this._quality = quality;

  String? _uri;
  String? get uri => _$this._uri;
  set uri(String? uri) => _$this._uri = uri;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _backend;
  String? get backend => _$this._backend;
  set backend(String? backend) => _$this._backend = backend;

  String? _adapter;
  String? get adapter => _$this._adapter;
  set adapter(String? adapter) => _$this._adapter = adapter;

  String? _state;
  String? get state => _$this._state;
  set state(String? state) => _$this._state = state;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  ErrorContextBuilder() {
    ErrorContext._initialize(this);
  }

  ErrorContextBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _slotId = $v.slotId;
      _sourceId = $v.sourceId;
      _requestId = $v.requestId;
      _operationId = $v.operationId;
      _generationId = $v.generationId;
      _operation = $v.operation;
      _lineId = $v.lineId;
      _quality = $v.quality;
      _uri = $v.uri;
      _platform = $v.platform;
      _backend = $v.backend;
      _adapter = $v.adapter;
      _state = $v.state;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ErrorContext other) {
    _$v = other as _$ErrorContext;
  }

  @override
  void update(void Function(ErrorContextBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ErrorContext build() => _build();

  _$ErrorContext _build() {
    final _$result =
        _$v ??
        _$ErrorContext._(
          playerId: playerId,
          sessionId: sessionId,
          slotId: slotId,
          sourceId: sourceId,
          requestId: requestId,
          operationId: operationId,
          generationId: generationId,
          operation: operation,
          lineId: lineId,
          quality: quality,
          uri: uri,
          platform: platform,
          backend: backend,
          adapter: adapter,
          state: state,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'ErrorContext',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
