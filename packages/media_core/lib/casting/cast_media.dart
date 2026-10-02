import 'package:equatable/equatable.dart';

/// The media handed to a render device.
///
/// A renderer needs a URL it can fetch by itself — it does not share
/// this process's sockets or headers — plus enough description to
/// pick a decoder. [headers] is carried because a receiver that can
/// present them (a DLNA device behind a `getAdditionalInfo` flow, a
/// custom app-side receiver) may; a stock TV usually cannot, and the
/// honest consequence — a token-gated URL that the device cannot
/// fetch — is a backend concern, not something to hide here.
final class CastMedia extends Equatable {
  /// Creates the payload for a cast.
  const CastMedia({
    required this.url,
    required this.title,
    this.mimeType,
    this.duration,
    this.objectClass = 'video.item',
    this.artworkUrl,
    this.creator,
    this.headers = const <String, String>{},
    this.attributes = const <String, Object?>{},
  });

  /// The media URL the device must fetch.
  final String url;

  /// Title shown by the receiver.
  final String title;

  /// Content MIME type (`video/mp4`, `audio/mp4`), when known.
  final String? mimeType;

  /// Declared duration; receivers use it for their own progress UI.
  final Duration? duration;

  /// DIDL object class (`video.item`, `audio.item`, ...).
  final String objectClass;

  /// Artwork the receiver may display.
  final Uri? artworkUrl;

  /// Upstream creator/author label.
  final String? creator;

  /// Request headers the receiver may need (Referer, Cookie, UA).
  ///
  /// Best-effort: most stock DLNA renderers ignore them, and a URL
  /// gated by headers a TV cannot send will simply fail to load on
  /// the device. The controller surfaces that failure as a transport
  /// error rather than pretending the cast succeeded.
  final Map<String, String> headers;

  /// Producer attributes; opaque to media_core.
  final Map<String, Object?> attributes;

  @override
  List<Object?> get props => <Object?>[
    url,
    title,
    mimeType,
    duration,
    objectClass,
    artworkUrl,
    creator,
    headers,
    attributes,
  ];
}
