import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/composition/schedule_position.dart';
import 'package:media_core/src/models/composition/scheduled_segment.dart';

part 'composed_schedule.g.dart';

/// A playback schedule resolved onto one absolute timeline.
///
/// The composer's product: ordered, non-overlapping [segments] that
/// tile the whole combined clock, plus [totalDuration]. Consumers ask
/// it questions only — the playhead never moves anything.
///
/// Responsibilities:
///
/// - answer position and boundary questions in constant or linear time
///
/// It does not:
///
/// - re-plan (it is immutable by construction)
/// - observe the playhead
///
/// Those belong to:
///
/// - TimelineComposer
/// - ScheduleNavigator
abstract class ComposedSchedule implements Built<ComposedSchedule, ComposedScheduleBuilder> {
  /// Builds ComposedSchedule from a [updates] callback — the codegen entry.
  factory ComposedSchedule([void Function(ComposedScheduleBuilder)? updates]) = _$ComposedSchedule;

  /// Creates a composed schedule from placed [segments].
  factory ComposedSchedule.of({required List<ScheduledSegment> segments}) {
    return ComposedSchedule((builder) => builder..segments = segments);
  }

  ComposedSchedule._();

  /// The empty schedule: no clips, no timeline.
  static final ComposedSchedule empty = ComposedSchedule.of(segments: const <ScheduledSegment>[]);

  /// A composed schedule must tile its own clock; a gap or an overlap means
  /// the composer miscounted, and a consumer asking "what is on at t" would
  /// get a silently wrong answer.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(ComposedScheduleBuilder builder) {
    final segments = builder.segments;
    assert(segments == null || _tilesWithoutGaps(segments), 'Composed segments must be ordered and gap-free.');
  }

  /// Every clip in placement order, tiling the combined clock.
  List<ScheduledSegment> get segments;

  /// Total length of the combined timeline.
  Duration get totalDuration {
    if (segments.isEmpty) {
      return Duration.zero;
    }
    return segments.last.end;
  }

  /// The segment under [time], or null when past the end.
  ScheduledSegment? segmentAt(Duration time) {
    for (final segment in segments) {
      if (segment.covers(time)) {
        return segment;
      }
    }
    return null;
  }

  /// Where the playhead is on this schedule.
  ///
  /// A [time] past the end clamps into the final segment's end and is
  /// reported at that boundary — the navigator treats "at the end" as
  /// a completed playhead, not a miss.
  SchedulePosition positionAt(Duration time) {
    if (segments.isEmpty) {
      throw StateError('positionAt called on an empty ComposedSchedule.');
    }
    final clamped = time < Duration.zero ? Duration.zero : time;
    for (final segment in segments) {
      if (segment.covers(clamped)) {
        return SchedulePosition.of(
          segment: segment,
          localTime: clamped - segment.start,
          programTime: segment.programTimeAt(clamped),
        );
      }
    }
    final last = segments.last;
    return SchedulePosition.of(segment: last, localTime: last.duration, programTime: last.programTimeAt(last.end));
  }

  /// The next segment boundary at or after [time].
  ///
  /// The navigator's wake-up signal: this is the combined time at
  /// which the playing clip changes, and the only time a correct
  /// schedule demands the host act.
  Duration? nextBoundary(Duration time) {
    for (final segment in segments) {
      if (segment.end > time) {
        return segment.end;
      }
    }
    return null;
  }

  static bool _tilesWithoutGaps(List<ScheduledSegment> segments) {
    var cursor = Duration.zero;
    for (final segment in segments) {
      if (segment.start != cursor) {
        return false;
      }
      if (segment.end <= segment.start) {
        return false;
      }
      cursor = segment.end;
    }
    return true;
  }
}
