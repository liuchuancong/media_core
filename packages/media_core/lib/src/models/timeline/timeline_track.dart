import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/source/media_track.dart';
import 'package:media_core/src/models/timeline/media_timeline.dart' show MediaTimeline;

part 'timeline_track.g.dart';

/// One essence track placed on a shared presentation timeline.
///
/// A [MediaTrack]'s [MediaTrack.startOffset] says where its media
/// begins relative to its period; a [TimelineTrack]'s [offset] says
/// where that media sits on the timeline the player presents, after
/// the earliest track has been normalized to zero. The two differ by
/// the origin shift [MediaTimeline.from] applies, and reading only
/// the raw `startOffset` is how two DASH periods with a large common
/// base offset (a `periodStart` in the manifest) would appear to
/// start late.
///
/// Responsibilities:
///
/// - convert between this track's media time and presentation time
///
/// It does not:
///
/// - know the track's duration (inspection owns that)
/// - schedule demuxer seeks
///
/// Those belong to:
///
/// - SourceInspector
/// - PlayerAdapter
abstract class TimelineTrack implements Built<TimelineTrack, TimelineTrackBuilder> {
  /// Builds a placed track from a [updates] callback — the codegen entry.
  factory TimelineTrack([void Function(TimelineTrackBuilder)? updates]) = _$TimelineTrack;

  /// Places [track] on the presentation timeline at [offset].
  factory TimelineTrack.of({required MediaTrack track, Duration offset = Duration.zero}) {
    return TimelineTrack(
      (builder) => builder
        ..track = track.toBuilder()
        ..offset = offset,
    );
  }

  TimelineTrack._();

  /// A track with no stated offset is pinned to the presentation origin.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(TimelineTrackBuilder builder) => builder..offset = Duration.zero;

  /// The essence this entry positions.
  MediaTrack get track;

  /// Where the track's media time zero sits on the presentation
  /// timeline.
  ///
  /// Always non-negative: [MediaTimeline.from] shifts every track so
  /// the earliest one lands exactly at zero.
  Duration get offset;

  /// Whether the track sits exactly at the presentation origin.
  bool get isAtOrigin => offset == Duration.zero;

  /// Converts a position in this track's media to presentation time.
  Duration presentationTimeFor(Duration mediaTime) => mediaTime + offset;

  /// Converts a presentation position to this track's media time.
  ///
  /// Can return a negative duration for a presentation time earlier
  /// than the track's own start; callers deciding whether to show
  /// this track must treat a negative result as "not started yet".
  Duration mediaTimeFor(Duration presentationTime) => presentationTime - offset;
}
