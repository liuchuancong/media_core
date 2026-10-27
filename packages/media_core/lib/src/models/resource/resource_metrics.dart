import 'package:built_value/built_value.dart';
import 'package:media_core/src/util/collection/math_utils.dart';

part 'resource_metrics.g.dart';

/// Represents runtime resource metrics.
///
/// [ResourceMetrics] is a read-only data model
/// describing the current resource consumption
/// of the media core runtime.
///
/// It aggregates information from:
///
/// - decoder usage
/// - memory usage
/// - bandwidth usage
/// - thermal state
/// - active player count
///
/// It is used by:
///
/// - ResourceManager
/// - Monitoring systems
/// - Debug tools
/// - Performance analyzers
///
/// It does not:
///
/// - collect metrics
/// - calculate hardware usage
/// - release resources
/// - control playback
///
/// Those responsibilities belong to:
///
/// - DecoderManager
/// - MemoryManager
/// - BandwidthManager
/// - ThermalManager
///
/// Metrics flow:
///
/// ```text
/// DecoderManager
///        |
/// MemoryManager
///        |
/// BandwidthManager
///        |
/// ThermalManager
///        |
///        v
/// ResourceMetrics
///        |
///        v
/// ResourceSnapshot
/// ```
abstract class ResourceMetrics implements Built<ResourceMetrics, ResourceMetricsBuilder> {
  /// Builds ResourceMetrics from a [updates] callback — the codegen entry.
  factory ResourceMetrics([void Function(ResourceMetricsBuilder)? updates]) = _$ResourceMetrics;

  /// Creates resource metrics, replacing only the counters named.
  ///
  /// An omitted counter keeps the zero written in [_initialize], which is the
  /// default the original constructor spelled out.
  factory ResourceMetrics.of({
    int? decoderCount,
    int? hardwareDecoderCount,
    int? memoryBytes,
    double? bandwidthMbps,
    int? activePlayers,
    int? preloadingPlayers,
    String? thermalState,
    DateTime? timestamp,
  }) {
    return ResourceMetrics((builder) {
      if (decoderCount != null) {
        builder.decoderCount = decoderCount;
      }
      if (hardwareDecoderCount != null) {
        builder.hardwareDecoderCount = hardwareDecoderCount;
      }
      if (memoryBytes != null) {
        builder.memoryBytes = memoryBytes;
      }
      if (bandwidthMbps != null) {
        builder.bandwidthMbps = bandwidthMbps;
      }
      if (activePlayers != null) {
        builder.activePlayers = activePlayers;
      }
      if (preloadingPlayers != null) {
        builder.preloadingPlayers = preloadingPlayers;
      }
      if (thermalState != null) {
        builder.thermalState = thermalState;
      }
      builder.timestamp = timestamp;
    });
  }

  ResourceMetrics._();

  /// A sample with nothing observed is a sample of an idle runtime, so every
  /// counter starts at zero and the thermal state at the calmest level; absent
  /// would be a different claim from zero.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ResourceMetricsBuilder builder) => builder
    ..decoderCount = 0
    ..hardwareDecoderCount = 0
    ..memoryBytes = 0
    ..bandwidthMbps = 0
    ..activePlayers = 0
    ..preloadingPlayers = 0
    ..thermalState = 'normal';

  /// Number of active decoders.
  int get decoderCount;

  /// Number of hardware decoders.
  int get hardwareDecoderCount;

  /// Current memory usage.
  ///
  /// Unit:
  ///
  /// bytes
  int get memoryBytes;

  /// Current bandwidth usage.
  ///
  /// Unit:
  ///
  /// Mbps
  double get bandwidthMbps;

  /// Number of active players.
  int get activePlayers;

  /// Number of players currently preloading.
  int get preloadingPlayers;

  /// Current thermal state.
  ///
  /// Stored as string because
  /// metrics may be serialized externally.
  String get thermalState;

  /// Metric collection timestamp.
  DateTime? get timestamp;

  /// Returns an empty metrics object.
  static final ResourceMetrics empty = ResourceMetrics.of();

  /// Memory usage in megabytes.
  double get memoryMB {
    return MathUtils.bytesToMb(memoryBytes);
  }

  /// Whether hardware decoding is active.
  bool get hasHardwareDecoder {
    return hardwareDecoderCount > 0;
  }

  /// Whether any decoder exists.
  bool get hasDecoder {
    return decoderCount > 0;
  }

  /// Whether players are active.
  bool get hasActivePlayers {
    return activePlayers > 0;
  }

  /// Whether preload is running.
  bool get hasPreload {
    return preloadingPlayers > 0;
  }
}
