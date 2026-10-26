import 'package:built_value/built_value.dart';
import 'package:media_core/src/composition/timeline/media_break.dart' show BreakPosition;
import 'package:media_core/src/models/composition/schedule_clip.dart';

part 'media_break.g.dart';

/// A group of clips that cuts into the program at one position.
///
/// [MediaBreak] models an ad pod (or any interruption block): one
/// position on the program, one ordered list of creatives. The
/// internal order matters (pod sequences pay per slot), the grouping
/// matters (a break completes when its last clip finishes), and the
/// two are independent of where the break sits.
///
/// Responsibilities:
///
/// - bind clips to one placement
///
/// It does not:
///
/// - know absolute timeline coordinates (that is ScheduledSegment,
///   assigned by TimelineComposer once it has all breaks and the
///   program length)
/// - fire tracking
///
/// Those belong to:
///
/// - ComposedSchedule
/// - the host
abstract class MediaBreak implements Built<MediaBreak, MediaBreakBuilder> {
  /// Builds MediaBreak from a [updates] callback — the codegen entry.
  factory MediaBreak([void Function(MediaBreakBuilder)? updates]) = _$MediaBreak;

  /// Creates a break at [position] with [clips] in playback order.
  factory MediaBreak.of({required BreakPosition position, required List<ScheduleClip> clips}) {
    return MediaBreak(
      (builder) => builder
        ..position = position
        ..clips = clips,
    );
  }

  MediaBreak._();

  /// A break with no clips cannot be scheduled, so it is refused rather
  /// than carried as an empty interruption.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(MediaBreakBuilder builder) {
    final clips = builder.clips;
    assert(clips == null || clips.isNotEmpty, 'A break with no clips cannot be scheduled.');
  }

  /// Where this break attaches to the program.
  BreakPosition get position;

  /// The clips in this break, in the order they play.
  ///
  /// Breaks of kind content are rejected by `PlaybackSchedule` rather
  /// than silently honored: a "break" that contains the program is a
  /// playlist, not an interruption, and pretending otherwise would
  /// hide a real authoring mistake behind working code.
  List<ScheduleClip> get clips;

  /// Total time this break occupies once placed.
  Duration get totalDuration {
    var total = Duration.zero;
    for (final clip in clips) {
      total += clip.duration;
    }
    return total;
  }
}
