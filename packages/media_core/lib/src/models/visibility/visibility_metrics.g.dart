// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visibility_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$VisibilityMetrics extends VisibilityMetrics {
  @override
  final Duration visibleDuration;
  @override
  final Duration hiddenDuration;
  @override
  final int changeCount;

  factory _$VisibilityMetrics([
    void Function(VisibilityMetricsBuilder)? updates,
  ]) => (VisibilityMetricsBuilder()..update(updates))._build();

  _$VisibilityMetrics._({
    required this.visibleDuration,
    required this.hiddenDuration,
    required this.changeCount,
  }) : super._();
  @override
  VisibilityMetrics rebuild(void Function(VisibilityMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  VisibilityMetricsBuilder toBuilder() =>
      VisibilityMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is VisibilityMetrics &&
        visibleDuration == other.visibleDuration &&
        hiddenDuration == other.hiddenDuration &&
        changeCount == other.changeCount;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, visibleDuration.hashCode);
    _$hash = $jc(_$hash, hiddenDuration.hashCode);
    _$hash = $jc(_$hash, changeCount.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'VisibilityMetrics')
          ..add('visibleDuration', visibleDuration)
          ..add('hiddenDuration', hiddenDuration)
          ..add('changeCount', changeCount))
        .toString();
  }
}

class VisibilityMetricsBuilder
    implements Builder<VisibilityMetrics, VisibilityMetricsBuilder> {
  _$VisibilityMetrics? _$v;

  Duration? _visibleDuration;
  Duration? get visibleDuration => _$this._visibleDuration;
  set visibleDuration(Duration? visibleDuration) =>
      _$this._visibleDuration = visibleDuration;

  Duration? _hiddenDuration;
  Duration? get hiddenDuration => _$this._hiddenDuration;
  set hiddenDuration(Duration? hiddenDuration) =>
      _$this._hiddenDuration = hiddenDuration;

  int? _changeCount;
  int? get changeCount => _$this._changeCount;
  set changeCount(int? changeCount) => _$this._changeCount = changeCount;

  VisibilityMetricsBuilder() {
    VisibilityMetrics._initialize(this);
  }

  VisibilityMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _visibleDuration = $v.visibleDuration;
      _hiddenDuration = $v.hiddenDuration;
      _changeCount = $v.changeCount;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(VisibilityMetrics other) {
    _$v = other as _$VisibilityMetrics;
  }

  @override
  void update(void Function(VisibilityMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  VisibilityMetrics build() => _build();

  _$VisibilityMetrics _build() {
    final _$result =
        _$v ??
        _$VisibilityMetrics._(
          visibleDuration: BuiltValueNullFieldError.checkNotNull(
            visibleDuration,
            r'VisibilityMetrics',
            'visibleDuration',
          ),
          hiddenDuration: BuiltValueNullFieldError.checkNotNull(
            hiddenDuration,
            r'VisibilityMetrics',
            'hiddenDuration',
          ),
          changeCount: BuiltValueNullFieldError.checkNotNull(
            changeCount,
            r'VisibilityMetrics',
            'changeCount',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
