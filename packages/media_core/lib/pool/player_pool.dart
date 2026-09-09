import 'dart:async';
import 'player_pool_state.dart';
import 'player_pool_config.dart';
import 'player_pool_manager.dart';
import 'player_pool_snapshot.dart';
import '../identity/player_id.dart';
import '../identity/session_id.dart';

/// Public player pool API.
///
/// [PlayerPool] is the public entry point
/// for player pool operations.
///
/// It hides internal pool coordination.
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
/// - PlayerSession
/// - PlaybackController
final class PlayerPool {
  /// Creates player pool.
  PlayerPool({PlayerPoolConfig config = const PlayerPoolConfig()}) : _manager = PlayerPoolManager(config: config);

  final PlayerPoolManager _manager;

  /// Current pool state stream.
  Stream<PlayerPoolState> get states {
    return _manager.states;
  }

  /// Current pool state.
  PlayerPoolState get state {
    return _manager.state;
  }

  /// Current snapshot.
  PlayerPoolSnapshot get snapshot {
    return _manager.snapshot;
  }

  /// Number of players.
  int get count {
    return state.totalPlayers;
  }

  /// Adds player into pool.
  void add(PlayerId playerId) {
    _manager.add(playerId);
  }

  /// Removes player.
  bool remove(PlayerId playerId) {
    return _manager.remove(playerId);
  }

  /// Allocates player for session.
  PlayerId? allocate({required SessionId sessionId}) {
    return _manager.allocate(sessionId: sessionId);
  }

  /// Releases player.
  bool release(PlayerId playerId) {
    return _manager.release(playerId);
  }

  /// Gets recycle candidates.
  List<PlayerId> recycleCandidates({int maxCount = 1}) {
    return _manager.recycleCandidates(maxCount: maxCount);
  }

  /// Disposes pool.
  Future<void> dispose() async {
    await _manager.dispose();
  }
}
