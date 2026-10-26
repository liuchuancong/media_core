// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SourceRequest extends SourceRequest {
  @override
  final RequestId id;
  @override
  final SourceId? sourceId;
  @override
  final Uri? uri;
  @override
  final SourceType type;
  @override
  final SourceHeaders? headers;
  @override
  final bool live;
  @override
  final bool lowLatency;
  @override
  final bool enableCache;
  @override
  final bool allowFallback;
  @override
  final Duration? timeout;
  @override
  final Map<String, Object?> attributes;

  factory _$SourceRequest([void Function(SourceRequestBuilder)? updates]) =>
      (SourceRequestBuilder()..update(updates))._build();

  _$SourceRequest._({
    required this.id,
    this.sourceId,
    this.uri,
    required this.type,
    this.headers,
    required this.live,
    required this.lowLatency,
    required this.enableCache,
    required this.allowFallback,
    this.timeout,
    required this.attributes,
  }) : super._();
  @override
  SourceRequest rebuild(void Function(SourceRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SourceRequestBuilder toBuilder() => SourceRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SourceRequest &&
        id == other.id &&
        sourceId == other.sourceId &&
        uri == other.uri &&
        type == other.type &&
        headers == other.headers &&
        live == other.live &&
        lowLatency == other.lowLatency &&
        enableCache == other.enableCache &&
        allowFallback == other.allowFallback &&
        timeout == other.timeout &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, live.hashCode);
    _$hash = $jc(_$hash, lowLatency.hashCode);
    _$hash = $jc(_$hash, enableCache.hashCode);
    _$hash = $jc(_$hash, allowFallback.hashCode);
    _$hash = $jc(_$hash, timeout.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SourceRequest')
          ..add('id', id)
          ..add('sourceId', sourceId)
          ..add('uri', uri)
          ..add('type', type)
          ..add('headers', headers)
          ..add('live', live)
          ..add('lowLatency', lowLatency)
          ..add('enableCache', enableCache)
          ..add('allowFallback', allowFallback)
          ..add('timeout', timeout)
          ..add('attributes', attributes))
        .toString();
  }
}

class SourceRequestBuilder
    implements Builder<SourceRequest, SourceRequestBuilder> {
  _$SourceRequest? _$v;

  RequestId? _id;
  RequestId? get id => _$this._id;
  set id(RequestId? id) => _$this._id = id;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  SourceType? _type;
  SourceType? get type => _$this._type;
  set type(SourceType? type) => _$this._type = type;

  SourceHeaders? _headers;
  SourceHeaders? get headers => _$this._headers;
  set headers(SourceHeaders? headers) => _$this._headers = headers;

  bool? _live;
  bool? get live => _$this._live;
  set live(bool? live) => _$this._live = live;

  bool? _lowLatency;
  bool? get lowLatency => _$this._lowLatency;
  set lowLatency(bool? lowLatency) => _$this._lowLatency = lowLatency;

  bool? _enableCache;
  bool? get enableCache => _$this._enableCache;
  set enableCache(bool? enableCache) => _$this._enableCache = enableCache;

  bool? _allowFallback;
  bool? get allowFallback => _$this._allowFallback;
  set allowFallback(bool? allowFallback) =>
      _$this._allowFallback = allowFallback;

  Duration? _timeout;
  Duration? get timeout => _$this._timeout;
  set timeout(Duration? timeout) => _$this._timeout = timeout;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  SourceRequestBuilder() {
    SourceRequest._initialize(this);
  }

  SourceRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _sourceId = $v.sourceId;
      _uri = $v.uri;
      _type = $v.type;
      _headers = $v.headers;
      _live = $v.live;
      _lowLatency = $v.lowLatency;
      _enableCache = $v.enableCache;
      _allowFallback = $v.allowFallback;
      _timeout = $v.timeout;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SourceRequest other) {
    _$v = other as _$SourceRequest;
  }

  @override
  void update(void Function(SourceRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SourceRequest build() => _build();

  _$SourceRequest _build() {
    final _$result =
        _$v ??
        _$SourceRequest._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'SourceRequest', 'id'),
          sourceId: sourceId,
          uri: uri,
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'SourceRequest',
            'type',
          ),
          headers: headers,
          live: BuiltValueNullFieldError.checkNotNull(
            live,
            r'SourceRequest',
            'live',
          ),
          lowLatency: BuiltValueNullFieldError.checkNotNull(
            lowLatency,
            r'SourceRequest',
            'lowLatency',
          ),
          enableCache: BuiltValueNullFieldError.checkNotNull(
            enableCache,
            r'SourceRequest',
            'enableCache',
          ),
          allowFallback: BuiltValueNullFieldError.checkNotNull(
            allowFallback,
            r'SourceRequest',
            'allowFallback',
          ),
          timeout: timeout,
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'SourceRequest',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
