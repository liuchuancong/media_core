import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/resource/resource_metrics.dart';
import 'package:media_core/src/resource/state/resource_pressure.dart';

part 'resource_state.g.dart';

/// Represents current resource runtime state.
///
/// [ResourceState] is the central immutable state
/// model of the resource subsystem.
///
/// It aggregates:
///
/// - memory state
/// - decoder state
/// - bandwidth state
/// - thermal state
/// - pressure state
///
/// It is used by:
///
/// - ResourceManager
/// - PlayerCoordinator
/// - PreloadManager
/// - PerformanceMonitor
///
/// It does not:
///
/// - collect hardware information
/// - release resources
/// - allocate resources
/// - control players
///
/// Those responsibilities belong to:
///
/// - MemoryManager
/// - DecoderManager
/// - BandwidthManager
/// - ThermalManager
///
/// State flow:
///
/// ```text
/// MemoryManager
///       |
/// DecoderManager
///       |
/// BandwidthManager
///       |
/// ThermalManager
///       |
///       v
/// ResourceState
///       |
///       v
/// ResourceManager
/// ```
abstract class ResourceState implements Built<ResourceState, ResourceStateBuilder> {
  /// Builds ResourceState from a [updates] callback — the codegen entry.
  factory ResourceState([void Function(ResourceStateBuilder)? updates]) = _$ResourceState;

  /// Creates resource state, replacing only the fields named.
  ///
  /// A field left out keeps the value written in [_initialize], which is the
  /// default the original constructor spelled out.
  factory ResourceState.of({
    ResourceMetrics? metrics,
    ResourcePressure? pressure,
    bool? enabled,
    bool? releasing,
    bool? degraded,
    DateTime? timestamp,
  }) {
    return ResourceState((builder) {
      if (metrics != null) {
        builder.metrics = metrics.toBuilder();
      }
      if (pressure != null) {
        builder.pressure = pressure;
      }
      if (enabled != null) {
        builder.enabled = enabled;
      }
      if (releasing != null) {
        builder.releasing = releasing;
      }
      if (degraded != null) {
        builder.degraded = degraded;
      }
      builder.timestamp = timestamp;
    });
  }

  ResourceState._();

  /// Resource management is on until something turns it off, and a state that
  /// has observed nothing is an idle one — pressure and counters start at
  /// their calmest values rather than staying absent, because "no pressure"
  /// and "pressure unknown" are different claims.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ResourceStateBuilder builder) => builder
    ..metrics = ResourceMetrics.empty.toBuilder()
    ..pressure = ResourcePressure.none
    ..enabled = true
    ..releasing = false
    ..degraded = false;

  /// Current resource metrics.
  ResourceMetrics get metrics;

  /// Current resource pressure.
  ResourcePressure get pressure;

  /// Whether resource management is enabled.
  bool get enabled;

  /// Whether resources are currently being released.
  bool get releasing;

  /// Whether the system is running in degraded mode.
  ///
  /// Degraded mode may include:
  ///
  /// - lower quality stream
  /// - disabled preload
  /// - reduced decoder usage
  bool get degraded;

  /// State update timestamp.
  DateTime? get timestamp;

  /// Returns default state.
  static final ResourceState initial = ResourceState.of();

  /// Whether any resource pressure exists.
  bool get hasPressure {
    return pressure.hasPressure;
  }

  /// Whether emergency handling is required.
  bool get isEmergency {
    return pressure == ResourcePressure.emergency;
  }

  /// Whether cleanup should start.
  bool get shouldRelease {
    return pressure.shouldReleaseResources;
  }

  /// Whether preload should stop.
  bool get shouldStopPreload {
    return pressure.shouldStopPreload;
  }

  /// Whether quality reduction is recommended.
  bool get shouldReduceQuality {
    return pressure.shouldReduceQuality;
  }

  /// Whether resource layer is idle.
  bool get isIdle {
    return !releasing && !degraded && pressure == ResourcePressure.none;
  }

  /// Creates a modified state.
  ///
  /// A null argument keeps the current value, exactly as the copy this
  /// replaced did.
  ResourceState copyWith({
    ResourceMetrics? metrics,
    ResourcePressure? pressure,
    bool? enabled,
    bool? releasing,
    bool? degraded,
    DateTime? timestamp,
  }) {
    return rebuild((builder) {
      if (metrics != null) {
        builder.metrics = metrics.toBuilder();
      }
      if (pressure != null) {
        builder.pressure = pressure;
      }
      if (enabled != null) {
        builder.enabled = enabled;
      }
      if (releasing != null) {
        builder.releasing = releasing;
      }
      if (degraded != null) {
        builder.degraded = degraded;
      }
      if (timestamp != null) {
        builder.timestamp = timestamp;
      }
    });
  }

  /// Creates state while releasing resources.
  ResourceState startRelease() {
    return rebuild((builder) => builder..releasing = true);
  }

  /// Creates state after releasing resources.
  ResourceState finishRelease() {
    return rebuild((builder) => builder..releasing = false);
  }

  /// Creates degraded mode state.
  ResourceState enableDegradedMode() {
    return rebuild((builder) => builder..degraded = true);
  }

  /// Creates normal mode state.
  ResourceState disableDegradedMode() {
    return rebuild((builder) => builder..degraded = false);
  }
}
