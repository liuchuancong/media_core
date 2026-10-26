// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bandwidth_budget.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BandwidthBudget extends BandwidthBudget {
  @override
  final double maxMbps;
  @override
  final double warningMbps;
  @override
  final double criticalMbps;
  @override
  final bool enabled;

  factory _$BandwidthBudget([void Function(BandwidthBudgetBuilder)? updates]) =>
      (BandwidthBudgetBuilder()..update(updates))._build();

  _$BandwidthBudget._({
    required this.maxMbps,
    required this.warningMbps,
    required this.criticalMbps,
    required this.enabled,
  }) : super._();
  @override
  BandwidthBudget rebuild(void Function(BandwidthBudgetBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BandwidthBudgetBuilder toBuilder() => BandwidthBudgetBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BandwidthBudget &&
        maxMbps == other.maxMbps &&
        warningMbps == other.warningMbps &&
        criticalMbps == other.criticalMbps &&
        enabled == other.enabled;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, maxMbps.hashCode);
    _$hash = $jc(_$hash, warningMbps.hashCode);
    _$hash = $jc(_$hash, criticalMbps.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BandwidthBudget')
          ..add('maxMbps', maxMbps)
          ..add('warningMbps', warningMbps)
          ..add('criticalMbps', criticalMbps)
          ..add('enabled', enabled))
        .toString();
  }
}

class BandwidthBudgetBuilder
    implements Builder<BandwidthBudget, BandwidthBudgetBuilder> {
  _$BandwidthBudget? _$v;

  double? _maxMbps;
  double? get maxMbps => _$this._maxMbps;
  set maxMbps(double? maxMbps) => _$this._maxMbps = maxMbps;

  double? _warningMbps;
  double? get warningMbps => _$this._warningMbps;
  set warningMbps(double? warningMbps) => _$this._warningMbps = warningMbps;

  double? _criticalMbps;
  double? get criticalMbps => _$this._criticalMbps;
  set criticalMbps(double? criticalMbps) => _$this._criticalMbps = criticalMbps;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  BandwidthBudgetBuilder() {
    BandwidthBudget._initialize(this);
  }

  BandwidthBudgetBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _maxMbps = $v.maxMbps;
      _warningMbps = $v.warningMbps;
      _criticalMbps = $v.criticalMbps;
      _enabled = $v.enabled;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BandwidthBudget other) {
    _$v = other as _$BandwidthBudget;
  }

  @override
  void update(void Function(BandwidthBudgetBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BandwidthBudget build() => _build();

  _$BandwidthBudget _build() {
    final _$result =
        _$v ??
        _$BandwidthBudget._(
          maxMbps: BuiltValueNullFieldError.checkNotNull(
            maxMbps,
            r'BandwidthBudget',
            'maxMbps',
          ),
          warningMbps: BuiltValueNullFieldError.checkNotNull(
            warningMbps,
            r'BandwidthBudget',
            'warningMbps',
          ),
          criticalMbps: BuiltValueNullFieldError.checkNotNull(
            criticalMbps,
            r'BandwidthBudget',
            'criticalMbps',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'BandwidthBudget',
            'enabled',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
