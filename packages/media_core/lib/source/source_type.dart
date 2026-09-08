/// Represents the category of a media source.
///
/// A [SourceType] describes where a media source
/// originates from.
///
/// It does not:
///
/// - resolve source URLs
/// - inspect media content
/// - create playback sessions
///
/// Those belong to:
///
/// - [SourceResolver]
/// - [SourceInspector]
enum SourceType {
  /// Unknown source type.
  unknown,

  /// Local file source.
  ///
  /// Example:
  /// - mp4 file
  /// - local recording
  file,

  /// Network stream source.
  ///
  /// Example:
  /// - HLS
  /// - DASH
  /// - RTMP
  network,

  /// Live streaming source.
  ///
  /// Example:
  /// - live channel
  /// - realtime stream
  live,

  /// Recorded media source.
  recorded,

  /// Asset bundled with application.
  asset,

  /// Memory based source.
  memory,

  /// Custom source type.
  custom,
}

/// Extensions for [SourceType].
extension SourceTypeExtension on SourceType {
  /// Whether this source requires network access.
  bool get requiresNetwork {
    switch (this) {
      case SourceType.network:
      case SourceType.live:
        return true;

      case SourceType.unknown:
      case SourceType.file:
      case SourceType.recorded:
      case SourceType.asset:
      case SourceType.memory:
      case SourceType.custom:
        return false;
    }
  }

  /// Whether this source represents live playback.
  bool get isLive {
    return this == SourceType.live;
  }

  /// Whether this source is local.
  bool get isLocal {
    switch (this) {
      case SourceType.file:
      case SourceType.recorded:
      case SourceType.asset:
      case SourceType.memory:
        return true;

      case SourceType.unknown:
      case SourceType.network:
      case SourceType.live:
      case SourceType.custom:
        return false;
    }
  }

  /// Returns readable name.
  String get displayName {
    switch (this) {
      case SourceType.unknown:
        return 'unknown';

      case SourceType.file:
        return 'file';

      case SourceType.network:
        return 'network';

      case SourceType.live:
        return 'live';

      case SourceType.recorded:
        return 'recorded';

      case SourceType.asset:
        return 'asset';

      case SourceType.memory:
        return 'memory';

      case SourceType.custom:
        return 'custom';
    }
  }
}
