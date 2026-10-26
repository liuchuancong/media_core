// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preload_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PreloadMetrics extends PreloadMetrics {
  @override
  final int total;
  @override
  final int completed;
  @override
  final int failed;
  @override
  final int cancelled;

  factory _$PreloadMetrics([void Function(PreloadMetricsBuilder)? updates]) =>
      (PreloadMetricsBuilder()..update(updates))._build();

  _$PreloadMetrics._({
    required this.total,
    required this.completed,
    required this.failed,
    required this.cancelled,
  }) : super._();
  @override
  PreloadMetrics rebuild(void Function(PreloadMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PreloadMetricsBuilder toBuilder() => PreloadMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PreloadMetrics &&
        total == other.total &&
        completed == other.completed &&
        failed == other.failed &&
        cancelled == other.cancelled;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, total.hashCode);
    _$hash = $jc(_$hash, completed.hashCode);
    _$hash = $jc(_$hash, failed.hashCode);
    _$hash = $jc(_$hash, cancelled.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PreloadMetrics')
          ..add('total', total)
          ..add('completed', completed)
          ..add('failed', failed)
          ..add('cancelled', cancelled))
        .toString();
  }
}

class PreloadMetricsBuilder
    implements Builder<PreloadMetrics, PreloadMetricsBuilder> {
  _$PreloadMetrics? _$v;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _completed;
  int? get completed => _$this._completed;
  set completed(int? completed) => _$this._completed = completed;

  int? _failed;
  int? get failed => _$this._failed;
  set failed(int? failed) => _$this._failed = failed;

  int? _cancelled;
  int? get cancelled => _$this._cancelled;
  set cancelled(int? cancelled) => _$this._cancelled = cancelled;

  PreloadMetricsBuilder() {
    PreloadMetrics._initialize(this);
  }

  PreloadMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _total = $v.total;
      _completed = $v.completed;
      _failed = $v.failed;
      _cancelled = $v.cancelled;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PreloadMetrics other) {
    _$v = other as _$PreloadMetrics;
  }

  @override
  void update(void Function(PreloadMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PreloadMetrics build() => _build();

  _$PreloadMetrics _build() {
    final _$result =
        _$v ??
        _$PreloadMetrics._(
          total: BuiltValueNullFieldError.checkNotNull(
            total,
            r'PreloadMetrics',
            'total',
          ),
          completed: BuiltValueNullFieldError.checkNotNull(
            completed,
            r'PreloadMetrics',
            'completed',
          ),
          failed: BuiltValueNullFieldError.checkNotNull(
            failed,
            r'PreloadMetrics',
            'failed',
          ),
          cancelled: BuiltValueNullFieldError.checkNotNull(
            cancelled,
            r'PreloadMetrics',
            'cancelled',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
