import 'dart:async';
import 'player_pool_state.dart';
import 'player_pool_config.dart';
import 'package:clock/clock.dart';
import 'player_pool_metrics.dart';
import 'player_pool_recycler.dart';
import 'player_pool_snapshot.dart';
import 'package:rxdart/rxdart.dart';
import '../identity/player_id.dart';
import 'player_pool_allocator.dart';
import '../identity/session_id.dart';


/// Manages player pool runtime.
///
/// [PlayerPoolManager] coordinates allocation
/// and recycling of player instances.
///
/// It does not:
///
/// - create players
/// - destroy players
/// - control playback
///
/// Those belong to:
///
/// - PlayerFactory
/// - PlayerController
/// - SessionManager
final class PlayerPoolManager {
  /// Creates pool manager.
  PlayerPoolManager({
    PlayerPoolConfig config = const PlayerPoolConfig(),
    PlayerPoolAllocator? allocator,
    PlayerPoolRecycler? recycler,
  }) : _config = config,
       _allocator = allocator ?? PlayerPoolAllocator(),
       _recycler = recycler ?? PlayerPoolRecycler();

  final PlayerPoolConfig _config;

  final PlayerPoolAllocator _allocator;

  final PlayerPoolRecycler _recycler;

  final Set<PlayerId> _players = {};

  final Set<PlayerId> _active = {};

  final Map<PlayerId, SessionId> _sessions = {};

  PlayerPoolMetrics _metrics = PlayerPoolMetrics.empty();

  final BehaviorSubject<PlayerPoolState> _stateSubject = BehaviorSubject.seeded(const PlayerPoolState());

  /// Current state stream.
  Stream<PlayerPoolState> get states {
    return _stateSubject.stream;
  }

  /// Current state.
  PlayerPoolState get state {
    return _stateSubject.value;
  }

  /// Current snapshot.
  PlayerPoolSnapshot get snapshot {
    return PlayerPoolSnapshot(state: state, metrics: _metrics, createdAt: clock.now());
  }

  /// Adds player into pool.
  void add(PlayerId playerId) {
    _players.add(playerId);

    _publish();
  }

  /// Removes player.
  bool remove(PlayerId playerId) {
    final removed = _players.remove(playerId);

    _active.remove(playerId);
    _sessions.remove(playerId);

    if (removed) {
      _publish();
    }

    return removed;
  }

  /// Allocates player.
  PlayerId? allocate({required SessionId sessionId}) {
    final player = _allocator.allocate(availablePlayers: _availablePlayers, sessionId: sessionId);

    if (player == null) {
      return null;
    }

    _active.add(player);
    _sessions[player] = sessionId;

    _metrics = _metrics.copyWith(allocationCount: _metrics.allocationCount + 1, allocatedCount: _active.length);

    _publish();

    return player;
  }

  /// Releases player back to pool.
  bool release(PlayerId playerId) {
    if (!_active.contains(playerId)) {
      return false;
    }

    _active.remove(playerId);
    _sessions.remove(playerId);

    _metrics = _metrics.copyWith(recycleCount: _metrics.recycleCount + 1, allocatedCount: _active.length);

    _publish();

    return true;
  }

  /// Finds recyclable players.
  List<PlayerId> recycleCandidates({int maxCount = 1}) {
    return _recycler.findCandidates(idlePlayers: _availablePlayers, maxCount: maxCount);
  }

  List<PlayerId> get _availablePlayers {
    return _players.where((id) => !_active.contains(id)).toList(growable: false);
  }

  void _publish() {
    _stateSubject.add(
      PlayerPoolState(
        totalPlayers: _players.length,
        idlePlayers: _availablePlayers.length,
        activePlayers: _active.length,
        isFull: _isFull,
        activePlayerIds: List.unmodifiable(_active),
        activeSessionIds: List.unmodifiable(_sessions.values),
        initialized: true,
      ),
    );
  }

  bool get _isFull {
    if (_config.maxPlayers == 0) {
      return false;
    }

    return _players.length >= _config.maxPlayers;
  }

  /// Disposes manager.
  Future<void> dispose() async {
    await _stateSubject.close();

    _players.clear();
    _active.clear();
    _sessions.clear();
  }
}
