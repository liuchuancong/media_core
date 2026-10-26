import 'package:built_value/built_value.dart';
import 'package:media_core_logging/media_core_logging.dart';

part 'diagnostics_config.g.dart';

/// Defines configuration for the diagnostics subsystem.
///
/// A [DiagnosticsConfig] controls which diagnostic capabilities are enabled
/// and how much diagnostic data is retained.
///
/// Responsibilities:
///
/// - enable or disable diagnostics
/// - configure log filtering
/// - configure performance sample retention
/// - configure periodic monitoring behavior
/// - provide immutable diagnostic configuration
///
/// It does not:
///
/// - collect diagnostic measurements
/// - emit log records
/// - schedule monitoring work
/// - own diagnostic monitor instances
///
/// Those responsibilities belong to:
///
/// - DiagnosticsManager
/// - PlayerLogger
/// - PerformanceMonitor
/// - MemoryMonitor
/// - NetworkMonitor
abstract class DiagnosticsConfig implements Built<DiagnosticsConfig, DiagnosticsConfigBuilder> {
  /// Builds DiagnosticsConfig from a [updates] callback — the codegen entry.
  factory DiagnosticsConfig([void Function(DiagnosticsConfigBuilder)? updates]) = _$DiagnosticsConfig;

  /// Creates diagnostic configuration.
  factory DiagnosticsConfig.of({
    bool enabled = true,
    bool loggingEnabled = true,
    bool performanceMonitoringEnabled = true,
    bool memoryMonitoringEnabled = true,
    bool networkMonitoringEnabled = true,
    LogLevel minimumLogLevel = LogLevel.info,
    int maxPerformanceSamples = 200,
    Duration monitoringInterval = const Duration(seconds: 5),
  }) {
    return DiagnosticsConfig(
      (builder) => builder
        ..enabled = enabled
        ..loggingEnabled = loggingEnabled
        ..performanceMonitoringEnabled = performanceMonitoringEnabled
        ..memoryMonitoringEnabled = memoryMonitoringEnabled
        ..networkMonitoringEnabled = networkMonitoringEnabled
        ..minimumLogLevel = minimumLogLevel
        ..maxPerformanceSamples = maxPerformanceSamples
        ..monitoringInterval = monitoringInterval,
    );
  }

  DiagnosticsConfig._();

  /// A configuration nobody filled in watches everything, from info upward,
  /// with two hundred samples every five seconds.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(DiagnosticsConfigBuilder builder) => builder
    ..enabled = true
    ..loggingEnabled = true
    ..performanceMonitoringEnabled = true
    ..memoryMonitoringEnabled = true
    ..networkMonitoringEnabled = true
    ..minimumLogLevel = LogLevel.info
    ..maxPerformanceSamples = 200
    ..monitoringInterval = const Duration(seconds: 5);

  /// A monitor that keeps no samples or measures on a zero interval is not a
  /// configuration the subsystem can act on, so it is refused here.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(DiagnosticsConfigBuilder builder) {
    final maxPerformanceSamples = builder.maxPerformanceSamples;
    final monitoringInterval = builder.monitoringInterval;
    assert(
      maxPerformanceSamples == null || maxPerformanceSamples > 0,
      'maxPerformanceSamples must be positive',
    );
    assert(
      monitoringInterval == null || monitoringInterval > Duration.zero,
      'monitoringInterval must be positive',
    );
  }

  /// Whether the diagnostics subsystem is enabled.
  bool get enabled;

  /// Whether diagnostic logging is enabled.
  bool get loggingEnabled;

  /// Whether performance monitoring is enabled.
  bool get performanceMonitoringEnabled;

  /// Whether memory monitoring is enabled.
  bool get memoryMonitoringEnabled;

  /// Whether network monitoring is enabled.
  bool get networkMonitoringEnabled;

  /// Minimum severity level emitted by the diagnostic logger.
  LogLevel get minimumLogLevel;

  /// Maximum number of performance samples retained by the monitor.
  int get maxPerformanceSamples;

  /// Default interval between periodic diagnostic measurements.
  Duration get monitoringInterval;
}
