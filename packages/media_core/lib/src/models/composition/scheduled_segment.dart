import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/composition/schedule_clip.dart';
import 'package:media_core/src/models/timeline/library.dart' show MediaSegment;

part 'scheduled_segment.g.dart';

/// One clip placed at an absolute position on the combined timeline.
///
/// [ScheduledSegment] is the atomic answer to "what is playing at
/// time t": a clip, and where it starts and ends on the single clock
/// the player reports. The composer produces these; nothing else
/// assigns coordinates, which keeps the placement arithmetic in one
/// auditable place.
abstract class ScheduledSegment implements Built<ScheduledSegment, ScheduledSegmentBuilder> {
  /// Builds ScheduledSegment from a [updates] callback — the codegen entry.
  factory ScheduledSegment([void Function(ScheduledSegmentBuilder)? updates]) = _$ScheduledSegment;

  /// Creates a placed segment.
  factory ScheduledSegment.of({
    required ScheduleClip clip,
    required Duration start,
    required Duration end,
    Duration? programTime,
  }) {
    return ScheduledSegment(
      (builder) => builder
        ..clip = clip.toBuilder()
        ..start = start
        ..end = end
        ..programTime = programTime,
    );
  }

  ScheduledSegment._();

  /// A segment that ends before it starts cannot be placed on a clock the
  /// playhead walks forward.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(ScheduledSegmentBuilder builder) {
    final start = builder.start;
    final end = builder.end;
    assert(start == null || end == null || end >= start, 'A scheduled segment cannot end before it starts.');
  }

  /// The clip occupying this span.
  ScheduleClip get clip;

  /// Combined-timeline time at which the segment begins.
  Duration get start;

  /// Combined-timeline time at which the segment ends.
  Duration get end;

  /// Program time this segment resumes at or cuts out of, for content
  /// segments.
  ///
  /// Null for non-content clips. For content segments this is the
  /// program time at [start]; a content segment never spans a break
  /// (the composer splits it at every cut), so mapping forward is
  /// always `programTime + (combinedTime - start)` within the
  /// segment — which is what makes a seek on a broken timeline
  /// resolvable without walking the whole segment list.
  Duration? get programTime;

  /// Length of this segment on the combined timeline.
  Duration get duration => end - start;

  /// The segment's [MediaSegment] geometry, for overlay layers that
  /// only need ranges and labels.
  MediaSegment toMediaSegment() => MediaSegment.of(
    start: start,
    duration: duration,
    label: clip.kind.name,
    attributes: <String, Object?>{if (clip.id != null) 'clipId': clip.id, ...clip.attributes},
  );

  /// Whether [time] falls inside this segment, end-exclusive.
  bool covers(Duration time) => time >= start && time < end;

  /// Program time for [time] inside this content segment.
  ///
  /// Returns null for a non-content segment or a [time] outside it —
  /// a wrong answer here would silently resume the program at the
  /// wrong place, so an out-of-range ask gets no answer.
  Duration? programTimeAt(Duration time) {
    if (!covers(time) || programTime == null) {
      return null;
    }
    return programTime! + (time - start);
  }
}
