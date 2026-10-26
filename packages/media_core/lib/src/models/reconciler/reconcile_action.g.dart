// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconcile_action.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReconcileAction extends ReconcileAction {
  @override
  final ReconcileActionType type;
  @override
  final PlayerStatus? from;
  @override
  final PlayerStatus? to;

  factory _$ReconcileAction([void Function(ReconcileActionBuilder)? updates]) =>
      (ReconcileActionBuilder()..update(updates))._build();

  _$ReconcileAction._({required this.type, this.from, this.to}) : super._();
  @override
  ReconcileAction rebuild(void Function(ReconcileActionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReconcileActionBuilder toBuilder() => ReconcileActionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReconcileAction &&
        type == other.type &&
        from == other.from &&
        to == other.to;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, from.hashCode);
    _$hash = $jc(_$hash, to.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReconcileAction')
          ..add('type', type)
          ..add('from', from)
          ..add('to', to))
        .toString();
  }
}

class ReconcileActionBuilder
    implements Builder<ReconcileAction, ReconcileActionBuilder> {
  _$ReconcileAction? _$v;

  ReconcileActionType? _type;
  ReconcileActionType? get type => _$this._type;
  set type(ReconcileActionType? type) => _$this._type = type;

  PlayerStatus? _from;
  PlayerStatus? get from => _$this._from;
  set from(PlayerStatus? from) => _$this._from = from;

  PlayerStatus? _to;
  PlayerStatus? get to => _$this._to;
  set to(PlayerStatus? to) => _$this._to = to;

  ReconcileActionBuilder();

  ReconcileActionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _from = $v.from;
      _to = $v.to;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReconcileAction other) {
    _$v = other as _$ReconcileAction;
  }

  @override
  void update(void Function(ReconcileActionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReconcileAction build() => _build();

  _$ReconcileAction _build() {
    final _$result =
        _$v ??
        _$ReconcileAction._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'ReconcileAction',
            'type',
          ),
          from: from,
          to: to,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
