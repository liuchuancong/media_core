import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/models/lifecycle/lifecycle_event_type.dart';

part 'lifecycle_event.g.dart';

/// Lifecycle event.
abstract class LifecycleEvent implements Built<LifecycleEvent, LifecycleEventBuilder> {
  /// Builds an event from a [updates] callback — the codegen entry.
  factory LifecycleEvent([void Function(LifecycleEventBuilder)? updates]) = _$LifecycleEvent;

  /// Creates an event for [type], optionally stamped with [timestamp].
  factory LifecycleEvent.of({required LifecycleEventType type, DateTime? timestamp}) {
    return LifecycleEvent(
      (builder) => builder
        ..type = type
        ..timestamp = timestamp,
    );
  }

  LifecycleEvent._();

  /// Creates an event for [type] stamped with the current clock time.
  factory LifecycleEvent.now(LifecycleEventType type) {
    return LifecycleEvent.of(type: type, timestamp: clock.now());
  }

  /// Which lifecycle transition this event reports.
  LifecycleEventType get type;

  /// When the transition happened, or `null` when the caller left it unset.
  DateTime? get timestamp;
}
