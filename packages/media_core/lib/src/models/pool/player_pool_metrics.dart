import 'package:built_value/built_value.dart';

part 'player_pool_metrics.g.dart';

/// Metrics of player pool.
///
/// [PlayerPoolMetrics] contains runtime statistics
/// collected from player pool.
///
/// It is used for:
///
/// - diagnostics
/// - performance monitoring
/// - debugging
///
/// It does not:
///
/// - manage players
/// - change pool state
/// - allocate resources
///
/// Those belong to:
///
/// - PlayerPoolManager
/// - PlayerPoolAllocator
/// - PlayerPoolRecycler
abstract class PlayerPoolMetrics implements Built<PlayerPoolMetrics, PlayerPoolMetricsBuilder> {
  /// Builds metrics from a [updates] callback — the codegen entry.
  factory PlayerPoolMetrics([void Function(PlayerPoolMetricsBuilder)? updates]) = _$PlayerPoolMetrics;

  /// Creates pool metrics.
  factory PlayerPoolMetrics.of({
    int createdCount = 0,
    int destroyedCount = 0,
    int allocationCount = 0,
    int allocationFailureCount = 0,
    int recycleCount = 0,
    int recycleFailureCount = 0,
    int allocatedCount = 0,
    int idleCount = 0,
    int peakCount = 0,
    Duration? averageAllocationTime,
    DateTime? updatedAt,
  }) {
    return PlayerPoolMetrics(
      (builder) => builder
        ..createdCount = createdCount
        ..destroyedCount = destroyedCount
        ..allocationCount = allocationCount
        ..allocationFailureCount = allocationFailureCount
        ..recycleCount = recycleCount
        ..recycleFailureCount = recycleFailureCount
        ..allocatedCount = allocatedCount
        ..idleCount = idleCount
        ..peakCount = peakCount
        ..averageAllocationTime = averageAllocationTime
        ..updatedAt = updatedAt,
    );
  }

  PlayerPoolMetrics._();

  /// Creates empty metrics.
  factory PlayerPoolMetrics.empty() => PlayerPoolMetrics.of();

  /// A pool that has done nothing counts zero of everything; latency
  /// and the update stamp stay unavailable rather than zero.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerPoolMetricsBuilder builder) => builder
    ..createdCount = 0
    ..destroyedCount = 0
    ..allocationCount = 0
    ..allocationFailureCount = 0
    ..recycleCount = 0
    ..recycleFailureCount = 0
    ..allocatedCount = 0
    ..idleCount = 0
    ..peakCount = 0;

  /// Total players created.
  int get createdCount;

  /// Total players destroyed.
  int get destroyedCount;

  /// Total player allocations.
  int get allocationCount;

  /// Total allocation failures.
  int get allocationFailureCount;

  /// Total recycle operations.
  int get recycleCount;

  /// Total recycle failures.
  int get recycleFailureCount;

  /// Current allocated players.
  int get allocatedCount;

  /// Current idle players.
  int get idleCount;

  /// Peak concurrent players.
  int get peakCount;

  /// Average allocation latency.
  Duration? get averageAllocationTime;

  /// Last update timestamp.
  DateTime? get updatedAt;
}
