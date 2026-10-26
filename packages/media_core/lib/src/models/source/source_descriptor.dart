import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/models/source/source_location.dart';
import 'package:media_core/src/models/source/source_metadata.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';
import 'package:media_core/src/source/types/source_format.dart';
import 'package:media_core/src/source/types/source_media_type.dart';
import 'package:media_core/src/source/types/source_protocol.dart';
import 'package:media_core/src/source/types/source_type.dart';

part 'source_descriptor.g.dart';

/// Complete description of a media source.
///
/// [SourceDescriptor] holds everything known about a source before
/// playback starts: what it is, where it is reached from, how it is
/// transported and what it asks for in the request.
///
/// It is used between:
///
/// - source resolver
/// - player session
/// - adapter selection
///
/// Responsibilities:
///
/// - describe source identity
/// - describe access information
/// - describe media characteristics
///
/// It does not:
///
/// - open streams
/// - probe media
/// - create players
///
/// Those belong to:
///
/// - SourceResolver
/// - SourceInspector
/// - PlayerAdapter
abstract class SourceDescriptor implements Built<SourceDescriptor, SourceDescriptorBuilder> {
  /// Builds a descriptor from a [updates] callback — the codegen entry.
  factory SourceDescriptor([void Function(SourceDescriptorBuilder)? updates]) = _$SourceDescriptor;

  /// Creates a descriptor from the fields it describes.
  factory SourceDescriptor.of({
    required SourceId id,
    required SourceLocation location,
    SourceType type = SourceType.unknown,
    SourceProtocol protocol = SourceProtocol.unknown,
    SourceMediaType mediaType = SourceMediaType.unknown,
    SourceFormat format = SourceFormat.unknown,
    SourceHeaders? headers,
    SourceMetadata? metadata,
    bool live = false,
    bool seekable = false,
    int priority = 0,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return SourceDescriptor(
      (builder) => builder
        ..id = id
        ..location = location.toBuilder()
        ..type = type
        ..protocol = protocol
        ..mediaType = mediaType
        ..format = format
        ..headers = headers
        ..metadata = metadata?.toBuilder()
        ..live = live
        ..seekable = seekable
        ..priority = priority
        ..attributes = attributes,
    );
  }

  SourceDescriptor._();

  /// Creates a descriptor with nothing known but its identity.
  factory SourceDescriptor.empty() =>
      SourceDescriptor.of(id: SourceId.unknown(), location: SourceLocation.empty());

  /// Unknown is the honest default for every characteristic the caller
  /// has not stated, and an unset attribute bag stays empty rather than null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SourceDescriptorBuilder builder) => builder
    ..type = SourceType.unknown
    ..protocol = SourceProtocol.unknown
    ..mediaType = SourceMediaType.unknown
    ..format = SourceFormat.unknown
    ..live = false
    ..seekable = false
    ..priority = 0
    ..attributes = const <String, Object?>{};

  /// Unique source identifier.
  SourceId get id;

  /// Source location.
  SourceLocation get location;

  /// Source category.
  SourceType get type;

  /// Transport protocol.
  SourceProtocol get protocol;

  /// Media content type.
  SourceMediaType get mediaType;

  /// Container format.
  SourceFormat get format;

  /// Request headers.
  SourceHeaders? get headers;

  /// Source metadata.
  SourceMetadata? get metadata;

  /// Whether the source is live.
  bool get live;

  /// Whether seeking is supported.
  bool get seekable;

  /// Preference among the sources on offer; higher wins.
  int get priority;

  /// Custom attributes.
  Map<String, Object?> get attributes;
}

/// Extensions for [SourceDescriptor].
extension SourceDescriptorExtension on SourceDescriptor {
  /// Whether the source is valid enough for playback.
  bool get isValid {
    return location.isValid;
  }

  /// Whether the source carries request headers.
  bool get hasHeaders {
    return headers != null && headers!.isNotEmpty;
  }

  /// Whether the source carries metadata.
  bool get hasMetadata {
    return metadata != null && metadata!.isNotEmpty;
  }

  /// Whether the source is reached over the network.
  bool get isNetwork {
    return protocol.isNetwork;
  }

  /// Creates a descriptor with a different priority.
  SourceDescriptor withPriority(int value) {
    return rebuild((builder) => builder..priority = value);
  }

  /// Creates a descriptor with one attribute set.
  SourceDescriptor putAttribute(String key, Object? value) {
    return rebuild((builder) => builder..attributes = <String, Object?>{...attributes, key: value});
  }
}
