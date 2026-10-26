// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_condition.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NetworkCondition extends NetworkCondition {
  @override
  final bool connected;
  @override
  final NetworkType type;
  @override
  final NetworkQuality quality;
  @override
  final int? downloadBandwidth;
  @override
  final int? uploadBandwidth;
  @override
  final int? latency;
  @override
  final bool metered;
  @override
  final bool expensive;
  @override
  final DateTime? timestamp;

  factory _$NetworkCondition([
    void Function(NetworkConditionBuilder)? updates,
  ]) => (NetworkConditionBuilder()..update(updates))._build();

  _$NetworkCondition._({
    required this.connected,
    required this.type,
    required this.quality,
    this.downloadBandwidth,
    this.uploadBandwidth,
    this.latency,
    required this.metered,
    required this.expensive,
    this.timestamp,
  }) : super._();
  @override
  NetworkCondition rebuild(void Function(NetworkConditionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NetworkConditionBuilder toBuilder() =>
      NetworkConditionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NetworkCondition &&
        connected == other.connected &&
        type == other.type &&
        quality == other.quality &&
        downloadBandwidth == other.downloadBandwidth &&
        uploadBandwidth == other.uploadBandwidth &&
        latency == other.latency &&
        metered == other.metered &&
        expensive == other.expensive &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, connected.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, quality.hashCode);
    _$hash = $jc(_$hash, downloadBandwidth.hashCode);
    _$hash = $jc(_$hash, uploadBandwidth.hashCode);
    _$hash = $jc(_$hash, latency.hashCode);
    _$hash = $jc(_$hash, metered.hashCode);
    _$hash = $jc(_$hash, expensive.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NetworkCondition')
          ..add('connected', connected)
          ..add('type', type)
          ..add('quality', quality)
          ..add('downloadBandwidth', downloadBandwidth)
          ..add('uploadBandwidth', uploadBandwidth)
          ..add('latency', latency)
          ..add('metered', metered)
          ..add('expensive', expensive)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class NetworkConditionBuilder
    implements Builder<NetworkCondition, NetworkConditionBuilder> {
  _$NetworkCondition? _$v;

  bool? _connected;
  bool? get connected => _$this._connected;
  set connected(bool? connected) => _$this._connected = connected;

  NetworkType? _type;
  NetworkType? get type => _$this._type;
  set type(NetworkType? type) => _$this._type = type;

  NetworkQuality? _quality;
  NetworkQuality? get quality => _$this._quality;
  set quality(NetworkQuality? quality) => _$this._quality = quality;

  int? _downloadBandwidth;
  int? get downloadBandwidth => _$this._downloadBandwidth;
  set downloadBandwidth(int? downloadBandwidth) =>
      _$this._downloadBandwidth = downloadBandwidth;

  int? _uploadBandwidth;
  int? get uploadBandwidth => _$this._uploadBandwidth;
  set uploadBandwidth(int? uploadBandwidth) =>
      _$this._uploadBandwidth = uploadBandwidth;

  int? _latency;
  int? get latency => _$this._latency;
  set latency(int? latency) => _$this._latency = latency;

  bool? _metered;
  bool? get metered => _$this._metered;
  set metered(bool? metered) => _$this._metered = metered;

  bool? _expensive;
  bool? get expensive => _$this._expensive;
  set expensive(bool? expensive) => _$this._expensive = expensive;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  NetworkConditionBuilder() {
    NetworkCondition._initialize(this);
  }

  NetworkConditionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _connected = $v.connected;
      _type = $v.type;
      _quality = $v.quality;
      _downloadBandwidth = $v.downloadBandwidth;
      _uploadBandwidth = $v.uploadBandwidth;
      _latency = $v.latency;
      _metered = $v.metered;
      _expensive = $v.expensive;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NetworkCondition other) {
    _$v = other as _$NetworkCondition;
  }

  @override
  void update(void Function(NetworkConditionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NetworkCondition build() => _build();

  _$NetworkCondition _build() {
    final _$result =
        _$v ??
        _$NetworkCondition._(
          connected: BuiltValueNullFieldError.checkNotNull(
            connected,
            r'NetworkCondition',
            'connected',
          ),
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'NetworkCondition',
            'type',
          ),
          quality: BuiltValueNullFieldError.checkNotNull(
            quality,
            r'NetworkCondition',
            'quality',
          ),
          downloadBandwidth: downloadBandwidth,
          uploadBandwidth: uploadBandwidth,
          latency: latency,
          metered: BuiltValueNullFieldError.checkNotNull(
            metered,
            r'NetworkCondition',
            'metered',
          ),
          expensive: BuiltValueNullFieldError.checkNotNull(
            expensive,
            r'NetworkCondition',
            'expensive',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
