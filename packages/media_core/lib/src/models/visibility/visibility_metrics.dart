import 'package:built_value/built_value.dart';

part 'visibility_metrics.g.dart';

/// Visibility statistics.
abstract class VisibilityMetrics implements Built<VisibilityMetrics, VisibilityMetricsBuilder> {
  /// Builds metrics from a [updates] callback — the codegen entry.
  factory VisibilityMetrics([void Function(VisibilityMetricsBuilder)? updates]) = _$VisibilityMetrics;

  /// Creates visibility statistics from explicit totals.
  factory VisibilityMetrics.of({
    Duration visibleDuration = Duration.zero,
    Duration hiddenDuration = Duration.zero,
    int changeCount = 0,
  }) {
    return VisibilityMetrics(
      (builder) => builder
        ..visibleDuration = visibleDuration
        ..hiddenDuration = hiddenDuration
        ..changeCount = changeCount,
    );
  }

  VisibilityMetrics._();

  /// A player that has never been measured has spent no time on or off
  /// screen and changed state zero times.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(VisibilityMetricsBuilder builder) => builder
    ..visibleDuration = Duration.zero
    ..hiddenDuration = Duration.zero
    ..changeCount = 0;

  /// Total visible time.
  Duration get visibleDuration;

  /// Total hidden time.
  Duration get hiddenDuration;

  /// Visibility changes.
  int get changeCount;
}
