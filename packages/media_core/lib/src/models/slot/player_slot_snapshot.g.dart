// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_slot_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSlotSnapshot extends PlayerSlotSnapshot {
  @override
  final SlotId slotId;
  @override
  final PlayerSlotStatus status;
  @override
  final PlayerId? playerId;
  @override
  final SessionId? sessionId;
  @override
  final DateTime createdAt;

  factory _$PlayerSlotSnapshot([
    void Function(PlayerSlotSnapshotBuilder)? updates,
  ]) => (PlayerSlotSnapshotBuilder()..update(updates))._build();

  _$PlayerSlotSnapshot._({
    required this.slotId,
    required this.status,
    this.playerId,
    this.sessionId,
    required this.createdAt,
  }) : super._();
  @override
  PlayerSlotSnapshot rebuild(
    void Function(PlayerSlotSnapshotBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerSlotSnapshotBuilder toBuilder() =>
      PlayerSlotSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSlotSnapshot &&
        slotId == other.slotId &&
        status == other.status &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, slotId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSlotSnapshot')
          ..add('slotId', slotId)
          ..add('status', status)
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class PlayerSlotSnapshotBuilder
    implements Builder<PlayerSlotSnapshot, PlayerSlotSnapshotBuilder> {
  _$PlayerSlotSnapshot? _$v;

  SlotId? _slotId;
  SlotId? get slotId => _$this._slotId;
  set slotId(SlotId? slotId) => _$this._slotId = slotId;

  PlayerSlotStatus? _status;
  PlayerSlotStatus? get status => _$this._status;
  set status(PlayerSlotStatus? status) => _$this._status = status;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  PlayerSlotSnapshotBuilder();

  PlayerSlotSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _slotId = $v.slotId;
      _status = $v.status;
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSlotSnapshot other) {
    _$v = other as _$PlayerSlotSnapshot;
  }

  @override
  void update(void Function(PlayerSlotSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSlotSnapshot build() => _build();

  _$PlayerSlotSnapshot _build() {
    final _$result =
        _$v ??
        _$PlayerSlotSnapshot._(
          slotId: BuiltValueNullFieldError.checkNotNull(
            slotId,
            r'PlayerSlotSnapshot',
            'slotId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'PlayerSlotSnapshot',
            'status',
          ),
          playerId: playerId,
          sessionId: sessionId,
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'PlayerSlotSnapshot',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
