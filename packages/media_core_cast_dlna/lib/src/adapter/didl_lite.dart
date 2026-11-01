import 'package:media_core/media_core.dart';

import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/didl_metadata.dart';

/// Builds DIDL-Lite metadata for `SetAVTransportURI` out of a
/// media_core [CastMedia].
///
/// This is the adapter's convenience over the protocol-level
/// `DidlMetadata` builder: MIME guessing, DLNA profile hints, escaping
/// and markup live there; this class only translates [CastMedia] into
/// its arguments.
abstract final class DidlLite {
  /// Builds the object element for [media].
  ///
  /// [resourceUrl] overrides the URL in the `res` element — the URL the
  /// renderer will actually fetch (a media-server rewrite of a local
  /// file), which must never be the local path itself.
  static String build(CastMedia media, {String? resourceUrl}) {
    final mimeType = media.mimeType ?? DidlMetadata.mimeTypeForUrl(media.url);
    return DidlMetadata.build(
      title: media.title,
      url: media.url,
      mimeType: mimeType,
      mediaType: DlnaMediaType.fromMimeType(mimeType),
      objectClass: media.objectClass,
      creator: media.creator,
      artwork: media.artworkUrl,
      resourceUrl: resourceUrl,
    );
  }
}
