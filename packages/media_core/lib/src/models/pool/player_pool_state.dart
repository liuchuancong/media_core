import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';

part 'player_pool_state.g.dart';

/// Runtime state of player pool.
///
/// [PlayerPoolState] describes current pool condition.
///
/// It does not:
///
/// - allocate players
/// - release players
/// - control playback
///
/// Those belong to:
///
/// - PlayerPoolManager
/// - PlayerPoolAllocator
/// - PlayerPoolRecycler
abstract class PlayerPoolState implements Built<PlayerPoolState, PlayerPoolStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory PlayerPoolState([void Function(PlayerPoolStateBuilder)? updates]) = _$PlayerPoolState;

  /// Creates pool state.
  factory PlayerPoolState.of({
    int totalPlayers = 0,
    int idlePlayers = 0,
    int activePlayers = 0,
    int releasingPlayers = 0,
    bool isFull = false,
    List<PlayerId> activePlayerIds = const <PlayerId>[],
    List<SessionId> activeSessionIds = const <SessionId>[],
    bool initialized = false,
    bool disposing = false,
  }) {
    return PlayerPoolState(
      (builder) => builder
        ..totalPlayers = totalPlayers
        ..idlePlayers = idlePlayers
        ..activePlayers = activePlayers
        ..releasingPlayers = releasingPlayers
        ..isFull = isFull
        ..activePlayerIds = activePlayerIds
        ..activeSessionIds = activeSessionIds
        ..initialized = initialized
        ..disposing = disposing,
    );
  }

  PlayerPoolState._();

  /// An empty pool holds no players, is neither full nor disposing, and
  /// carries no ids; the two id lists stay empty rather than null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerPoolStateBuilder builder) => builder
    ..totalPlayers = 0
    ..idlePlayers = 0
    ..activePlayers = 0
    ..releasingPlayers = 0
    ..isFull = false
    ..activePlayerIds = const <PlayerId>[]
    ..activeSessionIds = const <SessionId>[]
    ..initialized = false
    ..disposing = false;

  /// Total slots managed by pool.
  int get totalPlayers;

  /// Currently idle players.
  int get idlePlayers;

  /// Currently active players.
  int get activePlayers;

  /// Players being released.
  int get releasingPlayers;

  /// Whether pool reached capacity.
  bool get isFull;

  /// Current active player ids.
  List<PlayerId> get activePlayerIds;

  /// Current active sessions.
  List<SessionId> get activeSessionIds;

  /// Whether pool is initialized.
  bool get initialized;

  /// Whether pool is disposing.
  bool get disposing;
}
