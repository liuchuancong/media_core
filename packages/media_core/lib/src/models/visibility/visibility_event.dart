import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/models/visibility/visibility_event_type.dart';

part 'visibility_event.g.dart';

/// Visibility event.
abstract class VisibilityEvent implements Built<VisibilityEvent, VisibilityEventBuilder> {
  /// Builds an event from a [updates] callback — the codegen entry.
  factory VisibilityEvent([void Function(VisibilityEventBuilder)? updates]) = _$VisibilityEvent;

  /// Creates an event from explicit values.
  factory VisibilityEvent.of({required VisibilityEventType type, required double visibility, DateTime? timestamp}) {
    return VisibilityEvent(
      (builder) => builder
        ..type = type
        ..visibility = visibility
        ..timestamp = timestamp,
    );
  }

  VisibilityEvent._();

  /// Creates an event for [type] stamped with the current time.
  factory VisibilityEvent.now(VisibilityEventType type, double visibility) {
    return VisibilityEvent.of(type: type, visibility: visibility, timestamp: clock.now());
  }

  /// Which transition this event reports.
  VisibilityEventType get type;

  /// Value from 0.0 to 1.0.
  double get visibility;

  /// When the event was emitted; null for hand-built events.
  DateTime? get timestamp;
}
