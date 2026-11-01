/// One concrete, castable form of a media item.
///
/// A single video may have several resources (an MP4/H.264 rendition, a
/// WebM/VP9 one, an MPEG-TS one); selection picks among them per the
/// device's capabilities. The play URL a renderer is finally given is
/// a resource — it is not necessarily the original source URL (a local
/// file arrives here rewritten through the media server).
final class DlnaMediaResource {
  /// Creates a resource.
  const DlnaMediaResource({
    required this.uri,
    required this.mimeType,
    this.protocolInfo,
    this.size,
    this.duration,
    this.supportsByteRange = true,
  });

  /// The URL the renderer fetches.
  final Uri uri;

  /// The resource MIME type.
  final String mimeType;

  /// The `protocol:network:contentFormat:additionalInfo` string for the
  /// DIDL `res` element, when one should be advertised.
  final String? protocolInfo;

  /// The byte size, when known.
  final int? size;

  /// The playback duration, when known.
  final Duration? duration;

  /// Whether the resource answers HTTP byte ranges (seek support).
  final bool supportsByteRange;
}
