// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_slot_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSlotState extends PlayerSlotState {
  @override
  final SlotId slotId;
  @override
  final PlayerSlotStatus status;
  @override
  final PlayerId? playerId;
  @override
  final SessionId? sessionId;

  factory _$PlayerSlotState([void Function(PlayerSlotStateBuilder)? updates]) =>
      (PlayerSlotStateBuilder()..update(updates))._build();

  _$PlayerSlotState._({
    required this.slotId,
    required this.status,
    this.playerId,
    this.sessionId,
  }) : super._();
  @override
  PlayerSlotState rebuild(void Function(PlayerSlotStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerSlotStateBuilder toBuilder() => PlayerSlotStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSlotState &&
        slotId == other.slotId &&
        status == other.status &&
        playerId == other.playerId &&
        sessionId == other.sessionId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, slotId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSlotState')
          ..add('slotId', slotId)
          ..add('status', status)
          ..add('playerId', playerId)
          ..add('sessionId', sessionId))
        .toString();
  }
}

class PlayerSlotStateBuilder
    implements Builder<PlayerSlotState, PlayerSlotStateBuilder> {
  _$PlayerSlotState? _$v;

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

  PlayerSlotStateBuilder() {
    PlayerSlotState._initialize(this);
  }

  PlayerSlotStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _slotId = $v.slotId;
      _status = $v.status;
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSlotState other) {
    _$v = other as _$PlayerSlotState;
  }

  @override
  void update(void Function(PlayerSlotStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSlotState build() => _build();

  _$PlayerSlotState _build() {
    final _$result =
        _$v ??
        _$PlayerSlotState._(
          slotId: BuiltValueNullFieldError.checkNotNull(
            slotId,
            r'PlayerSlotState',
            'slotId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'PlayerSlotState',
            'status',
          ),
          playerId: playerId,
          sessionId: sessionId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
