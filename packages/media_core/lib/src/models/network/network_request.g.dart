// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NetworkRequest extends NetworkRequest {
  @override
  final Uri uri;
  @override
  final String method;
  @override
  final SourceHeaders? headers;
  @override
  final Object? body;
  @override
  final Duration? connectTimeout;
  @override
  final Duration? receiveTimeout;
  @override
  final int maxRetries;
  @override
  final bool cacheable;
  @override
  final Map<String, Object?>? metadata;

  factory _$NetworkRequest([void Function(NetworkRequestBuilder)? updates]) =>
      (NetworkRequestBuilder()..update(updates))._build();

  _$NetworkRequest._({
    required this.uri,
    required this.method,
    this.headers,
    this.body,
    this.connectTimeout,
    this.receiveTimeout,
    required this.maxRetries,
    required this.cacheable,
    this.metadata,
  }) : super._();
  @override
  NetworkRequest rebuild(void Function(NetworkRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NetworkRequestBuilder toBuilder() => NetworkRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NetworkRequest &&
        uri == other.uri &&
        method == other.method &&
        headers == other.headers &&
        body == other.body &&
        connectTimeout == other.connectTimeout &&
        receiveTimeout == other.receiveTimeout &&
        maxRetries == other.maxRetries &&
        cacheable == other.cacheable &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, method.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, body.hashCode);
    _$hash = $jc(_$hash, connectTimeout.hashCode);
    _$hash = $jc(_$hash, receiveTimeout.hashCode);
    _$hash = $jc(_$hash, maxRetries.hashCode);
    _$hash = $jc(_$hash, cacheable.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NetworkRequest')
          ..add('uri', uri)
          ..add('method', method)
          ..add('headers', headers)
          ..add('body', body)
          ..add('connectTimeout', connectTimeout)
          ..add('receiveTimeout', receiveTimeout)
          ..add('maxRetries', maxRetries)
          ..add('cacheable', cacheable)
          ..add('metadata', metadata))
        .toString();
  }
}

class NetworkRequestBuilder
    implements Builder<NetworkRequest, NetworkRequestBuilder> {
  _$NetworkRequest? _$v;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  String? _method;
  String? get method => _$this._method;
  set method(String? method) => _$this._method = method;

  SourceHeaders? _headers;
  SourceHeaders? get headers => _$this._headers;
  set headers(SourceHeaders? headers) => _$this._headers = headers;

  Object? _body;
  Object? get body => _$this._body;
  set body(Object? body) => _$this._body = body;

  Duration? _connectTimeout;
  Duration? get connectTimeout => _$this._connectTimeout;
  set connectTimeout(Duration? connectTimeout) =>
      _$this._connectTimeout = connectTimeout;

  Duration? _receiveTimeout;
  Duration? get receiveTimeout => _$this._receiveTimeout;
  set receiveTimeout(Duration? receiveTimeout) =>
      _$this._receiveTimeout = receiveTimeout;

  int? _maxRetries;
  int? get maxRetries => _$this._maxRetries;
  set maxRetries(int? maxRetries) => _$this._maxRetries = maxRetries;

  bool? _cacheable;
  bool? get cacheable => _$this._cacheable;
  set cacheable(bool? cacheable) => _$this._cacheable = cacheable;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  NetworkRequestBuilder() {
    NetworkRequest._initialize(this);
  }

  NetworkRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _uri = $v.uri;
      _method = $v.method;
      _headers = $v.headers;
      _body = $v.body;
      _connectTimeout = $v.connectTimeout;
      _receiveTimeout = $v.receiveTimeout;
      _maxRetries = $v.maxRetries;
      _cacheable = $v.cacheable;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NetworkRequest other) {
    _$v = other as _$NetworkRequest;
  }

  @override
  void update(void Function(NetworkRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NetworkRequest build() => _build();

  _$NetworkRequest _build() {
    final _$result =
        _$v ??
        _$NetworkRequest._(
          uri: BuiltValueNullFieldError.checkNotNull(
            uri,
            r'NetworkRequest',
            'uri',
          ),
          method: BuiltValueNullFieldError.checkNotNull(
            method,
            r'NetworkRequest',
            'method',
          ),
          headers: headers,
          body: body,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          maxRetries: BuiltValueNullFieldError.checkNotNull(
            maxRetries,
            r'NetworkRequest',
            'maxRetries',
          ),
          cacheable: BuiltValueNullFieldError.checkNotNull(
            cacheable,
            r'NetworkRequest',
            'cacheable',
          ),
          metadata: metadata,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
