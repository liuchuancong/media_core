import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/resource/model/resource_metrics.dart';
import 'package:media_core/src/resource/state/resource_pressure.dart';
import 'package:media_core/src/resource/state/resource_state.dart';

part 'resource_snapshot.g.dart';

/// Immutable snapshot of resource runtime state.
///
/// [ResourceSnapshot] provides a stable read-only
/// representation of the resource subsystem at
/// a specific point in time.
///
/// It is designed for:
///
/// - external observers
/// - debugging tools
/// - telemetry systems
/// - UI state binding
/// - performance monitoring
///
/// It does not:
///
/// - update resources
/// - trigger cleanup
/// - allocate resources
/// - release resources
///
/// Those responsibilities belong to:
///
/// - ResourceManager
/// - MemoryManager
/// - DecoderManager
/// - BandwidthManager
///
/// Snapshot flow:
///
/// ```text
/// ResourceManager
///        |
///        v
/// ResourceSnapshot
///        |
///        +--> UI
///        +--> Debug tools
///        +--> Metrics
/// ```
abstract class ResourceSnapshot implements Built<ResourceSnapshot, ResourceSnapshotBuilder> {
  /// Builds a snapshot from a [updates] callback — the codegen entry.
  factory ResourceSnapshot([void Function(ResourceSnapshotBuilder)? updates]) = _$ResourceSnapshot;

  /// Creates resource snapshot.
  factory ResourceSnapshot.of({required ResourceState state, required DateTime createdAt}) {
    return ResourceSnapshot(
      (builder) => builder
        ..state = state
        ..createdAt = createdAt,
    );
  }

  ResourceSnapshot._();

  /// Creates an empty snapshot.
  factory ResourceSnapshot.empty() {
    return ResourceSnapshot.fromState(ResourceState.initial);
  }

  /// Creates snapshot from state.
  factory ResourceSnapshot.fromState(ResourceState state) {
    return ResourceSnapshot.of(state: state, createdAt: clock.now());
  }

  /// Resource runtime state.
  ResourceState get state;

  /// Snapshot creation time.
  DateTime get createdAt;

  /// Current resource metrics.
  ResourceMetrics get metrics {
    return state.metrics;
  }

  /// Current resource pressure.
  ResourcePressure get pressure {
    return state.pressure;
  }

  /// Whether resource pressure exists.
  bool get hasPressure {
    return pressure.hasPressure;
  }

  /// Whether emergency handling is required.
  bool get isEmergency {
    return pressure == ResourcePressure.emergency;
  }

  /// Whether system is degraded.
  bool get isDegraded {
    return state.degraded;
  }

  /// Whether resources are being released.
  bool get isReleasing {
    return state.releasing;
  }

  /// Number of active decoders.
  int get decoderCount {
    return metrics.decoderCount;
  }

  /// Current memory usage.
  int get memoryBytes {
    return metrics.memoryBytes;
  }

  /// Current bandwidth usage.
  double get bandwidthMbps {
    return metrics.bandwidthMbps;
  }

  /// Returns whether two snapshots
  /// have the same pressure level.
  bool samePressure(ResourceSnapshot other) {
    return pressure == other.pressure;
  }

  /// Returns whether resource usage changed.
  bool usageChanged(ResourceSnapshot other) {
    return metrics != other.metrics;
  }
}
