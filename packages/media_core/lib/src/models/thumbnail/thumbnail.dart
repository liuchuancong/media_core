import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/thumbnail/thumbnail_slice.dart';

part 'thumbnail.g.dart';

/// One preview frame of a scrub track.
///
/// [start] and [end] are the cue window on the media timeline the
/// frame represents — the time a scrubber is hovering, not a playback
/// range. [imageUrl] is either the sprite page (with [slice]) or a
/// standalone image.
abstract class Thumbnail implements Built<Thumbnail, ThumbnailBuilder> {
  /// Builds a frame from a [updates] callback — the codegen entry.
  factory Thumbnail([void Function(ThumbnailBuilder)? updates]) = _$Thumbnail;

  /// Creates one cue of a thumbnail track.
  factory Thumbnail.of({
    required Duration start,
    required Duration end,
    required Uri imageUrl,
    ThumbnailSlice? slice,
  }) {
    return Thumbnail(
      (builder) => builder
        ..start = start
        ..end = end
        ..imageUrl = imageUrl
        ..slice = slice?.toBuilder(),
    );
  }

  Thumbnail._();

  /// Media time this frame begins representing.
  Duration get start;

  /// Media time this frame stops representing.
  Duration get end;

  /// The image, sprite page included, as reported by the cue.
  Uri get imageUrl;

  /// The crop inside a sprite page; null when the cue is a single
  /// image with no fragment.
  ThumbnailSlice? get slice;

  /// Whether [time] falls inside this cue, end-exclusive.
  bool covers(Duration time) => time >= start && time < end;
}
