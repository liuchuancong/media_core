// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_pressure_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResourcePressureSnapshot extends ResourcePressureSnapshot {
  @override
  final ResourcePressure pressure;
  @override
  final DateTime timestamp;

  factory _$ResourcePressureSnapshot([
    void Function(ResourcePressureSnapshotBuilder)? updates,
  ]) => (ResourcePressureSnapshotBuilder()..update(updates))._build();

  _$ResourcePressureSnapshot._({
    required this.pressure,
    required this.timestamp,
  }) : super._();
  @override
  ResourcePressureSnapshot rebuild(
    void Function(ResourcePressureSnapshotBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResourcePressureSnapshotBuilder toBuilder() =>
      ResourcePressureSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResourcePressureSnapshot &&
        pressure == other.pressure &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pressure.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResourcePressureSnapshot')
          ..add('pressure', pressure)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class ResourcePressureSnapshotBuilder
    implements
        Builder<ResourcePressureSnapshot, ResourcePressureSnapshotBuilder> {
  _$ResourcePressureSnapshot? _$v;

  ResourcePressure? _pressure;
  ResourcePressure? get pressure => _$this._pressure;
  set pressure(ResourcePressure? pressure) => _$this._pressure = pressure;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  ResourcePressureSnapshotBuilder();

  ResourcePressureSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _pressure = $v.pressure;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResourcePressureSnapshot other) {
    _$v = other as _$ResourcePressureSnapshot;
  }

  @override
  void update(void Function(ResourcePressureSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResourcePressureSnapshot build() => _build();

  _$ResourcePressureSnapshot _build() {
    final _$result =
        _$v ??
        _$ResourcePressureSnapshot._(
          pressure: BuiltValueNullFieldError.checkNotNull(
            pressure,
            r'ResourcePressureSnapshot',
            'pressure',
          ),
          timestamp: BuiltValueNullFieldError.checkNotNull(
            timestamp,
            r'ResourcePressureSnapshot',
            'timestamp',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
