import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_pool_config.freezed.dart';

/// Configuration for player pool.
///
/// [PlayerPoolConfig] defines how the player pool
/// should allocate and recycle players.
///
/// It does not:
///
/// - create players
/// - manage player lifecycle
/// - store runtime state
///
/// Those belong to:
///
/// - PlayerPool
/// - PlayerPoolManager
/// - PlayerPoolAllocator
@freezed
abstract class PlayerPoolConfig with _$PlayerPoolConfig {
  /// Creates pool configuration.
  const factory PlayerPoolConfig({
    /// Maximum number of players in pool.
    ///
    /// 0 means unlimited.
    @Default(0) int maxPlayers,

    /// Initial number of pre-created players.
    @Default(0) int initialSize,

    /// Whether pool can create players lazily.
    @Default(true) bool lazyCreate,

    /// Whether unused players should be recycled.
    @Default(true) bool enableRecycle,

    /// Maximum idle duration before recycle.
    Duration? idleTimeout,

    /// Whether pool should keep at least one warm player.
    @Default(false) bool keepWarm,

    /// Number of warm players.
    @Default(0) int warmSize,

    /// Maximum concurrent active sessions.
    @Default(1) int maxActivePlayers,
  }) = _PlayerPoolConfig;
}
