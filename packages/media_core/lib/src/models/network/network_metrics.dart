import 'package:built_value/built_value.dart';
import 'package:media_core/media_core.dart' show DiagnosticsManager;
import 'package:media_core/src/network/monitor/network_monitor.dart';

part 'network_metrics.g.dart';

/// Represents network performance metrics.
///
/// A [NetworkMetrics] is an immutable snapshot
/// containing network performance statistics.
///
/// Responsibilities:
///
/// - store latency information
/// - store bandwidth information
/// - store request statistics
/// - provide diagnostic data
///
/// It does not:
///
/// - measure network speed
/// - perform ping tests
/// - collect metrics automatically
///
/// Those belong to:
///
/// - [NetworkMonitor]
/// - [DiagnosticsManager]
abstract class NetworkMetrics implements Built<NetworkMetrics, NetworkMetricsBuilder> {
  /// Builds metrics from a [updates] callback — the codegen entry.
  factory NetworkMetrics([void Function(NetworkMetricsBuilder)? updates]) = _$NetworkMetrics;

  /// Creates network metrics.
  factory NetworkMetrics.of({
    int? averageLatency,
    int? minimumLatency,
    int? maximumLatency,
    int? downloadSpeed,
    int? uploadSpeed,
    int totalRequests = 0,
    int successfulRequests = 0,
    int failedRequests = 0,
    int receivedBytes = 0,
    int sentBytes = 0,
    DateTime? timestamp,
  }) {
    return NetworkMetrics(
      (builder) => builder
        ..averageLatency = averageLatency
        ..minimumLatency = minimumLatency
        ..maximumLatency = maximumLatency
        ..downloadSpeed = downloadSpeed
        ..uploadSpeed = uploadSpeed
        ..totalRequests = totalRequests
        ..successfulRequests = successfulRequests
        ..failedRequests = failedRequests
        ..receivedBytes = receivedBytes
        ..sentBytes = sentBytes
        ..timestamp = timestamp,
    );
  }

  NetworkMetrics._();

  /// Creates empty metrics.
  factory NetworkMetrics.empty() => NetworkMetrics.of();

  /// A metrics snapshot counts zero unless it is told otherwise;
  /// latency, speed and timestamp stay unavailable rather than zero.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(NetworkMetricsBuilder builder) => builder
    ..totalRequests = 0
    ..successfulRequests = 0
    ..failedRequests = 0
    ..receivedBytes = 0
    ..sentBytes = 0;

  /// Average latency in milliseconds.
  int? get averageLatency;

  /// Minimum latency in milliseconds.
  int? get minimumLatency;

  /// Maximum latency in milliseconds.
  int? get maximumLatency;

  /// Download throughput in bytes per second.
  int? get downloadSpeed;

  /// Upload throughput in bytes per second.
  int? get uploadSpeed;

  /// Total requests performed.
  int get totalRequests;

  /// Successful request count.
  int get successfulRequests;

  /// Failed request count.
  int get failedRequests;

  /// Total received bytes.
  int get receivedBytes;

  /// Total sent bytes.
  int get sentBytes;

  /// Timestamp of this metrics snapshot.
  DateTime? get timestamp;
}

/// Extensions for [NetworkMetrics].
extension NetworkMetricsExtension on NetworkMetrics {
  /// Total request failure rate.
  ///
  /// Returns a value between `0.0` and `1.0`.
  double get failureRate {
    if (totalRequests == 0) {
      return 0;
    }

    return failedRequests / totalRequests;
  }

  /// Whether requests are failing frequently.
  bool get hasHighFailureRate {
    return failureRate >= 0.5;
  }

  /// Whether latency information exists.
  bool get hasLatency {
    return averageLatency != null;
  }

  /// Whether download speed information exists.
  bool get hasDownloadSpeed {
    return downloadSpeed != null;
  }

  /// Whether network is performing well.
  bool get isHealthy {
    return !hasHighFailureRate;
  }
}
