import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/source/media_track_type.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';
import 'package:media_core/src/source/model/player_source.dart';
import 'package:media_core/src/source/types/source_format.dart';
import 'package:media_core/src/source/types/source_media_type.dart';
import 'package:media_core/src/source/types/source_protocol.dart';

part 'media_track.g.dart';

/// A single media stream that a player can consume.
///
/// [MediaTrack] is the atomic unit of the source model. Where
/// [PlayerSource] describes a whole playable input, a track describes
/// exactly one stream: one video essence, one audio essence, or one
/// subtitle file. Composite sources such as Bilibili DASH deliver a
/// `video.m4s` and an `audio.m4s` as separate HTTP resources — each
/// becomes one [MediaTrack], and the pair is assembled into a
/// CompositeMediaSource so no layer above has to re-derive them.
///
/// A track deliberately keeps the access information (headers,
/// start offset) beside the location, because DASH and HLS segments
/// routinely require per-stream request headers that would be lost if
/// the URL alone were carried.
///
/// Responsibilities:
///
/// - describe one stream's location, media type and per-stream HTTP context
/// - expose enough information for a planner or adapter to schedule it
///
/// It does not:
///
/// - represent a whole playable source
/// - open connections or fetch data
/// - track runtime state
///
/// Those belong to:
///
/// - MediaSource
/// - SourceService
/// - PlayerAdapter
abstract class MediaTrack implements Built<MediaTrack, MediaTrackBuilder> {
  /// Builds a track from a [updates] callback — the codegen entry.
  factory MediaTrack([void Function(MediaTrackBuilder)? updates]) = _$MediaTrack;

  /// Creates a media track.
  ///
  /// Every field except [uri] and [kind] is optional; a track with only
  /// those two is still valid — a caller that discovers URLs before it
  /// knows the codec, bitrate or MIME type is the normal case.
  factory MediaTrack.of({
    required Uri uri,
    required MediaTrackType kind,
    SourceHeaders? headers,
    String? mimeType,
    String? codec,
    int? bitrate,
    String? language,
    Duration? startOffset,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return MediaTrack(
      (builder) => builder
        ..uri = uri
        ..kind = kind
        ..headers = headers
        ..mimeType = mimeType
        ..codec = codec
        ..bitrate = bitrate
        ..language = language
        ..startOffset = startOffset
        ..metadata = metadata,
    );
  }

  MediaTrack._();

  /// An unset metadata bag stays empty rather than null; every other
  /// optional field is genuinely absent until a provider states it.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(MediaTrackBuilder builder) => builder..metadata = const <String, Object?>{};

  /// Location of this track's stream.
  ///
  /// Typically an `https` URL for DASH and HLS essence streams, or a
  /// `file` URI for a local asset. The scheme is intentionally not
  /// duplicated here; derive it via [protocol].
  Uri get uri;

  /// What kind of stream this track carries.
  ///
  /// Distinct from [mimeType]: `kind` classifies the essence for
  /// grouping (which list of a composite source this track belongs
  /// to), while `mimeType` describes the container encoding.
  MediaTrackType get kind;

  /// Optional HTTP or transport request headers.
  ///
  /// Sites like Bilibili gate DASH segments on `Referer`, `User-Agent`
  /// and `Cookie`; without carrying them per-track a downstream
  /// adapter would have no way to reproduce the request that produced
  /// the URL in the first place.
  SourceHeaders? get headers;

  /// Optional MIME type, for example `video/mp4` or `audio/mp4`.
  String? get mimeType;

  /// Optional codec identifier.
  ///
  /// Uses RFC 6381 codec strings, for example `avc1.640028`,
  /// `hev1.2.4.L153.B0` or `av01.0.08M.08`. Callers that need a
  /// family-level test should read [codecFamily] instead of parsing
  /// the raw string.
  String? get codec;

  /// Optional bitrate in bits per second.
  ///
  /// Mirrors the value advertised by the upstream manifest or API so a
  /// planner can rank tracks by bandwidth without re-fetching them.
  int? get bitrate;

  /// Optional BCP-47 language tag, e.g. `zh-CN`, `en`, `und`.
  ///
  /// Meaningful for audio and subtitle tracks; usually absent for the
  /// single video essence of a DASH stream.
  String? get language;

  /// Presentation start of this track relative to the timeline it belongs to.
  ///
  /// DASH representations do not always begin at zero — the audio
  /// period can trail the video period by a few frames. Adapters that
  /// merge essence streams must apply this offset to keep the
  /// presentation synchronized.
  Duration? get startOffset;

  /// Additional track-specific metadata.
  ///
  /// Values are opaque to media_core and are meant for the provider
  /// that produced the track (for example a Bilibili quality code or
  /// an HDR flag). Keys are documented by the producing provider, not
  /// by media_core.
  Map<String, Object?> get metadata;

  /// Whether the track carries request headers.
  bool get hasHeaders => headers != null && headers!.isNotEmpty;

  /// Whether the track carries additional metadata.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether the track declares a codec string.
  bool get hasCodec => codec != null && codec!.trim().isNotEmpty;

  /// Whether the track declares a language.
  bool get hasLanguage => language != null && language!.trim().isNotEmpty;

  /// Whether the track declares a non-zero presentation start offset.
  bool get hasStartOffset => startOffset != null && startOffset != Duration.zero;

  /// Protocol inferred from [uri].
  ///
  /// Delegates to [SourceProtocol.fromScheme], so an unrecognised
  /// scheme returns [SourceProtocol.unknown] instead of throwing.
  SourceProtocol get protocol => SourceProtocol.fromScheme(uri.scheme);

  /// Container format inferred from the URI path's file extension.
  ///
  /// Delegates to [SourceFormat.fromUri]. A track that ends in a query
  /// string or has no extension reports [SourceFormat.unknown]; this is
  /// a heuristic and never a substitute for inspecting the stream.
  SourceFormat get format => SourceFormat.fromUri(uri);

  /// Media type equivalent to [kind], expressed at the source level.
  ///
  /// Bridges [MediaTrackType] into the vocabulary the rest of the
  /// source layer uses, so a single-track progressive source can fill
  /// `PlayerSource.mediaType` without a separate hint.
  SourceMediaType get mediaType {
    switch (kind) {
      case MediaTrackType.video:
        return SourceMediaType.video;
      case MediaTrackType.audio:
        return SourceMediaType.audio;
      case MediaTrackType.subtitle:
        return SourceMediaType.subtitle;
    }
  }

  /// The first segment of a RFC 6381 [codec] string, e.g. `avc1`, `hev1`,
  /// `av01`, `mp4a`.
  ///
  /// Returns `null` when [codec] is not declared.
  String? get codecFamily {
    final raw = codec;
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final dot = trimmed.indexOf('.');
    return dot <= 0 ? trimmed : trimmed.substring(0, dot);
  }

  /// Returns a metadata value.
  Object? metadataValue(String key) => metadata[key];

  /// Whether a metadata key exists.
  bool hasMetadataKey(String key) => metadata.containsKey(key);
}
