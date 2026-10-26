import 'package:built_value/built_value.dart';

part 'source_metadata.g.dart';

/// Additional metadata attached to a media source.
///
/// [SourceMetadata] contains optional descriptive information about a
/// source: title, author, channel, language, artwork, duration and any
/// custom extras the caller wants to carry along.
///
/// Responsibilities:
///
/// - store source metadata
/// - hand out one immutable metadata object
///
/// It does not:
///
/// - inspect media streams
/// - extract codec information
/// - probe network resources
///
/// Those belong to:
///
/// - SourceInspector
abstract class SourceMetadata implements Built<SourceMetadata, SourceMetadataBuilder> {
  /// Builds metadata from a [updates] callback — the codegen entry.
  factory SourceMetadata([void Function(SourceMetadataBuilder)? updates]) = _$SourceMetadata;

  /// Creates metadata from the fields it describes.
  factory SourceMetadata.of({
    String? title,
    String? description,
    String? author,
    String? channel,
    String? language,
    Uri? artwork,
    Duration? duration,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    return SourceMetadata(
      (builder) => builder
        ..title = title
        ..description = description
        ..author = author
        ..channel = channel
        ..language = language
        ..artwork = artwork
        ..duration = duration
        ..extras = extras,
    );
  }

  SourceMetadata._();

  /// Creates empty metadata.
  factory SourceMetadata.empty() => SourceMetadata.of();

  /// Carries no extras and sets no field unless the caller said so.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SourceMetadataBuilder builder) => builder..extras = const <String, Object?>{};

  /// Display title.
  String? get title;

  /// Description text.
  String? get description;

  /// Author or creator.
  String? get author;

  /// Channel name.
  String? get channel;

  /// Language code, for example `en` or `zh-CN`.
  String? get language;

  /// Thumbnail or poster URL.
  Uri? get artwork;

  /// Duration of the media the metadata describes.
  Duration? get duration;

  /// Additional custom metadata.
  Map<String, Object?> get extras;
}

/// Extensions for [SourceMetadata].
extension SourceMetadataExtension on SourceMetadata {
  /// Whether metadata contains no values.
  bool get isEmpty {
    return title == null &&
        description == null &&
        author == null &&
        channel == null &&
        language == null &&
        artwork == null &&
        duration == null &&
        extras.isEmpty;
  }

  /// Whether metadata has any value.
  bool get isNotEmpty {
    return !isEmpty;
  }

  /// Whether artwork exists.
  bool get hasArtwork {
    return artwork != null;
  }

  /// Whether duration exists.
  bool get hasDuration {
    return duration != null;
  }

  /// Reads one extra by key, the way the map it wraps would be read.
  Object? operator [](String key) {
    return extras[key];
  }

  /// Creates metadata with one extra field set.
  SourceMetadata putExtra(String key, Object? value) {
    return rebuild((builder) => builder..extras = <String, Object?>{...extras, key: value});
  }

  /// Drops one extra field.
  SourceMetadata removeExtra(String key) {
    return rebuild((builder) => builder..extras = (<String, Object?>{...extras}..remove(key)));
  }
}
