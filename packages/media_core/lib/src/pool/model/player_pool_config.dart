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

    /// How many **warm** players the pool may hold — the one playing is not one of
    /// them, so `warmSize: 2` is a ledger of at most three players.
    ///
    /// Zero means unbounded. It is one number with one meaning, read the same way by
    /// the cap that decides whether another neighbour gets warmed and by the decision
    /// that holds or releases an idle player outside the window — the second of those
    /// used to compare it against the whole ledger instead, which is a second meaning
    /// no doc comment can tell apart from the first. A preset that sizes itself for
    /// the ledger leaves the cap loose: `warmSize: 2` with a one-each-side window is
    /// the budget doing nothing at all.
    @Default(0) int warmSize,

    /// Maximum concurrent active sessions.
    @Default(1) int maxActivePlayers,

    /// How many neighbours on each side of the active item are kept warm.
    ///
    /// A list or feed pre-opens the items a swipe can reach, so the swipe is a
    /// source swap on an already-open player rather than a cold start. One is
    /// the smallest useful value (the next item only) and the default; zero
    /// turns preloading off.
    @Default(1) int preloadCount,

    /// Visibility ratio at which an item is allowed to play.
    ///
    /// Above this the item becomes the active one. Between this and
    /// [pauseVisibilityThreshold] nothing changes, which is what stops a
    /// partially visible item from flapping between play and pause mid-scroll.
    @Default(0.6) double playVisibilityThreshold,

    /// Visibility ratio below which the active item is paused.
    @Default(0.4) double pauseVisibilityThreshold,

    /// How long a warm item may stay open without becoming active.
    ///
    /// A warm player holds a decoder, so one that never becomes active is
    /// released rather than kept forever. Null means no timeout.
    Duration? preloadTimeout,

    /// Whether an idle player may be re-pointed at another item instead of
    /// being released and replaced.
    ///
    /// This is the difference between "one player per swipe" and "three players
    /// for an endless list": with reuse on, an idle player takes the next
    /// item's source, so decoder setup happens once per pool slot rather than
    /// once per item. Turn it off when every item needs to keep its own player
    /// (its own playback state, its own session).
    @Default(true) bool reuseIdlePlayers,
  }) = _PlayerPoolConfig;
}
