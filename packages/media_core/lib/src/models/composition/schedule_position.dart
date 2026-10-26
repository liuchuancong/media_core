import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/composition/clip_kind.dart';
import 'package:media_core/src/models/composition/schedule_clip.dart';
import 'package:media_core/src/models/composition/scheduled_segment.dart';

part 'schedule_position.g.dart';

/// Where the playhead is on a composed schedule.
///
/// The navigator and the host read the same fact from here: which
/// clip is under the playhead, where inside that clip the playhead
/// sits, and — for content — what program time that corresponds to
/// (resume position, progress bars, DVR mapping, analytics).
abstract class SchedulePosition implements Built<SchedulePosition, SchedulePositionBuilder> {
  /// Builds SchedulePosition from a [updates] callback — the codegen entry.
  factory SchedulePosition([void Function(SchedulePositionBuilder)? updates]) = _$SchedulePosition;

  /// Creates a position.
  factory SchedulePosition.of({required ScheduledSegment segment, required Duration localTime, Duration? programTime}) {
    return SchedulePosition(
      (builder) => builder
        ..segment = segment.toBuilder()
        ..localTime = localTime
        ..programTime = programTime,
    );
  }

  SchedulePosition._();

  /// The segment under the playhead.
  ScheduledSegment get segment;

  /// Time since the segment began.
  Duration get localTime;

  /// Program time under the playhead, when the segment is content.
  Duration? get programTime;

  /// The clip under the playhead.
  ScheduleClip get clip => segment.clip;

  /// What kind of clip is playing.
  ClipKind get kind => segment.clip.kind;
}
