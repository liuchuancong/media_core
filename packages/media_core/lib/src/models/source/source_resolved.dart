import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';
import 'package:media_core/src/source/model/player_source.dart';
import 'package:media_core/src/source/types/source_format.dart';
import 'package:media_core/src/source/types/source_media_type.dart';
import 'package:media_core/src/source/types/source_protocol.dart';

part 'source_resolved.g.dart';

/// Represents a source after source resolution.
///
/// [ResolvedSource] contains the concrete access information produced by a
/// source resolver. It is suitable for passing to an adapter or player
/// factory.
///
/// Resolution may normalize a URI, determine a protocol, merge request
/// headers, or otherwise transform the original [PlayerSource].
///
/// [ResolvedSource] does not:
///
/// - open the source
/// - inspect media streams
/// - create a player
/// - manage playback
/// - perform recovery or fallback
abstract class ResolvedSource implements Built<ResolvedSource, ResolvedSourceBuilder> {
  /// Builds ResolvedSource from a [updates] callback — the codegen entry.
  factory ResolvedSource([void Function(ResolvedSourceBuilder)? updates]) = _$ResolvedSource;

  /// Creates a resolved source.
  factory ResolvedSource.of({
    required SourceId sourceId,
    required Uri uri,
    SourceProtocol protocol = SourceProtocol.unknown,
    SourceMediaType mediaType = SourceMediaType.unknown,
    SourceFormat format = SourceFormat.unknown,
    SourceHeaders? headers,
    PlayerSource? source,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return ResolvedSource(
      (builder) => builder
        ..sourceId = sourceId
        ..uri = uri
        ..protocol = protocol
        ..mediaType = mediaType
        ..format = format
        ..headers = headers
        ..source = source
        ..metadata = metadata,
    );
  }

  ResolvedSource._();

  /// A resolver that names no protocol, media type or format leaves them
  /// unknown rather than guessing, and carries no metadata until it has some.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ResolvedSourceBuilder builder) => builder
    ..protocol = SourceProtocol.unknown
    ..mediaType = SourceMediaType.unknown
    ..format = SourceFormat.unknown
    ..metadata = const <String, Object?>{};

  /// Identifier of the original source.
  SourceId get sourceId;

  /// Concrete URI to be passed to the backend.
  Uri get uri;

  /// Resolved access protocol.
  SourceProtocol get protocol;

  /// Resolved media type.
  SourceMediaType get mediaType;

  /// Resolved media format.
  SourceFormat get format;

  /// Request headers required to access the resolved source.
  SourceHeaders? get headers;

  /// Original source from which this resolved source was produced.
  PlayerSource? get source;

  /// Additional resolver-specific metadata.
  Map<String, Object?> get metadata;

  /// Whether this source has a non-empty URI.
  bool get hasUri {
    return uri.toString().trim().isNotEmpty;
  }

  /// Whether the source has a valid identifier.
  bool get hasSourceId {
    return sourceId != SourceId.unknown();
  }

  /// Whether request headers are present.
  bool get hasHeaders => headers != null && headers!.isNotEmpty;

  /// Whether resolver metadata is present.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether the source has been resolved sufficiently for an adapter.
  ///
  /// This only validates the resolved descriptor. It does not verify that the
  /// URI is reachable or that the backend can actually open it.
  bool get isValid {
    return hasSourceId && hasUri && protocol.isKnown;
  }

  /// Whether this is a network source.
  bool get isNetworkSource => protocol.isNetwork;

  /// Whether this is a local source.
  bool get isLocalSource => protocol.isLocal;

  /// Whether this is an HTTP-based source.
  bool get isHttpSource => protocol.isHttp;

  /// Whether this is an HLS source.
  bool get isHls => protocol.isHls;

  /// Whether this is a DASH source.
  bool get isDash => protocol.isDash;

  /// Whether this is a file source.
  bool get isFile => protocol.isFile;

  /// Whether this is an application asset.
  bool get isAsset => protocol.isAsset;

  /// Returns a metadata value.
  Object? metadataValue(String key) => metadata[key];

  /// Whether a metadata key exists.
  bool hasMetadataKey(String key) => metadata.containsKey(key);

  /// Returns a new resolved source with the specified header.
  ResolvedSource withHeader(String name, String value) {
    final current = headers ?? SourceHeaders.empty;

    return rebuild((builder) => builder..headers = current.set(name, value));
  }

  /// Returns a new resolved source without the specified header.
  ResolvedSource withoutHeader(String name) {
    final current = headers;

    if (current == null) {
      return this;
    }

    return rebuild((builder) => builder..headers = current.remove(name));
  }
}
