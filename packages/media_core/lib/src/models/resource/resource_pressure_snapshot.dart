import 'package:built_value/built_value.dart';
import 'package:media_core/src/resource/state/resource_pressure.dart';

part 'resource_pressure_snapshot.g.dart';

/// Immutable resource pressure snapshot.
///
/// Used when resource pressure needs
/// to be passed between managers.
///
/// It does not:
///
/// - calculate pressure
/// - update pressure
/// - trigger actions
abstract class ResourcePressureSnapshot
    implements Built<ResourcePressureSnapshot, ResourcePressureSnapshotBuilder> {
  /// Builds a snapshot from a [updates] callback — the codegen entry.
  factory ResourcePressureSnapshot([void Function(ResourcePressureSnapshotBuilder)? updates]) =
      _$ResourcePressureSnapshot;

  /// Creates resource pressure snapshot.
  factory ResourcePressureSnapshot.of({required ResourcePressure pressure, required DateTime timestamp}) {
    return ResourcePressureSnapshot(
      (builder) => builder
        ..pressure = pressure
        ..timestamp = timestamp,
    );
  }

  ResourcePressureSnapshot._();

  /// Current pressure level.
  ResourcePressure get pressure;

  /// Snapshot timestamp.
  DateTime get timestamp;

  /// Whether pressure exists.
  bool get hasPressure {
    return pressure.hasPressure;
  }

  /// Whether emergency handling is required.
  bool get isEmergency {
    return pressure == ResourcePressure.emergency;
  }
}
