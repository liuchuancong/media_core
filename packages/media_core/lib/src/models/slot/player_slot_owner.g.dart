// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_slot_owner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSlotOwner extends PlayerSlotOwner {
  @override
  final PlayerSlotOwnerType type;
  @override
  final String? id;

  factory _$PlayerSlotOwner([void Function(PlayerSlotOwnerBuilder)? updates]) =>
      (PlayerSlotOwnerBuilder()..update(updates))._build();

  _$PlayerSlotOwner._({required this.type, this.id}) : super._();
  @override
  PlayerSlotOwner rebuild(void Function(PlayerSlotOwnerBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerSlotOwnerBuilder toBuilder() => PlayerSlotOwnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSlotOwner && type == other.type && id == other.id;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSlotOwner')
          ..add('type', type)
          ..add('id', id))
        .toString();
  }
}

class PlayerSlotOwnerBuilder
    implements Builder<PlayerSlotOwner, PlayerSlotOwnerBuilder> {
  _$PlayerSlotOwner? _$v;

  PlayerSlotOwnerType? _type;
  PlayerSlotOwnerType? get type => _$this._type;
  set type(PlayerSlotOwnerType? type) => _$this._type = type;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  PlayerSlotOwnerBuilder();

  PlayerSlotOwnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _id = $v.id;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSlotOwner other) {
    _$v = other as _$PlayerSlotOwner;
  }

  @override
  void update(void Function(PlayerSlotOwnerBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSlotOwner build() => _build();

  _$PlayerSlotOwner _build() {
    final _$result =
        _$v ??
        _$PlayerSlotOwner._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'PlayerSlotOwner',
            'type',
          ),
          id: id,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
