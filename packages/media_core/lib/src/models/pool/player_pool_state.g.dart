// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_pool_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerPoolState extends PlayerPoolState {
  @override
  final int totalPlayers;
  @override
  final int idlePlayers;
  @override
  final int activePlayers;
  @override
  final int releasingPlayers;
  @override
  final bool isFull;
  @override
  final List<PlayerId> activePlayerIds;
  @override
  final List<SessionId> activeSessionIds;
  @override
  final bool initialized;
  @override
  final bool disposing;

  factory _$PlayerPoolState([void Function(PlayerPoolStateBuilder)? updates]) =>
      (PlayerPoolStateBuilder()..update(updates))._build();

  _$PlayerPoolState._({
    required this.totalPlayers,
    required this.idlePlayers,
    required this.activePlayers,
    required this.releasingPlayers,
    required this.isFull,
    required this.activePlayerIds,
    required this.activeSessionIds,
    required this.initialized,
    required this.disposing,
  }) : super._();
  @override
  PlayerPoolState rebuild(void Function(PlayerPoolStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerPoolStateBuilder toBuilder() => PlayerPoolStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerPoolState &&
        totalPlayers == other.totalPlayers &&
        idlePlayers == other.idlePlayers &&
        activePlayers == other.activePlayers &&
        releasingPlayers == other.releasingPlayers &&
        isFull == other.isFull &&
        activePlayerIds == other.activePlayerIds &&
        activeSessionIds == other.activeSessionIds &&
        initialized == other.initialized &&
        disposing == other.disposing;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, totalPlayers.hashCode);
    _$hash = $jc(_$hash, idlePlayers.hashCode);
    _$hash = $jc(_$hash, activePlayers.hashCode);
    _$hash = $jc(_$hash, releasingPlayers.hashCode);
    _$hash = $jc(_$hash, isFull.hashCode);
    _$hash = $jc(_$hash, activePlayerIds.hashCode);
    _$hash = $jc(_$hash, activeSessionIds.hashCode);
    _$hash = $jc(_$hash, initialized.hashCode);
    _$hash = $jc(_$hash, disposing.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerPoolState')
          ..add('totalPlayers', totalPlayers)
          ..add('idlePlayers', idlePlayers)
          ..add('activePlayers', activePlayers)
          ..add('releasingPlayers', releasingPlayers)
          ..add('isFull', isFull)
          ..add('activePlayerIds', activePlayerIds)
          ..add('activeSessionIds', activeSessionIds)
          ..add('initialized', initialized)
          ..add('disposing', disposing))
        .toString();
  }
}

class PlayerPoolStateBuilder
    implements Builder<PlayerPoolState, PlayerPoolStateBuilder> {
  _$PlayerPoolState? _$v;

  int? _totalPlayers;
  int? get totalPlayers => _$this._totalPlayers;
  set totalPlayers(int? totalPlayers) => _$this._totalPlayers = totalPlayers;

  int? _idlePlayers;
  int? get idlePlayers => _$this._idlePlayers;
  set idlePlayers(int? idlePlayers) => _$this._idlePlayers = idlePlayers;

  int? _activePlayers;
  int? get activePlayers => _$this._activePlayers;
  set activePlayers(int? activePlayers) =>
      _$this._activePlayers = activePlayers;

  int? _releasingPlayers;
  int? get releasingPlayers => _$this._releasingPlayers;
  set releasingPlayers(int? releasingPlayers) =>
      _$this._releasingPlayers = releasingPlayers;

  bool? _isFull;
  bool? get isFull => _$this._isFull;
  set isFull(bool? isFull) => _$this._isFull = isFull;

  List<PlayerId>? _activePlayerIds;
  List<PlayerId>? get activePlayerIds => _$this._activePlayerIds;
  set activePlayerIds(List<PlayerId>? activePlayerIds) =>
      _$this._activePlayerIds = activePlayerIds;

  List<SessionId>? _activeSessionIds;
  List<SessionId>? get activeSessionIds => _$this._activeSessionIds;
  set activeSessionIds(List<SessionId>? activeSessionIds) =>
      _$this._activeSessionIds = activeSessionIds;

  bool? _initialized;
  bool? get initialized => _$this._initialized;
  set initialized(bool? initialized) => _$this._initialized = initialized;

  bool? _disposing;
  bool? get disposing => _$this._disposing;
  set disposing(bool? disposing) => _$this._disposing = disposing;

  PlayerPoolStateBuilder() {
    PlayerPoolState._initialize(this);
  }

  PlayerPoolStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _totalPlayers = $v.totalPlayers;
      _idlePlayers = $v.idlePlayers;
      _activePlayers = $v.activePlayers;
      _releasingPlayers = $v.releasingPlayers;
      _isFull = $v.isFull;
      _activePlayerIds = $v.activePlayerIds;
      _activeSessionIds = $v.activeSessionIds;
      _initialized = $v.initialized;
      _disposing = $v.disposing;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerPoolState other) {
    _$v = other as _$PlayerPoolState;
  }

  @override
  void update(void Function(PlayerPoolStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerPoolState build() => _build();

  _$PlayerPoolState _build() {
    final _$result =
        _$v ??
        _$PlayerPoolState._(
          totalPlayers: BuiltValueNullFieldError.checkNotNull(
            totalPlayers,
            r'PlayerPoolState',
            'totalPlayers',
          ),
          idlePlayers: BuiltValueNullFieldError.checkNotNull(
            idlePlayers,
            r'PlayerPoolState',
            'idlePlayers',
          ),
          activePlayers: BuiltValueNullFieldError.checkNotNull(
            activePlayers,
            r'PlayerPoolState',
            'activePlayers',
          ),
          releasingPlayers: BuiltValueNullFieldError.checkNotNull(
            releasingPlayers,
            r'PlayerPoolState',
            'releasingPlayers',
          ),
          isFull: BuiltValueNullFieldError.checkNotNull(
            isFull,
            r'PlayerPoolState',
            'isFull',
          ),
          activePlayerIds: BuiltValueNullFieldError.checkNotNull(
            activePlayerIds,
            r'PlayerPoolState',
            'activePlayerIds',
          ),
          activeSessionIds: BuiltValueNullFieldError.checkNotNull(
            activeSessionIds,
            r'PlayerPoolState',
            'activeSessionIds',
          ),
          initialized: BuiltValueNullFieldError.checkNotNull(
            initialized,
            r'PlayerPoolState',
            'initialized',
          ),
          disposing: BuiltValueNullFieldError.checkNotNull(
            disposing,
            r'PlayerPoolState',
            'disposing',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
