import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/models/pool/player_pool_metrics.dart';
import 'package:media_core/src/models/pool/player_pool_state.dart';

part 'player_pool_snapshot.g.dart';

/// Immutable snapshot of player pool.
///
/// [PlayerPoolSnapshot] represents a captured
/// point-in-time view of the player pool.
///
/// It is used for:
///
/// - diagnostics
/// - debugging
/// - testing
/// - state inspection
///
/// It does not:
///
/// - manage pool lifecycle
/// - allocate players
/// - recycle players
///
/// Those belong to:
///
/// - PlayerPoolManager
/// - PlayerPoolAllocator
/// - PlayerPoolRecycler
abstract class PlayerPoolSnapshot implements Built<PlayerPoolSnapshot, PlayerPoolSnapshotBuilder> {
  /// Builds a snapshot from a [updates] callback — the codegen entry.
  factory PlayerPoolSnapshot([void Function(PlayerPoolSnapshotBuilder)? updates]) = _$PlayerPoolSnapshot;

  /// Creates pool snapshot.
  factory PlayerPoolSnapshot.of({
    required PlayerPoolState state,
    required PlayerPoolMetrics metrics,
    required DateTime createdAt,
  }) {
    return PlayerPoolSnapshot(
      (builder) => builder
        ..state = state.toBuilder()
        ..metrics = metrics.toBuilder()
        ..createdAt = createdAt,
    );
  }

  PlayerPoolSnapshot._();

  /// Creates empty snapshot.
  factory PlayerPoolSnapshot.empty() {
    return PlayerPoolSnapshot.of(
      state: PlayerPoolState.of(),
      metrics: PlayerPoolMetrics.empty(),
      createdAt: clock.now(),
    );
  }

  /// Current pool state.
  PlayerPoolState get state;

  /// Current pool metrics.
  PlayerPoolMetrics get metrics;

  /// Snapshot creation time.
  DateTime get createdAt;
}
