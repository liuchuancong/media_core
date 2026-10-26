// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconcile_plan.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReconcilePlan extends ReconcilePlan {
  @override
  final List<ReconcileAction> actions;

  factory _$ReconcilePlan([void Function(ReconcilePlanBuilder)? updates]) =>
      (ReconcilePlanBuilder()..update(updates))._build();

  _$ReconcilePlan._({required this.actions}) : super._();
  @override
  ReconcilePlan rebuild(void Function(ReconcilePlanBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReconcilePlanBuilder toBuilder() => ReconcilePlanBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReconcilePlan && actions == other.actions;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, actions.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ReconcilePlan',
    )..add('actions', actions)).toString();
  }
}

class ReconcilePlanBuilder
    implements Builder<ReconcilePlan, ReconcilePlanBuilder> {
  _$ReconcilePlan? _$v;

  List<ReconcileAction>? _actions;
  List<ReconcileAction>? get actions => _$this._actions;
  set actions(List<ReconcileAction>? actions) => _$this._actions = actions;

  ReconcilePlanBuilder() {
    ReconcilePlan._initialize(this);
  }

  ReconcilePlanBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _actions = $v.actions;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReconcilePlan other) {
    _$v = other as _$ReconcilePlan;
  }

  @override
  void update(void Function(ReconcilePlanBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReconcilePlan build() => _build();

  _$ReconcilePlan _build() {
    final _$result =
        _$v ??
        _$ReconcilePlan._(
          actions: BuiltValueNullFieldError.checkNotNull(
            actions,
            r'ReconcilePlan',
            'actions',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
