// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_network.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformNetwork extends PlatformNetwork {
  @override
  final bool enabled;
  @override
  final bool http;
  @override
  final bool https;
  @override
  final bool hls;
  @override
  final bool dash;
  @override
  final bool rtmp;
  @override
  final bool websocket;
  @override
  final bool proxy;
  @override
  final bool tls;
  @override
  final int maxConnections;

  factory _$PlatformNetwork([void Function(PlatformNetworkBuilder)? updates]) =>
      (PlatformNetworkBuilder()..update(updates))._build();

  _$PlatformNetwork._({
    required this.enabled,
    required this.http,
    required this.https,
    required this.hls,
    required this.dash,
    required this.rtmp,
    required this.websocket,
    required this.proxy,
    required this.tls,
    required this.maxConnections,
  }) : super._();
  @override
  PlatformNetwork rebuild(void Function(PlatformNetworkBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformNetworkBuilder toBuilder() => PlatformNetworkBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformNetwork &&
        enabled == other.enabled &&
        http == other.http &&
        https == other.https &&
        hls == other.hls &&
        dash == other.dash &&
        rtmp == other.rtmp &&
        websocket == other.websocket &&
        proxy == other.proxy &&
        tls == other.tls &&
        maxConnections == other.maxConnections;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, http.hashCode);
    _$hash = $jc(_$hash, https.hashCode);
    _$hash = $jc(_$hash, hls.hashCode);
    _$hash = $jc(_$hash, dash.hashCode);
    _$hash = $jc(_$hash, rtmp.hashCode);
    _$hash = $jc(_$hash, websocket.hashCode);
    _$hash = $jc(_$hash, proxy.hashCode);
    _$hash = $jc(_$hash, tls.hashCode);
    _$hash = $jc(_$hash, maxConnections.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformNetwork')
          ..add('enabled', enabled)
          ..add('http', http)
          ..add('https', https)
          ..add('hls', hls)
          ..add('dash', dash)
          ..add('rtmp', rtmp)
          ..add('websocket', websocket)
          ..add('proxy', proxy)
          ..add('tls', tls)
          ..add('maxConnections', maxConnections))
        .toString();
  }
}

class PlatformNetworkBuilder
    implements Builder<PlatformNetwork, PlatformNetworkBuilder> {
  _$PlatformNetwork? _$v;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _http;
  bool? get http => _$this._http;
  set http(bool? http) => _$this._http = http;

  bool? _https;
  bool? get https => _$this._https;
  set https(bool? https) => _$this._https = https;

  bool? _hls;
  bool? get hls => _$this._hls;
  set hls(bool? hls) => _$this._hls = hls;

  bool? _dash;
  bool? get dash => _$this._dash;
  set dash(bool? dash) => _$this._dash = dash;

  bool? _rtmp;
  bool? get rtmp => _$this._rtmp;
  set rtmp(bool? rtmp) => _$this._rtmp = rtmp;

  bool? _websocket;
  bool? get websocket => _$this._websocket;
  set websocket(bool? websocket) => _$this._websocket = websocket;

  bool? _proxy;
  bool? get proxy => _$this._proxy;
  set proxy(bool? proxy) => _$this._proxy = proxy;

  bool? _tls;
  bool? get tls => _$this._tls;
  set tls(bool? tls) => _$this._tls = tls;

  int? _maxConnections;
  int? get maxConnections => _$this._maxConnections;
  set maxConnections(int? maxConnections) =>
      _$this._maxConnections = maxConnections;

  PlatformNetworkBuilder() {
    PlatformNetwork._initialize(this);
  }

  PlatformNetworkBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _enabled = $v.enabled;
      _http = $v.http;
      _https = $v.https;
      _hls = $v.hls;
      _dash = $v.dash;
      _rtmp = $v.rtmp;
      _websocket = $v.websocket;
      _proxy = $v.proxy;
      _tls = $v.tls;
      _maxConnections = $v.maxConnections;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformNetwork other) {
    _$v = other as _$PlatformNetwork;
  }

  @override
  void update(void Function(PlatformNetworkBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformNetwork build() => _build();

  _$PlatformNetwork _build() {
    final _$result =
        _$v ??
        _$PlatformNetwork._(
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'PlatformNetwork',
            'enabled',
          ),
          http: BuiltValueNullFieldError.checkNotNull(
            http,
            r'PlatformNetwork',
            'http',
          ),
          https: BuiltValueNullFieldError.checkNotNull(
            https,
            r'PlatformNetwork',
            'https',
          ),
          hls: BuiltValueNullFieldError.checkNotNull(
            hls,
            r'PlatformNetwork',
            'hls',
          ),
          dash: BuiltValueNullFieldError.checkNotNull(
            dash,
            r'PlatformNetwork',
            'dash',
          ),
          rtmp: BuiltValueNullFieldError.checkNotNull(
            rtmp,
            r'PlatformNetwork',
            'rtmp',
          ),
          websocket: BuiltValueNullFieldError.checkNotNull(
            websocket,
            r'PlatformNetwork',
            'websocket',
          ),
          proxy: BuiltValueNullFieldError.checkNotNull(
            proxy,
            r'PlatformNetwork',
            'proxy',
          ),
          tls: BuiltValueNullFieldError.checkNotNull(
            tls,
            r'PlatformNetwork',
            'tls',
          ),
          maxConnections: BuiltValueNullFieldError.checkNotNull(
            maxConnections,
            r'PlatformNetwork',
            'maxConnections',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
