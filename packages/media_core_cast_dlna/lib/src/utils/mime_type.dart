/// MIME types this package serves or advertises for media resources.
abstract final class MimeType {
  /// Guesses the MIME type from a file path or URL extension.
  ///
  /// Returns `application/octet-stream` rather than null when nothing
  /// matches: a renderer sniffs an octet-stream, but a null MIME in a
  /// DIDL `res` line makes some firmwares refuse the item outright.
  static String forPath(String path) {
    final lower = path.toLowerCase();
    final withoutQuery = lower.contains('?') ? lower.split('?').first : lower;
    final dot = withoutQuery.lastIndexOf('.');
    if (dot < 0) {
      return 'application/octet-stream';
    }
    return _byExtension[withoutQuery.substring(dot + 1)] ?? 'application/octet-stream';
  }

  static const Map<String, String> _byExtension = <String, String>{
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'ts': 'video/mp2t',
    'm2ts': 'video/mp2t',
    'flv': 'video/x-flv',
    'wmv': 'video/x-ms-wmv',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'ogg': 'audio/ogg',
    'opus': 'audio/opus',
    'wav': 'audio/wav',
    'wma': 'audio/x-ms-wma',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'm3u8': 'application/vnd.apple.mpegurl',
  };
}
