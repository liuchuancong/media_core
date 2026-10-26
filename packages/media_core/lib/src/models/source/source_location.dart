import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/source/source_location_type.dart';

part 'source_location.g.dart';

/// Represents the location of a media source.
///
/// [SourceLocation] abstracts where media data can be accessed from:
/// a network URL, a local file path, an application asset or a custom
/// locator.
///
/// Responsibilities:
///
/// - store source address
/// - describe location type
///
/// It does not:
///
/// - check file existence
/// - open connections
/// - resolve redirects
///
/// Those belong to:
///
/// - SourceResolver
/// - Network layer
abstract class SourceLocation implements Built<SourceLocation, SourceLocationBuilder> {
  /// Builds a location from a [updates] callback — the codegen entry.
  factory SourceLocation([void Function(SourceLocationBuilder)? updates]) = _$SourceLocation;

  /// Creates a location from the fields it describes.
  factory SourceLocation.of({
    Uri? uri,
    String? path,
    String? asset,
    String? custom,
    SourceLocationType type = SourceLocationType.unknown,
  }) {
    return SourceLocation(
      (builder) => builder
        ..uri = uri
        ..path = path
        ..asset = asset
        ..custom = custom
        ..type = type,
    );
  }

  SourceLocation._();

  /// Creates an empty location.
  factory SourceLocation.empty() => SourceLocation.of();

  /// Creates a network location.
  factory SourceLocation.network(Uri uri) => SourceLocation.of(uri: uri, type: SourceLocationType.network);

  /// Creates a local file location.
  factory SourceLocation.file(String path) => SourceLocation.of(path: path, type: SourceLocationType.file);

  /// Creates an asset location.
  factory SourceLocation.asset(String asset) => SourceLocation.of(asset: asset, type: SourceLocationType.asset);

  /// Creates a custom location.
  factory SourceLocation.custom(String value) => SourceLocation.of(custom: value, type: SourceLocationType.custom);

  /// An unset location is of the unknown category rather than invalid.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SourceLocationBuilder builder) => builder..type = SourceLocationType.unknown;

  /// Resource URI.
  Uri? get uri;

  /// Local filesystem path.
  String? get path;

  /// Asset identifier.
  String? get asset;

  /// Custom location value.
  String? get custom;

  /// Location category.
  SourceLocationType get type;
}

/// Extensions for [SourceLocation].
extension SourceLocationExtension on SourceLocation {
  /// Whether the location carries the address its type promises.
  bool get isValid {
    switch (type) {
      case SourceLocationType.network:
        return uri != null;
      case SourceLocationType.file:
        return path != null && path!.isNotEmpty;
      case SourceLocationType.asset:
        return asset != null && asset!.isNotEmpty;
      case SourceLocationType.custom:
        return custom != null && custom!.isNotEmpty;
      case SourceLocationType.unknown:
        return false;
    }
  }

  /// Whether this is network based.
  bool get isNetwork {
    return type == SourceLocationType.network;
  }

  /// Whether this is local.
  bool get isLocal {
    return type == SourceLocationType.file || type == SourceLocationType.asset;
  }

  /// The location as the single string its type is carried by.
  String? get value {
    switch (type) {
      case SourceLocationType.network:
        return uri?.toString();
      case SourceLocationType.file:
        return path;
      case SourceLocationType.asset:
        return asset;
      case SourceLocationType.custom:
        return custom;
      case SourceLocationType.unknown:
        return null;
    }
  }
}
