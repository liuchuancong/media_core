import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/source/media_track.dart';
import 'package:media_core/src/source/model/media_source.dart';

part 'quality_candidate.g.dart';

/// One selectable playback quality.
///
/// A [QualityCandidate] is the unit a viewer chooses from — 4K, 1080p,
/// "auto" — bound to the concrete [MediaSource] that delivers it.
/// Sources rather than quality codes: the whole point of the
/// MediaSource model is that the engine never learns what a Bilibili
/// quality id means, and a switch that hands an adapter a source
/// keeps that promise.
///
/// Responsibilities:
///
/// - name a quality and point at its media
///
/// It does not:
///
/// - know how to resume into it (that is QualitySwitchController)
/// - carry playback state
///
/// Those belong to:
///
/// - QualitySwitchController
/// - PlayerHandle
abstract class QualityCandidate implements Built<QualityCandidate, QualityCandidateBuilder> {
  /// Builds a candidate from a [updates] callback — the codegen entry.
  factory QualityCandidate([void Function(QualityCandidateBuilder)? updates]) = _$QualityCandidate;

  /// Creates a quality candidate.
  factory QualityCandidate.of({
    required String label,
    required MediaSource source,
    int? bitrate,
    String? id,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return QualityCandidate(
      (builder) => builder
        ..label = label
        ..source = source
        ..bitrate = bitrate
        ..id = id
        ..attributes = attributes,
    );
  }

  QualityCandidate._();

  /// An unset attribute bag stays empty rather than null; bitrate and
  /// provider id are genuinely absent until the host states them.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(QualityCandidateBuilder builder) => builder..attributes = const <String, Object?>{};

  /// Builds candidates from progressive sources.
  ///
  /// [labelOf] and [bitrateOf] let the caller map its own model; the
  /// default labels use the source's primary track when it carries
  /// one, because a quality list built without labels would be
  /// numbers a human cannot choose from.
  static List<QualityCandidate> fromProgressive(
    Iterable<MediaSource> sources, {
    String Function(MediaSource source)? labelOf,
    int Function(MediaSource source)? bitrateOf,
  }) {
    return sources
        .map((source) {
          return QualityCandidate.of(
            label: labelOf?.call(source) ?? _defaultLabel(source),
            source: source,
            bitrate: bitrateOf?.call(source),
          );
        })
        .toList(growable: false);
  }

  /// Builds one candidate per video track of a composite source,
  /// pairing it with the given audio tracks.
  ///
  /// A DASH representation list is video tracks (each with its own
  /// bitrate and quality label) sharing one or more audio essences;
  /// [audioTracks] carries the audio the switch must keep for every
  /// quality. If the composite has no audio, pass an empty list.
  ///
  /// [subtitleTracks] and [live] carry over from the source being
  /// switched: dropping the captions would play the same picture with
  /// less, and dropping the live declaration would reclassify a
  /// broadcast as VOD, turning off every downstream `isLive` guard.
  static List<QualityCandidate> fromCompositeTracks(
    List<MediaTrack> videoTracks, {
    List<MediaTrack> audioTracks = const <MediaTrack>[],
    List<MediaTrack> subtitleTracks = const <MediaTrack>[],
    bool live = false,
    String Function(MediaTrack track)? labelOf,
  }) {
    return videoTracks
        .map((track) {
          return QualityCandidate.of(
            label: labelOf?.call(track) ?? '${track.bitrate ?? 0} bps',
            source: CompositeMediaSource(
              videoTracks: [track],
              audioTracks: audioTracks,
              subtitleTracks: subtitleTracks,
              live: live,
            ),
            bitrate: track.bitrate,
          );
        })
        .toList(growable: false);
  }

  static String _defaultLabel(MediaSource source) {
    final track = switch (source) {
      ProgressiveMediaSource(:final track) => track,
      CompositeMediaSource() => source.primaryVideo ?? source.primaryAudio,
    };
    if (track == null) {
      return 'unknown';
    }
    final bitrate = track.bitrate;
    if (bitrate != null) {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    }
    return track.uri.toString();
  }

  /// Human-readable choice label ("1080P", "4K", "Auto").
  String get label;

  /// The media to open when this quality is chosen.
  MediaSource get source;

  /// Optional declared bitrate in bits per second, for ordering and
  /// for the auto-select comparison the host runs against bandwidth.
  int? get bitrate;

  /// Optional stable id (a provider quality code).
  String? get id;

  /// Provider attributes; opaque to media_core.
  Map<String, Object?> get attributes;
}
