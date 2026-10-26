// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_pool_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerPoolSnapshot extends PlayerPoolSnapshot {
  @override
  final PlayerPoolState state;
  @override
  final PlayerPoolMetrics metrics;
  @override
  final DateTime createdAt;

  factory _$PlayerPoolSnapshot([
    void Function(PlayerPoolSnapshotBuilder)? updates,
  ]) => (PlayerPoolSnapshotBuilder()..update(updates))._build();

  _$PlayerPoolSnapshot._({
    required this.state,
    required this.metrics,
    required this.createdAt,
  }) : super._();
  @override
  PlayerPoolSnapshot rebuild(
    void Function(PlayerPoolSnapshotBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerPoolSnapshotBuilder toBuilder() =>
      PlayerPoolSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerPoolSnapshot &&
        state == other.state &&
        metrics == other.metrics &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, metrics.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerPoolSnapshot')
          ..add('state', state)
          ..add('metrics', metrics)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class PlayerPoolSnapshotBuilder
    implements Builder<PlayerPoolSnapshot, PlayerPoolSnapshotBuilder> {
  _$PlayerPoolSnapshot? _$v;

  PlayerPoolStateBuilder? _state;
  PlayerPoolStateBuilder get state =>
      _$this._state ??= PlayerPoolStateBuilder();
  set state(PlayerPoolStateBuilder? state) => _$this._state = state;

  PlayerPoolMetricsBuilder? _metrics;
  PlayerPoolMetricsBuilder get metrics =>
      _$this._metrics ??= PlayerPoolMetricsBuilder();
  set metrics(PlayerPoolMetricsBuilder? metrics) => _$this._metrics = metrics;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  PlayerPoolSnapshotBuilder();

  PlayerPoolSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _state = $v.state.toBuilder();
      _metrics = $v.metrics.toBuilder();
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerPoolSnapshot other) {
    _$v = other as _$PlayerPoolSnapshot;
  }

  @override
  void update(void Function(PlayerPoolSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerPoolSnapshot build() => _build();

  _$PlayerPoolSnapshot _build() {
    _$PlayerPoolSnapshot _$result;
    try {
      _$result =
          _$v ??
          _$PlayerPoolSnapshot._(
            state: state.build(),
            metrics: metrics.build(),
            createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt,
              r'PlayerPoolSnapshot',
              'createdAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'state';
        state.build();
        _$failedField = 'metrics';
        metrics.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlayerPoolSnapshot',
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
