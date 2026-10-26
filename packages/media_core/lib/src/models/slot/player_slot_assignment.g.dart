// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_slot_assignment.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSlotAssignment extends PlayerSlotAssignment {
  @override
  final SlotId slotId;
  @override
  final PlayerSlotOwner owner;
  @override
  final PlayerId playerId;
  @override
  final SessionId sessionId;
  @override
  final DateTime createdAt;

  factory _$PlayerSlotAssignment([
    void Function(PlayerSlotAssignmentBuilder)? updates,
  ]) => (PlayerSlotAssignmentBuilder()..update(updates))._build();

  _$PlayerSlotAssignment._({
    required this.slotId,
    required this.owner,
    required this.playerId,
    required this.sessionId,
    required this.createdAt,
  }) : super._();
  @override
  PlayerSlotAssignment rebuild(
    void Function(PlayerSlotAssignmentBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerSlotAssignmentBuilder toBuilder() =>
      PlayerSlotAssignmentBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSlotAssignment &&
        slotId == other.slotId &&
        owner == other.owner &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, slotId.hashCode);
    _$hash = $jc(_$hash, owner.hashCode);
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSlotAssignment')
          ..add('slotId', slotId)
          ..add('owner', owner)
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class PlayerSlotAssignmentBuilder
    implements Builder<PlayerSlotAssignment, PlayerSlotAssignmentBuilder> {
  _$PlayerSlotAssignment? _$v;

  SlotId? _slotId;
  SlotId? get slotId => _$this._slotId;
  set slotId(SlotId? slotId) => _$this._slotId = slotId;

  PlayerSlotOwnerBuilder? _owner;
  PlayerSlotOwnerBuilder get owner =>
      _$this._owner ??= PlayerSlotOwnerBuilder();
  set owner(PlayerSlotOwnerBuilder? owner) => _$this._owner = owner;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  PlayerSlotAssignmentBuilder();

  PlayerSlotAssignmentBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _slotId = $v.slotId;
      _owner = $v.owner.toBuilder();
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSlotAssignment other) {
    _$v = other as _$PlayerSlotAssignment;
  }

  @override
  void update(void Function(PlayerSlotAssignmentBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSlotAssignment build() => _build();

  _$PlayerSlotAssignment _build() {
    _$PlayerSlotAssignment _$result;
    try {
      _$result =
          _$v ??
          _$PlayerSlotAssignment._(
            slotId: BuiltValueNullFieldError.checkNotNull(
              slotId,
              r'PlayerSlotAssignment',
              'slotId',
            ),
            owner: owner.build(),
            playerId: BuiltValueNullFieldError.checkNotNull(
              playerId,
              r'PlayerSlotAssignment',
              'playerId',
            ),
            sessionId: BuiltValueNullFieldError.checkNotNull(
              sessionId,
              r'PlayerSlotAssignment',
              'sessionId',
            ),
            createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt,
              r'PlayerSlotAssignment',
              'createdAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'owner';
        owner.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlayerSlotAssignment',
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
