import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_resource.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';

/// A media item to cast: identity, display metadata and the candidate
/// resources a renderer may be given.
///
/// A media item is not its play URL — [resources] is the list of
/// concrete forms, and selection decides which one the device gets
/// (§8.4: the source URL and the casted resource are different things,
/// e.g. a local file served through the package's media server).
final class DlnaMedia {
  /// Creates a media item.
  const DlnaMedia({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.sourceUri,
    required this.resources,
    this.duration,
    this.mimeType,
  });

  /// A stable identity for this item (the DIDL object id).
  final String id;

  /// The display title.
  final String title;

  /// The content kind.
  final DlnaMediaType mediaType;

  /// The original source (`https://...`, `file:///...`, a local path).
  final Uri sourceUri;

  /// The playable forms this item offers.
  final List<DlnaMediaResource> resources;

  /// The duration, when known up front.
  final Duration? duration;

  /// The item-level MIME type, when known.
  final String? mimeType;
}
