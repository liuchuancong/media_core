// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_pool_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerPoolMetrics extends PlayerPoolMetrics {
  @override
  final int createdCount;
  @override
  final int destroyedCount;
  @override
  final int allocationCount;
  @override
  final int allocationFailureCount;
  @override
  final int recycleCount;
  @override
  final int recycleFailureCount;
  @override
  final int allocatedCount;
  @override
  final int idleCount;
  @override
  final int peakCount;
  @override
  final Duration? averageAllocationTime;
  @override
  final DateTime? updatedAt;

  factory _$PlayerPoolMetrics([
    void Function(PlayerPoolMetricsBuilder)? updates,
  ]) => (PlayerPoolMetricsBuilder()..update(updates))._build();

  _$PlayerPoolMetrics._({
    required this.createdCount,
    required this.destroyedCount,
    required this.allocationCount,
    required this.allocationFailureCount,
    required this.recycleCount,
    required this.recycleFailureCount,
    required this.allocatedCount,
    required this.idleCount,
    required this.peakCount,
    this.averageAllocationTime,
    this.updatedAt,
  }) : super._();
  @override
  PlayerPoolMetrics rebuild(void Function(PlayerPoolMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerPoolMetricsBuilder toBuilder() =>
      PlayerPoolMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerPoolMetrics &&
        createdCount == other.createdCount &&
        destroyedCount == other.destroyedCount &&
        allocationCount == other.allocationCount &&
        allocationFailureCount == other.allocationFailureCount &&
        recycleCount == other.recycleCount &&
        recycleFailureCount == other.recycleFailureCount &&
        allocatedCount == other.allocatedCount &&
        idleCount == other.idleCount &&
        peakCount == other.peakCount &&
        averageAllocationTime == other.averageAllocationTime &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, createdCount.hashCode);
    _$hash = $jc(_$hash, destroyedCount.hashCode);
    _$hash = $jc(_$hash, allocationCount.hashCode);
    _$hash = $jc(_$hash, allocationFailureCount.hashCode);
    _$hash = $jc(_$hash, recycleCount.hashCode);
    _$hash = $jc(_$hash, recycleFailureCount.hashCode);
    _$hash = $jc(_$hash, allocatedCount.hashCode);
    _$hash = $jc(_$hash, idleCount.hashCode);
    _$hash = $jc(_$hash, peakCount.hashCode);
    _$hash = $jc(_$hash, averageAllocationTime.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerPoolMetrics')
          ..add('createdCount', createdCount)
          ..add('destroyedCount', destroyedCount)
          ..add('allocationCount', allocationCount)
          ..add('allocationFailureCount', allocationFailureCount)
          ..add('recycleCount', recycleCount)
          ..add('recycleFailureCount', recycleFailureCount)
          ..add('allocatedCount', allocatedCount)
          ..add('idleCount', idleCount)
          ..add('peakCount', peakCount)
          ..add('averageAllocationTime', averageAllocationTime)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class PlayerPoolMetricsBuilder
    implements Builder<PlayerPoolMetrics, PlayerPoolMetricsBuilder> {
  _$PlayerPoolMetrics? _$v;

  int? _createdCount;
  int? get createdCount => _$this._createdCount;
  set createdCount(int? createdCount) => _$this._createdCount = createdCount;

  int? _destroyedCount;
  int? get destroyedCount => _$this._destroyedCount;
  set destroyedCount(int? destroyedCount) =>
      _$this._destroyedCount = destroyedCount;

  int? _allocationCount;
  int? get allocationCount => _$this._allocationCount;
  set allocationCount(int? allocationCount) =>
      _$this._allocationCount = allocationCount;

  int? _allocationFailureCount;
  int? get allocationFailureCount => _$this._allocationFailureCount;
  set allocationFailureCount(int? allocationFailureCount) =>
      _$this._allocationFailureCount = allocationFailureCount;

  int? _recycleCount;
  int? get recycleCount => _$this._recycleCount;
  set recycleCount(int? recycleCount) => _$this._recycleCount = recycleCount;

  int? _recycleFailureCount;
  int? get recycleFailureCount => _$this._recycleFailureCount;
  set recycleFailureCount(int? recycleFailureCount) =>
      _$this._recycleFailureCount = recycleFailureCount;

  int? _allocatedCount;
  int? get allocatedCount => _$this._allocatedCount;
  set allocatedCount(int? allocatedCount) =>
      _$this._allocatedCount = allocatedCount;

  int? _idleCount;
  int? get idleCount => _$this._idleCount;
  set idleCount(int? idleCount) => _$this._idleCount = idleCount;

  int? _peakCount;
  int? get peakCount => _$this._peakCount;
  set peakCount(int? peakCount) => _$this._peakCount = peakCount;

  Duration? _averageAllocationTime;
  Duration? get averageAllocationTime => _$this._averageAllocationTime;
  set averageAllocationTime(Duration? averageAllocationTime) =>
      _$this._averageAllocationTime = averageAllocationTime;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  PlayerPoolMetricsBuilder() {
    PlayerPoolMetrics._initialize(this);
  }

  PlayerPoolMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _createdCount = $v.createdCount;
      _destroyedCount = $v.destroyedCount;
      _allocationCount = $v.allocationCount;
      _allocationFailureCount = $v.allocationFailureCount;
      _recycleCount = $v.recycleCount;
      _recycleFailureCount = $v.recycleFailureCount;
      _allocatedCount = $v.allocatedCount;
      _idleCount = $v.idleCount;
      _peakCount = $v.peakCount;
      _averageAllocationTime = $v.averageAllocationTime;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerPoolMetrics other) {
    _$v = other as _$PlayerPoolMetrics;
  }

  @override
  void update(void Function(PlayerPoolMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerPoolMetrics build() => _build();

  _$PlayerPoolMetrics _build() {
    final _$result =
        _$v ??
        _$PlayerPoolMetrics._(
          createdCount: BuiltValueNullFieldError.checkNotNull(
            createdCount,
            r'PlayerPoolMetrics',
            'createdCount',
          ),
          destroyedCount: BuiltValueNullFieldError.checkNotNull(
            destroyedCount,
            r'PlayerPoolMetrics',
            'destroyedCount',
          ),
          allocationCount: BuiltValueNullFieldError.checkNotNull(
            allocationCount,
            r'PlayerPoolMetrics',
            'allocationCount',
          ),
          allocationFailureCount: BuiltValueNullFieldError.checkNotNull(
            allocationFailureCount,
            r'PlayerPoolMetrics',
            'allocationFailureCount',
          ),
          recycleCount: BuiltValueNullFieldError.checkNotNull(
            recycleCount,
            r'PlayerPoolMetrics',
            'recycleCount',
          ),
          recycleFailureCount: BuiltValueNullFieldError.checkNotNull(
            recycleFailureCount,
            r'PlayerPoolMetrics',
            'recycleFailureCount',
          ),
          allocatedCount: BuiltValueNullFieldError.checkNotNull(
            allocatedCount,
            r'PlayerPoolMetrics',
            'allocatedCount',
          ),
          idleCount: BuiltValueNullFieldError.checkNotNull(
            idleCount,
            r'PlayerPoolMetrics',
            'idleCount',
          ),
          peakCount: BuiltValueNullFieldError.checkNotNull(
            peakCount,
            r'PlayerPoolMetrics',
            'peakCount',
          ),
          averageAllocationTime: averageAllocationTime,
          updatedAt: updatedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
