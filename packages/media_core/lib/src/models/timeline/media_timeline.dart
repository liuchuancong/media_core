import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/source/media_track.dart';
import 'package:media_core/src/models/source/media_track_type.dart';
import 'package:media_core/src/models/timeline/media_cue.dart';
import 'package:media_core/src/models/timeline/media_segment.dart';
import 'package:media_core/src/models/timeline/timeline_track.dart';
import 'package:media_core/src/source/model/media_source.dart';

part 'media_timeline.g.dart';

/// The presentation timeline of a [MediaSource].
///
/// DASH periods and HLS discontinuities do not all start at media
/// time zero: the audio representation may trail the video by a
/// frame's worth of milliseconds, or both may share a large period
/// base. [MediaTimeline.from] turns those per-track
/// [MediaTrack.startOffset] values into one shared clock — the
/// earliest track pinned at zero, every other track shifted by its
/// distance from that earliest start — so an adapter merging essence
/// streams (MPV's `audio-files`, Media3's `MergingMediaSource`) has a
/// single number to apply per track instead of raw manifest offsets.
///
/// Progressive sources get the trivial timeline: one track at zero.
///
/// Responsibilities:
///
/// - align composite tracks onto one presentation clock
/// - answer time-conversion questions per track
/// - carry the optional segment and cue layers above the alignment
///
/// It does not:
///
/// - know track durations (inspection owns that)
/// - parse subtitle formats
/// - schedule seeks
///
/// Those belong to:
///
/// - SourceInspector
/// - a cue-producing provider
/// - PlayerAdapter
abstract class MediaTimeline implements Built<MediaTimeline, MediaTimelineBuilder> {
  /// Builds a timeline from a [updates] callback — the codegen entry.
  factory MediaTimeline([void Function(MediaTimelineBuilder)? updates]) = _$MediaTimeline;

  /// Creates a timeline from already-aligned [tracks].
  factory MediaTimeline.of({
    required List<TimelineTrack> tracks,
    Duration originShift = Duration.zero,
    List<MediaSegment> segments = const <MediaSegment>[],
    List<MediaCue> cues = const <MediaCue>[],
  }) {
    return MediaTimeline(
      (builder) => builder
        ..tracks = tracks
        ..originShift = originShift
        ..segments = segments
        ..cues = cues,
    );
  }

  MediaTimeline._();

  /// Derives the presentation timeline of [source].
  ///
  /// Every track's [MediaTrack.startOffset] is normalized against the
  /// earliest declared offset in the source: the earliest track lands
  /// at zero and the rest follow. The amount subtracted from all
  /// tracks is reported as [originShift] so a caller that needs the
  /// original period base (a manifest reload, for instance) can add
  /// it back.
  ///
  /// Tracks without a `startOffset` are treated as starting at zero —
  /// the common case — which means a source with no offsets at all
  /// produces an all-zero timeline rather than failing.
  factory MediaTimeline.from(MediaSource source) {
    final sourceTracks = source.tracks;
    if (sourceTracks.isEmpty) {
      return MediaTimeline.of(tracks: const <TimelineTrack>[]);
    }

    // The clock anchors at the earliest track, not at media zero: a
    // DASH period where every essence shares a large base offset
    // should start presenting when its first essence starts, not
    // idle through the base.
    var minimum = Duration.zero;
    var seen = false;
    for (final track in sourceTracks) {
      final offset = track.startOffset ?? Duration.zero;
      if (!seen || offset < minimum) {
        minimum = offset;
        seen = true;
      }
    }

    final aligned = sourceTracks
        .map((track) {
          final raw = track.startOffset ?? Duration.zero;
          return TimelineTrack.of(track: track, offset: raw - minimum);
        })
        .toList(growable: false);

    return MediaTimeline.of(tracks: aligned, originShift: minimum);
  }

  /// The empty layers and the origin pin are the honest defaults; a
  /// timeline is only ever defined by the tracks placed on it.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(MediaTimelineBuilder builder) => builder
    ..originShift = Duration.zero
    ..segments = const <MediaSegment>[]
    ..cues = const <MediaCue>[];

  /// The aligned tracks of this timeline.
  List<TimelineTrack> get tracks;

  /// How far the presentation origin was shifted from the raw period
  /// base during [MediaTimeline.from].
  Duration get originShift;

  /// Optional segment layer (chapters, discontinuities, ad breaks).
  List<MediaSegment> get segments;

  /// Optional cue layer (subtitle captions) on presentation time.
  List<MediaCue> get cues;

  /// Whether the timeline has any placed tracks.
  bool get isEmpty => tracks.isEmpty;

  /// The track the playhead follows: the first video essence, else
  /// the first audio, else the first track of any kind.
  TimelineTrack? get primary {
    for (final entry in tracks) {
      if (entry.track.kind == MediaTrackType.video) {
        return entry;
      }
    }
    for (final entry in tracks) {
      if (entry.track.kind == MediaTrackType.audio) {
        return entry;
      }
    }
    return tracks.isEmpty ? null : tracks.first;
  }

  /// The placed entry for [track], if this timeline contains it.
  TimelineTrack? operator [](MediaTrack track) {
    for (final entry in tracks) {
      if (entry.track == track) {
        return entry;
      }
    }
    return null;
  }

  /// Converts a position in [track]'s media to presentation time.
  ///
  /// Returns [mediaTime] unchanged when the track is not part of this
  /// timeline — an unmapped track has no alignment to apply, and
  /// treating it as origin-pinned keeps the result usable instead of
  /// throwing at every subtitle or audio lookup on a rebuilt source.
  Duration presentationTimeFor(MediaTrack track, Duration mediaTime) {
    return this[track]?.presentationTimeFor(mediaTime) ?? mediaTime;
  }

  /// Converts a presentation position to [track]'s media time.
  ///
  /// The result may be negative when [presentationTime] precedes the
  /// track's start; callers must interpret that as "this track has
  /// not begun yet".
  Duration mediaTimeFor(MediaTrack track, Duration presentationTime) {
    return this[track]?.mediaTimeFor(presentationTime) ?? presentationTime;
  }

  /// The segment containing [presentationTime], if any.
  MediaSegment? segmentAt(Duration presentationTime) {
    for (final segment in segments) {
      if (segment.covers(presentationTime)) {
        return segment;
      }
    }
    return null;
  }

  /// Every cue active at [presentationTime].
  List<MediaCue> cuesAt(Duration presentationTime) {
    return cues.where((cue) => cue.covers(presentationTime)).toList(growable: false);
  }
}
