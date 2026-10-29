import 'dart:io';

/// One media segment of an HLS playlist.
final class HlsSegment {
  /// Creates a segment.
  const HlsSegment({required this.uri, required this.duration});

  /// Where the segment lives, resolved against the playlist's own address.
  final Uri uri;

  /// How much media time it holds.
  final Duration duration;
}

/// A parsed media playlist (`#EXTINF` segments and their container tags).
final class HlsMediaPlaylist {
  /// Creates a parsed media playlist.
  const HlsMediaPlaylist({
    required this.source,
    required this.base,
    required this.segments,
    required this.isLive,
    this.initUri,
  });

  /// The playlist text, kept so the local copy can be rewritten line by line.
  final String source;

  /// The playlist's own address; relative segment URIs resolve against it.
  final Uri base;

  /// The segments in playback order.
  final List<HlsSegment> segments;

  /// The fMP4 initialization segment (`#EXT-X-MAP`), when the playlist has one.
  final Uri? initUri;

  /// Whether the playlist has no `#EXT-X-ENDLIST`: a live stream cannot be
  /// resumed from cached segments because its window moves.
  final bool isLive;

  /// Total media time the segments add up to.
  Duration get duration => Duration(milliseconds: segments.fold(0, (sum, segment) => sum + segment.duration.inMilliseconds));

  /// Reads [text] as a media playlist; null when it carries no segments.
  static HlsMediaPlaylist? parse(String text, Uri base) {
    final segments = <HlsSegment>[];
    Uri? initUri;
    var endList = false;
    Duration? pending;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final value = line.substring('#EXTINF:'.length).split(',').first;
        final seconds = double.tryParse(value);
        if (seconds != null && seconds >= 0) pending = Duration(milliseconds: (seconds * 1000).round());
        continue;
      }
      if (line.startsWith('#EXT-X-MAP:')) {
        final uri = _attribute(line, 'URI');
        if (uri != null && uri.isNotEmpty) initUri = base.resolve(uri);
        continue;
      }
      if (line.startsWith('#EXT-X-ENDLIST')) {
        endList = true;
        continue;
      }
      if (line.startsWith('#')) continue;
      if (pending == null) continue;
      segments.add(HlsSegment(uri: base.resolve(line), duration: pending));
      pending = null;
    }
    if (segments.isEmpty) return null;
    return HlsMediaPlaylist(
      source: text,
      base: base,
      segments: segments,
      isLive: !endList,
      initUri: initUri,
    );
  }

  static String? _attribute(String line, String name) {
    final match = RegExp('$name="([^"]*)"').firstMatch(line);
    return match?.group(1);
  }
}

/// One variant of a master playlist.
final class HlsVariant {
  /// Creates a variant.
  const HlsVariant({required this.uri, required this.bandwidth});

  /// The variant playlist's address.
  final Uri uri;

  /// Its declared peak bandwidth in bits per second.
  final int bandwidth;
}

/// A parsed master playlist (`#EXT-X-STREAM-INF` variants).
final class HlsMasterPlaylist {
  /// Creates a parsed master playlist.
  const HlsMasterPlaylist({required this.variants});

  /// The variants, in playlist order.
  final List<HlsVariant> variants;

  /// Reads [text] as a master playlist; null when it carries no variants.
  static HlsMasterPlaylist? parse(String text, Uri base) {
    final variants = <HlsVariant>[];
    int? pending;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        pending = int.tryParse(match?.group(1) ?? '');
        continue;
      }
      if (line.startsWith('#')) continue;
      if (pending == null) continue;
      variants.add(HlsVariant(uri: base.resolve(line), bandwidth: pending));
      pending = null;
    }
    if (variants.isEmpty) return null;
    return HlsMasterPlaylist(variants: variants);
  }

  /// The variant to download for [qualityId] (`128k`, `320k`, `flac`): the
  /// smallest one that reaches the requested bitrate, or the highest there is.
  HlsVariant choose(String? qualityId) {
    final requested = RegExp(r'(\d+)k').firstMatch(qualityId ?? '');
    final target = requested == null ? null : int.parse(requested.group(1)!) * 1000;
    var best = variants.first;
    for (final variant in variants) {
      if (variant.bandwidth > best.bandwidth) best = variant;
    }
    if (target == null) return best;
    HlsVariant? adequate;
    for (final variant in variants) {
      if (variant.bandwidth < target) continue;
      if (adequate == null || variant.bandwidth < adequate.bandwidth) adequate = variant;
    }
    return adequate ?? best;
  }
}

/// The local playlist a segment cache hands to ffmpeg: every segment URI is
/// replaced by its cached file, the init segment by its own copy, and the
/// remote key/media references made absolute so they still resolve.
String rewriteHlsPlaylist(
  String source, {
  required Uri base,
  required List<String> segmentPaths,
  String? initPath,
}) {
  final out = StringBuffer();
  var index = 0;
  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      out.writeln();
      continue;
    }
    if (line.startsWith('#EXT-X-MAP:')) {
      out.writeln(initPath == null ? _absoluteAttribute(line, base) : _replaceAttribute(line, 'URI', _fileUri(initPath)));
      continue;
    }
    if (line.startsWith('#EXT-X-KEY:') || line.startsWith('#EXT-X-MEDIA:')) {
      out.writeln(_absoluteAttribute(line, base));
      continue;
    }
    if (line.startsWith('#')) {
      out.writeln(line);
      continue;
    }
    if (index < segmentPaths.length) out.writeln(_fileUri(segmentPaths[index++]));
  }
  return out.toString();
}

/// The indexes whose cached file exists and is non-empty, so a resumed
/// download only fetches what it is missing.
Future<Set<int>> completedHlsSegments(String directory, List<HlsSegment> segments) async {
  final done = <int>{};
  for (var index = 0; index < segments.length; index++) {
    final file = File(segmentCachePath(directory, index, segments[index].uri));
    if (!file.existsSync()) continue;
    try {
      if (await file.length() > 0) done.add(index);
    } on Object {
      // An unreadable file is simply refetched.
    }
  }
  return done;
}

/// The cache path of segment [index]; the extension comes from its URI.
String segmentCachePath(String directory, int index, Uri uri) =>
    '$directory/seg_${index.toString().padLeft(5, '0')}.${_extensionOf(uri)}';

/// The cache path of the init segment.
String initCachePath(String directory, Uri uri) => '$directory/init.${_extensionOf(uri)}';

String _extensionOf(Uri uri) {
  final segments = uri.pathSegments;
  final name = segments.isEmpty ? '' : segments.last;
  final dot = name.lastIndexOf('.');
  return dot > 0 && dot < name.length - 1 ? name.substring(dot + 1) : 'ts';
}

String _fileUri(String path) => Uri.file(path).toString();

String _absoluteAttribute(String line, Uri base) {
  final value = RegExp('URI="([^"]*)"').firstMatch(line)?.group(1);
  if (value == null || value.isEmpty) return line;
  return _replaceAttribute(line, 'URI', base.resolve(value).toString());
}

String _replaceAttribute(String line, String name, String value) =>
    line.replaceFirst(RegExp('$name="[^"]*"'), '$name="$value"');
