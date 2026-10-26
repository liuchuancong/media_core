import 'package:built_value/built_value.dart';

part 'preload_metrics.g.dart';

/// Preload statistics.
abstract class PreloadMetrics implements Built<PreloadMetrics, PreloadMetricsBuilder> {
  /// Builds metrics from a [updates] callback — the codegen entry.
  factory PreloadMetrics([void Function(PreloadMetricsBuilder)? updates]) = _$PreloadMetrics;

  /// Creates a metrics record with the given counters.
  factory PreloadMetrics.of({int total = 0, int completed = 0, int failed = 0, int cancelled = 0}) {
    return PreloadMetrics(
      (builder) => builder
        ..total = total
        ..completed = completed
        ..failed = failed
        ..cancelled = cancelled,
    );
  }

  PreloadMetrics._();

  /// Nothing has run until a counter says it did.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PreloadMetricsBuilder builder) => builder
    ..total = 0
    ..completed = 0
    ..failed = 0
    ..cancelled = 0;

  /// Total number of preload operations started.
  int get total;

  /// Number of preload operations that finished successfully.
  int get completed;

  /// Number of preload operations that failed.
  int get failed;

  /// Number of preload operations cancelled before completion.
  int get cancelled;

  /// Fraction of [total] operations that completed successfully, or `0`
  /// when nothing has run yet.
  double get successRate {
    if (total == 0) {
      return 0;
    }

    return completed / total;
  }
}
