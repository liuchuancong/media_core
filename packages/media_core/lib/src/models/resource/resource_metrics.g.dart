// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResourceMetrics extends ResourceMetrics {
  @override
  final int decoderCount;
  @override
  final int hardwareDecoderCount;
  @override
  final int memoryBytes;
  @override
  final double bandwidthMbps;
  @override
  final int activePlayers;
  @override
  final int preloadingPlayers;
  @override
  final String thermalState;
  @override
  final DateTime? timestamp;

  factory _$ResourceMetrics([void Function(ResourceMetricsBuilder)? updates]) =>
      (ResourceMetricsBuilder()..update(updates))._build();

  _$ResourceMetrics._({
    required this.decoderCount,
    required this.hardwareDecoderCount,
    required this.memoryBytes,
    required this.bandwidthMbps,
    required this.activePlayers,
    required this.preloadingPlayers,
    required this.thermalState,
    this.timestamp,
  }) : super._();
  @override
  ResourceMetrics rebuild(void Function(ResourceMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResourceMetricsBuilder toBuilder() => ResourceMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResourceMetrics &&
        decoderCount == other.decoderCount &&
        hardwareDecoderCount == other.hardwareDecoderCount &&
        memoryBytes == other.memoryBytes &&
        bandwidthMbps == other.bandwidthMbps &&
        activePlayers == other.activePlayers &&
        preloadingPlayers == other.preloadingPlayers &&
        thermalState == other.thermalState &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, decoderCount.hashCode);
    _$hash = $jc(_$hash, hardwareDecoderCount.hashCode);
    _$hash = $jc(_$hash, memoryBytes.hashCode);
    _$hash = $jc(_$hash, bandwidthMbps.hashCode);
    _$hash = $jc(_$hash, activePlayers.hashCode);
    _$hash = $jc(_$hash, preloadingPlayers.hashCode);
    _$hash = $jc(_$hash, thermalState.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResourceMetrics')
          ..add('decoderCount', decoderCount)
          ..add('hardwareDecoderCount', hardwareDecoderCount)
          ..add('memoryBytes', memoryBytes)
          ..add('bandwidthMbps', bandwidthMbps)
          ..add('activePlayers', activePlayers)
          ..add('preloadingPlayers', preloadingPlayers)
          ..add('thermalState', thermalState)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class ResourceMetricsBuilder
    implements Builder<ResourceMetrics, ResourceMetricsBuilder> {
  _$ResourceMetrics? _$v;

  int? _decoderCount;
  int? get decoderCount => _$this._decoderCount;
  set decoderCount(int? decoderCount) => _$this._decoderCount = decoderCount;

  int? _hardwareDecoderCount;
  int? get hardwareDecoderCount => _$this._hardwareDecoderCount;
  set hardwareDecoderCount(int? hardwareDecoderCount) =>
      _$this._hardwareDecoderCount = hardwareDecoderCount;

  int? _memoryBytes;
  int? get memoryBytes => _$this._memoryBytes;
  set memoryBytes(int? memoryBytes) => _$this._memoryBytes = memoryBytes;

  double? _bandwidthMbps;
  double? get bandwidthMbps => _$this._bandwidthMbps;
  set bandwidthMbps(double? bandwidthMbps) =>
      _$this._bandwidthMbps = bandwidthMbps;

  int? _activePlayers;
  int? get activePlayers => _$this._activePlayers;
  set activePlayers(int? activePlayers) =>
      _$this._activePlayers = activePlayers;

  int? _preloadingPlayers;
  int? get preloadingPlayers => _$this._preloadingPlayers;
  set preloadingPlayers(int? preloadingPlayers) =>
      _$this._preloadingPlayers = preloadingPlayers;

  String? _thermalState;
  String? get thermalState => _$this._thermalState;
  set thermalState(String? thermalState) => _$this._thermalState = thermalState;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  ResourceMetricsBuilder() {
    ResourceMetrics._initialize(this);
  }

  ResourceMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _decoderCount = $v.decoderCount;
      _hardwareDecoderCount = $v.hardwareDecoderCount;
      _memoryBytes = $v.memoryBytes;
      _bandwidthMbps = $v.bandwidthMbps;
      _activePlayers = $v.activePlayers;
      _preloadingPlayers = $v.preloadingPlayers;
      _thermalState = $v.thermalState;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResourceMetrics other) {
    _$v = other as _$ResourceMetrics;
  }

  @override
  void update(void Function(ResourceMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResourceMetrics build() => _build();

  _$ResourceMetrics _build() {
    final _$result =
        _$v ??
        _$ResourceMetrics._(
          decoderCount: BuiltValueNullFieldError.checkNotNull(
            decoderCount,
            r'ResourceMetrics',
            'decoderCount',
          ),
          hardwareDecoderCount: BuiltValueNullFieldError.checkNotNull(
            hardwareDecoderCount,
            r'ResourceMetrics',
            'hardwareDecoderCount',
          ),
          memoryBytes: BuiltValueNullFieldError.checkNotNull(
            memoryBytes,
            r'ResourceMetrics',
            'memoryBytes',
          ),
          bandwidthMbps: BuiltValueNullFieldError.checkNotNull(
            bandwidthMbps,
            r'ResourceMetrics',
            'bandwidthMbps',
          ),
          activePlayers: BuiltValueNullFieldError.checkNotNull(
            activePlayers,
            r'ResourceMetrics',
            'activePlayers',
          ),
          preloadingPlayers: BuiltValueNullFieldError.checkNotNull(
            preloadingPlayers,
            r'ResourceMetrics',
            'preloadingPlayers',
          ),
          thermalState: BuiltValueNullFieldError.checkNotNull(
            thermalState,
            r'ResourceMetrics',
            'thermalState',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
