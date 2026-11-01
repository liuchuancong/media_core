import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';

/// Builds DIDL-Lite metadata for `SetAVTransportURI` (§16.6).
///
/// A DLNA renderer is given two things: the URL, and a DIDL-Lite
/// document describing it. Most stock TVs read only `res` (the URL,
/// again, this time with `protocolInfo` so the device can decide
/// whether it can play it) and `dc:title`; everything else here is
/// what a richer renderer uses for its library UI.
abstract final class DidlMetadata {
  /// Builds the item element.
  ///
  /// [url] is the source URL for MIME guessing; [resourceUrl], when
  /// given, is what the `res` element advertises (a media-server
  /// rewrite of a local file) — the local path never reaches the
  /// device. [objectClass] defaults to the derived
  /// `object.item.<kind>` class.
  static String build({
    required String title,
    required String url,
    required String mimeType,
    DlnaMediaType mediaType = DlnaMediaType.unknown,
    String? objectClass,
    String? creator,
    Uri? artwork,
    String? resourceUrl,
    String objectId = '0',
    String parentID = '-1',
    bool restricted = true,
  }) {
    final resUrl = resourceUrl ?? url;
    final resolvedClass = objectClass ?? 'object.item.${mediaType.objectClassName}';
    // protocolInfo follows `http-get:{mime}:{dlna-profile}`. The
    // profile is guessed from the MIME: `*` is legal but many TV
    // firmwares will refuse a `*` profile they can't match to a
    // decoder, while `DLNA.ORG_PN=MP3`/`AVI`/none is a hint they do
    // understand. An unknown MIME still emits a usable `*` line.
    final profile = _profileFor(mimeType);
    final protocol = 'http-get:$mimeType:${profile ?? ''}';

    final builder = StringBuffer()
      ..write('<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" ')
      ..write('xmlns:dc="http://purl.org/dc/elements/1.1/" ')
      ..write('xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">')
      ..write('<item id="${_escape(objectId)}" parentID="${_escape(parentID)}" restricted="$restricted">')
      ..write('<dc:title>${_escape(title)}</dc:title>')
      ..write('<upnp:class>${_escape(resolvedClass)}</upnp:class>');

    if (creator != null && creator.isNotEmpty) {
      builder
        ..write('<dc:creator>${_escape(creator)}</dc:creator>')
        ..write('<upnp:artist>${_escape(creator)}</upnp:artist>');
    }

    if (artwork != null) {
      builder.write('<upnp:albumArtURI>${_escape(artwork.toString())}</upnp:albumArtURI>');
    }

    builder
      ..write('<res protocolInfo="${_escape(protocol)}"')
      ..write(' size="0"')
      ..write(' mimeType="${_escape(mimeType)}"')
      ..write('>${_escape(resUrl)}</res>')
      ..write('</item></DIDL-Lite>');

    return builder.toString();
  }

  /// Guesses the MIME type from a URL extension, falling back to `*`.
  ///
  /// Unlike the media server's guesser this returns `*` rather than
  /// `application/octet-stream`: inside a DIDL `res` line, `*` asks the
  /// device to sniff, while octet-stream makes some firmwares refuse
  /// the item outright.
  static String mimeTypeForUrl(String url) {
    final lower = url.toLowerCase();
    final path = lower.contains('?') ? lower.split('?').first : lower;
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) {
      return 'video/mp4';
    }
    if (path.endsWith('.mkv')) {
      return 'video/x-matroska';
    }
    if (path.endsWith('.webm')) {
      return 'video/webm';
    }
    if (path.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (path.endsWith('.aac') || path.endsWith('.m4a')) {
      return 'audio/aac';
    }
    if (path.endsWith('.ts') || path.endsWith('.m2ts')) {
      return 'video/mp2t';
    }
    if (path.endsWith('.m3u8')) {
      return 'application/vnd.apple.mpegurl';
    }
    return '*';
  }

  static String? _profileFor(String mime) {
    switch (mime) {
      case 'audio/mpeg':
        return 'DLNA.ORG_PN=MP3';
      case 'video/mp4':
        return 'DLNA.ORG_PN=MP4';
      case 'video/mp2t':
        return 'DLNA.ORG_PN=TS';
      default:
        return null;
    }
  }

  static String _escape(String value) {
    return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  }
}
