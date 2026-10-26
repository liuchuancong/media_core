// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quality_switch_outcome.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$QualitySwitchOutcome extends QualitySwitchOutcome {
  @override
  final QualitySwitchResult result;
  @override
  final QualityCandidate? from;
  @override
  final QualityCandidate to;
  @override
  final Duration? resumedAt;
  @override
  final Object? error;
  @override
  final bool restored;

  factory _$QualitySwitchOutcome([
    void Function(QualitySwitchOutcomeBuilder)? updates,
  ]) => (QualitySwitchOutcomeBuilder()..update(updates))._build();

  _$QualitySwitchOutcome._({
    required this.result,
    this.from,
    required this.to,
    this.resumedAt,
    this.error,
    required this.restored,
  }) : super._();
  @override
  QualitySwitchOutcome rebuild(
    void Function(QualitySwitchOutcomeBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  QualitySwitchOutcomeBuilder toBuilder() =>
      QualitySwitchOutcomeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is QualitySwitchOutcome &&
        result == other.result &&
        from == other.from &&
        to == other.to &&
        resumedAt == other.resumedAt &&
        error == other.error &&
        restored == other.restored;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, from.hashCode);
    _$hash = $jc(_$hash, to.hashCode);
    _$hash = $jc(_$hash, resumedAt.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jc(_$hash, restored.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'QualitySwitchOutcome')
          ..add('result', result)
          ..add('from', from)
          ..add('to', to)
          ..add('resumedAt', resumedAt)
          ..add('error', error)
          ..add('restored', restored))
        .toString();
  }
}

class QualitySwitchOutcomeBuilder
    implements Builder<QualitySwitchOutcome, QualitySwitchOutcomeBuilder> {
  _$QualitySwitchOutcome? _$v;

  QualitySwitchResult? _result;
  QualitySwitchResult? get result => _$this._result;
  set result(QualitySwitchResult? result) => _$this._result = result;

  QualityCandidateBuilder? _from;
  QualityCandidateBuilder get from =>
      _$this._from ??= QualityCandidateBuilder();
  set from(QualityCandidateBuilder? from) => _$this._from = from;

  QualityCandidateBuilder? _to;
  QualityCandidateBuilder get to => _$this._to ??= QualityCandidateBuilder();
  set to(QualityCandidateBuilder? to) => _$this._to = to;

  Duration? _resumedAt;
  Duration? get resumedAt => _$this._resumedAt;
  set resumedAt(Duration? resumedAt) => _$this._resumedAt = resumedAt;

  Object? _error;
  Object? get error => _$this._error;
  set error(Object? error) => _$this._error = error;

  bool? _restored;
  bool? get restored => _$this._restored;
  set restored(bool? restored) => _$this._restored = restored;

  QualitySwitchOutcomeBuilder() {
    QualitySwitchOutcome._initialize(this);
  }

  QualitySwitchOutcomeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _from = $v.from?.toBuilder();
      _to = $v.to.toBuilder();
      _resumedAt = $v.resumedAt;
      _error = $v.error;
      _restored = $v.restored;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(QualitySwitchOutcome other) {
    _$v = other as _$QualitySwitchOutcome;
  }

  @override
  void update(void Function(QualitySwitchOutcomeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  QualitySwitchOutcome build() => _build();

  _$QualitySwitchOutcome _build() {
    _$QualitySwitchOutcome _$result;
    try {
      _$result =
          _$v ??
          _$QualitySwitchOutcome._(
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'QualitySwitchOutcome',
              'result',
            ),
            from: _from?.build(),
            to: to.build(),
            resumedAt: resumedAt,
            error: error,
            restored: BuiltValueNullFieldError.checkNotNull(
              restored,
              r'QualitySwitchOutcome',
              'restored',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'from';
        _from?.build();
        _$failedField = 'to';
        to.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'QualitySwitchOutcome',
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
