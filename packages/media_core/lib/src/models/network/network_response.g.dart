// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NetworkResponse extends NetworkResponse {
  @override
  final int? statusCode;
  @override
  final Object? data;
  @override
  final Map<String, String>? headers;
  @override
  final Duration? duration;
  @override
  final bool fromCache;
  @override
  final DateTime? timestamp;

  factory _$NetworkResponse([void Function(NetworkResponseBuilder)? updates]) =>
      (NetworkResponseBuilder()..update(updates))._build();

  _$NetworkResponse._({
    this.statusCode,
    this.data,
    this.headers,
    this.duration,
    required this.fromCache,
    this.timestamp,
  }) : super._();
  @override
  NetworkResponse rebuild(void Function(NetworkResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NetworkResponseBuilder toBuilder() => NetworkResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NetworkResponse &&
        statusCode == other.statusCode &&
        data == other.data &&
        headers == other.headers &&
        duration == other.duration &&
        fromCache == other.fromCache &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, statusCode.hashCode);
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, fromCache.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NetworkResponse')
          ..add('statusCode', statusCode)
          ..add('data', data)
          ..add('headers', headers)
          ..add('duration', duration)
          ..add('fromCache', fromCache)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class NetworkResponseBuilder
    implements Builder<NetworkResponse, NetworkResponseBuilder> {
  _$NetworkResponse? _$v;

  int? _statusCode;
  int? get statusCode => _$this._statusCode;
  set statusCode(int? statusCode) => _$this._statusCode = statusCode;

  Object? _data;
  Object? get data => _$this._data;
  set data(Object? data) => _$this._data = data;

  Map<String, String>? _headers;
  Map<String, String>? get headers => _$this._headers;
  set headers(Map<String, String>? headers) => _$this._headers = headers;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  bool? _fromCache;
  bool? get fromCache => _$this._fromCache;
  set fromCache(bool? fromCache) => _$this._fromCache = fromCache;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  NetworkResponseBuilder() {
    NetworkResponse._initialize(this);
  }

  NetworkResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _statusCode = $v.statusCode;
      _data = $v.data;
      _headers = $v.headers;
      _duration = $v.duration;
      _fromCache = $v.fromCache;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NetworkResponse other) {
    _$v = other as _$NetworkResponse;
  }

  @override
  void update(void Function(NetworkResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NetworkResponse build() => _build();

  _$NetworkResponse _build() {
    final _$result =
        _$v ??
        _$NetworkResponse._(
          statusCode: statusCode,
          data: data,
          headers: headers,
          duration: duration,
          fromCache: BuiltValueNullFieldError.checkNotNull(
            fromCache,
            r'NetworkResponse',
            'fromCache',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
