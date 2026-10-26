import 'package:built_value/built_value.dart';

part 'bandwidth_budget.g.dart';

/// Defines network bandwidth limitations.
///
/// [BandwidthBudget] describes the maximum network
/// bandwidth that the media core should consume.
///
/// It is a configuration object used by:
///
/// - BandwidthManager
/// - ResourceManager
///
/// It does not:
///
/// - measure network speed
/// - monitor active connections
/// - throttle network traffic
/// - change player quality directly
///
/// Those responsibilities belong to:
///
/// - BandwidthManager
/// - NetworkMonitor
/// - QualityController
///
/// Bandwidth flow:
///
/// ```text
/// BandwidthBudget
///        |
///        | defines limits
///        v
///
/// BandwidthManager
///        |
///        | runtime monitoring
///        v
///
/// ResourceManager
///        |
///        +--> reduce quality
///        +--> stop preload
///        +--> switch stream
/// ```
abstract class BandwidthBudget implements Built<BandwidthBudget, BandwidthBudgetBuilder> {
  /// Builds a budget from a [updates] callback — the codegen entry.
  factory BandwidthBudget([void Function(BandwidthBudgetBuilder)? updates]) = _$BandwidthBudget;

  /// Creates bandwidth budget.
  factory BandwidthBudget.of({
    double maxMbps = 20.0,
    double warningMbps = 15.0,
    double criticalMbps = 18.0,
    bool enabled = true,
  }) {
    return BandwidthBudget(
      (builder) => builder
        ..maxMbps = maxMbps
        ..warningMbps = warningMbps
        ..criticalMbps = criticalMbps
        ..enabled = enabled,
    );
  }

  BandwidthBudget._();

  /// A budget is active unless it is turned off, and its thresholds are
  /// the ones a 1080p-plus stream is expected to fit under.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(BandwidthBudgetBuilder builder) => builder
    ..maxMbps = 20.0
    ..warningMbps = 15.0
    ..criticalMbps = 18.0
    ..enabled = true;

  /// Maximum allowed bandwidth, in Mbps.
  double get maxMbps;

  /// Warning bandwidth threshold, in Mbps.
  ///
  /// When bandwidth exceeds this value, quality reduction may be
  /// considered.
  double get warningMbps;

  /// Critical bandwidth threshold, in Mbps.
  ///
  /// When bandwidth exceeds this value, aggressive reduction may be
  /// required.
  double get criticalMbps;

  /// Whether bandwidth limitation is enabled.
  bool get enabled;

  /// Whether bandwidth usage is above warning level.
  bool isWarning(double currentMbps) {
    if (!enabled) {
      return false;
    }

    return currentMbps >= warningMbps;
  }

  /// Whether bandwidth usage is critical.
  bool isCritical(double currentMbps) {
    if (!enabled) {
      return false;
    }

    return currentMbps >= criticalMbps;
  }

  /// Whether bandwidth limit is exceeded.
  bool isExceeded(double currentMbps) {
    if (!enabled) {
      return false;
    }

    return currentMbps >= maxMbps;
  }

  /// Returns remaining bandwidth.
  double remainingMbps(double currentMbps) {
    final remaining = maxMbps - currentMbps;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }
}
