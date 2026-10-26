// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconcile_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReconcileResult extends ReconcileResult {
  @override
  final ReconcileResultType type;
  @override
  final ReconcilePlan? plan;
  @override
  final Object? error;

  factory _$ReconcileResult([void Function(ReconcileResultBuilder)? updates]) =>
      (ReconcileResultBuilder()..update(updates))._build();

  _$ReconcileResult._({required this.type, this.plan, this.error}) : super._();
  @override
  ReconcileResult rebuild(void Function(ReconcileResultBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReconcileResultBuilder toBuilder() => ReconcileResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReconcileResult &&
        type == other.type &&
        plan == other.plan &&
        error == other.error;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, plan.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReconcileResult')
          ..add('type', type)
          ..add('plan', plan)
          ..add('error', error))
        .toString();
  }
}

class ReconcileResultBuilder
    implements Builder<ReconcileResult, ReconcileResultBuilder> {
  _$ReconcileResult? _$v;

  ReconcileResultType? _type;
  ReconcileResultType? get type => _$this._type;
  set type(ReconcileResultType? type) => _$this._type = type;

  ReconcilePlanBuilder? _plan;
  ReconcilePlanBuilder get plan => _$this._plan ??= ReconcilePlanBuilder();
  set plan(ReconcilePlanBuilder? plan) => _$this._plan = plan;

  Object? _error;
  Object? get error => _$this._error;
  set error(Object? error) => _$this._error = error;

  ReconcileResultBuilder();

  ReconcileResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _plan = $v.plan?.toBuilder();
      _error = $v.error;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReconcileResult other) {
    _$v = other as _$ReconcileResult;
  }

  @override
  void update(void Function(ReconcileResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReconcileResult build() => _build();

  _$ReconcileResult _build() {
    _$ReconcileResult _$result;
    try {
      _$result =
          _$v ??
          _$ReconcileResult._(
            type: BuiltValueNullFieldError.checkNotNull(
              type,
              r'ReconcileResult',
              'type',
            ),
            plan: _plan?.build(),
            error: error,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'plan';
        _plan?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ReconcileResult',
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
