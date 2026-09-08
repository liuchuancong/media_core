/// Represents the type of media content.
///
/// A [SourceMediaType] describes the primary content
/// contained in a media source.
///
/// It does not:
///
/// - inspect media streams
/// - detect codecs
/// - parse containers
///
/// Those belong to:
///
/// - [SourceInspector]
/// - player adapters
enum SourceMediaType {
  /// Unknown media type.
  unknown,

  /// Video content.
  video,

  /// Audio-only content.
  audio,

  /// Image content.
  image,

  /// Subtitle or caption content.
  subtitle,

  /// Mixed media content.
  ///
  /// Example:
  /// - video + audio
  mixed,

  /// Metadata-only content.
  metadata,

  /// Custom media type.
  custom,
}

/// Extensions for [SourceMediaType].
extension SourceMediaTypeExtension on SourceMediaType {
  /// Whether this type contains video.
  bool get hasVideo {
    switch (this) {
      case SourceMediaType.video:
      case SourceMediaType.mixed:
        return true;

      case SourceMediaType.unknown:
      case SourceMediaType.audio:
      case SourceMediaType.image:
      case SourceMediaType.subtitle:
      case SourceMediaType.metadata:
      case SourceMediaType.custom:
        return false;
    }
  }

  /// Whether this type contains audio.
  bool get hasAudio {
    switch (this) {
      case SourceMediaType.audio:
      case SourceMediaType.video:
      case SourceMediaType.mixed:
        return true;

      case SourceMediaType.unknown:
      case SourceMediaType.image:
      case SourceMediaType.subtitle:
      case SourceMediaType.metadata:
      case SourceMediaType.custom:
        return false;
    }
  }

  /// Whether this type can be played by a media player.
  bool get playable {
    switch (this) {
      case SourceMediaType.video:
      case SourceMediaType.audio:
      case SourceMediaType.mixed:
        return true;

      case SourceMediaType.unknown:
      case SourceMediaType.image:
      case SourceMediaType.subtitle:
      case SourceMediaType.metadata:
      case SourceMediaType.custom:
        return false;
    }
  }

  /// Returns readable media type name.
  String get displayName {
    switch (this) {
      case SourceMediaType.unknown:
        return 'unknown';

      case SourceMediaType.video:
        return 'video';

      case SourceMediaType.audio:
        return 'audio';

      case SourceMediaType.image:
        return 'image';

      case SourceMediaType.subtitle:
        return 'subtitle';

      case SourceMediaType.mixed:
        return 'mixed';

      case SourceMediaType.metadata:
        return 'metadata';

      case SourceMediaType.custom:
        return 'custom';
    }
  }
}
