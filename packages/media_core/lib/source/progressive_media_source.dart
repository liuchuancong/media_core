part of 'media_source.dart';

/// A single self-contained media stream.
///
/// [ProgressiveMediaSource] wraps one [MediaTrack] that already
/// carries everything the player needs to play it: an MP4 file, an
/// HLS playlist, an RTMP live line, a plain HTTP video. The name
/// follows ExoPlayer's `ProgressiveMediaSource` vocabulary — "the
/// container is not going to change shape at playback time".
///
/// A source that combines separate video and audio essences is not
/// progressive; it is a [CompositeMediaSource].
///
/// Responsibilities:
///
/// - carry one playable track
/// - report [MediaSourceType.progressive]
///
/// It does not:
///
/// - group related tracks
/// - schedule a backend
///
/// Those belong to:
///
/// - CompositeMediaSource
/// - MediaSourcePlanner
final class ProgressiveMediaSource extends MediaSource {
  /// Creates a progressive source backed by a single [track].
  const ProgressiveMediaSource({required this.track});

  /// Convenience constructor for the extremely common case of
  /// "just play this URL".
  ///
  /// [kind] defaults to [MediaTrackType.video] because most callers
  /// building a single progressive source from a bare URL are holding
  /// a video file; audio-only or subtitle-only inputs should pass the
  /// kind explicitly. Any extra context (headers, mime type, codec)
  /// belongs on the constructed [track] via [MediaTrack.copyWith].
  factory ProgressiveMediaSource.url(
    Object uri, {
    MediaTrackType kind = MediaTrackType.video,
  }) {
    return ProgressiveMediaSource(
      track: MediaTrack(uri: _coerceUri(uri), kind: kind),
    );
  }

  /// The playable track.
  final MediaTrack track;

  @override
  MediaSourceType get type => MediaSourceType.progressive;

  @override
  List<MediaTrack> get tracks => <MediaTrack>[track];

  /// Creates a copy with modifications.
  ProgressiveMediaSource copyWith({MediaTrack? track}) {
    if (track == null) {
      return this;
    }
    return ProgressiveMediaSource(track: track);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressiveMediaSource && other.track == track;

  @override
  int get hashCode => Object.hash(MediaSourceType.progressive, track);

  @override
  String toString() => 'ProgressiveMediaSource(${track.uri})';
}

Uri _coerceUri(Object value) {
  if (value is Uri) {
    return value;
  }
  if (value is String) {
    return Uri.parse(value);
  }
  throw ArgumentError.value(
    value,
    'uri',
    'ProgressiveMediaSource.url accepts Uri or String.',
  );
}
