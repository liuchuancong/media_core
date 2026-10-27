// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResourceState extends ResourceState {
  @override
  final ResourceMetrics metrics;
  @override
  final ResourcePressure pressure;
  @override
  final bool enabled;
  @override
  final bool releasing;
  @override
  final bool degraded;
  @override
  final DateTime? timestamp;

  factory _$ResourceState([void Function(ResourceStateBuilder)? updates]) =>
      (ResourceStateBuilder()..update(updates))._build();

  _$ResourceState._({
    required this.metrics,
    required this.pressure,
    required this.enabled,
    required this.releasing,
    required this.degraded,
    this.timestamp,
  }) : super._();
  @override
  ResourceState rebuild(void Function(ResourceStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResourceStateBuilder toBuilder() => ResourceStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResourceState &&
        metrics == other.metrics &&
        pressure == other.pressure &&
        enabled == other.enabled &&
        releasing == other.releasing &&
        degraded == other.degraded &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, metrics.hashCode);
    _$hash = $jc(_$hash, pressure.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, releasing.hashCode);
    _$hash = $jc(_$hash, degraded.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResourceState')
          ..add('metrics', metrics)
          ..add('pressure', pressure)
          ..add('enabled', enabled)
          ..add('releasing', releasing)
          ..add('degraded', degraded)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class ResourceStateBuilder
    implements Builder<ResourceState, ResourceStateBuilder> {
  _$ResourceState? _$v;

  ResourceMetricsBuilder? _metrics;
  ResourceMetricsBuilder get metrics =>
      _$this._metrics ??= ResourceMetricsBuilder();
  set metrics(ResourceMetricsBuilder? metrics) => _$this._metrics = metrics;

  ResourcePressure? _pressure;
  ResourcePressure? get pressure => _$this._pressure;
  set pressure(ResourcePressure? pressure) => _$this._pressure = pressure;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _releasing;
  bool? get releasing => _$this._releasing;
  set releasing(bool? releasing) => _$this._releasing = releasing;

  bool? _degraded;
  bool? get degraded => _$this._degraded;
  set degraded(bool? degraded) => _$this._degraded = degraded;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  ResourceStateBuilder() {
    ResourceState._initialize(this);
  }

  ResourceStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _metrics = $v.metrics.toBuilder();
      _pressure = $v.pressure;
      _enabled = $v.enabled;
      _releasing = $v.releasing;
      _degraded = $v.degraded;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResourceState other) {
    _$v = other as _$ResourceState;
  }

  @override
  void update(void Function(ResourceStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResourceState build() => _build();

  _$ResourceState _build() {
    _$ResourceState _$result;
    try {
      _$result =
          _$v ??
          _$ResourceState._(
            metrics: metrics.build(),
            pressure: BuiltValueNullFieldError.checkNotNull(
              pressure,
              r'ResourceState',
              'pressure',
            ),
            enabled: BuiltValueNullFieldError.checkNotNull(
              enabled,
              r'ResourceState',
              'enabled',
            ),
            releasing: BuiltValueNullFieldError.checkNotNull(
              releasing,
              r'ResourceState',
              'releasing',
            ),
            degraded: BuiltValueNullFieldError.checkNotNull(
              degraded,
              r'ResourceState',
              'degraded',
            ),
            timestamp: timestamp,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'metrics';
        metrics.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ResourceState',
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
