import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';
import 'package:media_core/src/source/types/source_format.dart';
import 'package:media_core/src/source/types/source_media_type.dart';
import 'package:media_core/src/source/types/source_protocol.dart';
import 'package:media_core/src/source/types/source_type.dart';

part 'player_source.g.dart';

/// Describes a playable media source.
///
/// [PlayerSource] represents the identity and access information required
/// to resolve a media source. It is intentionally independent from any
/// player backend or runtime playback state.
///
/// [PlayerSource] does not:
///
/// - open connections
/// - resolve source URLs
/// - inspect media streams
/// - create player instances
/// - track playback state
/// - perform recovery or fallback
///
/// Source resolution and inspection belong to the source layer, while
/// backend-specific playback belongs to adapters.
abstract class PlayerSource implements Built<PlayerSource, PlayerSourceBuilder> {
  /// Builds PlayerSource from a [updates] callback — the codegen entry.
  factory PlayerSource([void Function(PlayerSourceBuilder)? updates]) = _$PlayerSource;

  /// Creates a media source, replacing only the fields named.
  ///
  /// A field left out keeps the value written in [_initialize], which is the
  /// unknown-everything default the original constructor spelled out.
  factory PlayerSource.of({
    required SourceId id,
    required Uri uri,
    SourceType? type,
    SourceProtocol? protocol,
    SourceMediaType? mediaType,
    SourceFormat? format,
    SourceHeaders? headers,
    String? title,
    Map<String, Object?>? metadata,
    DateTime? createdAt,
  }) {
    return PlayerSource((builder) {
      builder
        ..id = id
        ..uri = uri
        ..headers = headers
        ..title = title
        ..createdAt = createdAt;

      if (type != null) {
        builder.type = type;
      }
      if (protocol != null) {
        builder.protocol = protocol;
      }
      if (mediaType != null) {
        builder.mediaType = mediaType;
      }
      if (format != null) {
        builder.format = format;
      }
      if (metadata != null) {
        builder.metadata = metadata;
      }
    });
  }

  /// Creates an unknown source.
  factory PlayerSource.unknown() {
    return PlayerSource.of(id: SourceId.unknown(), uri: Uri());
  }

  PlayerSource._();

  /// A source straight from a manifest usually knows only where it is; every
  /// other classification is something a resolver or inspector adds later, so
  /// the unset fields say "unknown" rather than staying absent.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerSourceBuilder builder) => builder
    ..type = SourceType.unknown
    ..protocol = SourceProtocol.unknown
    ..mediaType = SourceMediaType.unknown
    ..format = SourceFormat.unknown
    ..metadata = const <String, Object?>{};

  /// Unique identifier of this source.
  SourceId get id;

  /// URI used to access the source.
  Uri get uri;

  /// General source category.
  SourceType get type;

  /// Protocol used to access the source.
  SourceProtocol get protocol;

  /// Known media content type.
  ///
  /// This is a source-level hint and may remain [SourceMediaType.unknown]
  /// until the source is inspected.
  SourceMediaType get mediaType;

  /// Known media format.
  ///
  /// This is a source-level hint and may remain [SourceFormat.unknown] until
  /// the source is inspected.
  SourceFormat get format;

  /// Optional HTTP or transport request headers.
  SourceHeaders? get headers;

  /// Optional human-readable source title.
  String? get title;

  /// Additional source-specific metadata.
  Map<String, Object?> get metadata;

  /// Optional source creation timestamp.
  DateTime? get createdAt;

  /// Creates a copy with the specified fields replaced.
  ///
  /// A null argument keeps the current value: a resolver that had nothing to
  /// say about a field must not erase what the source already knew.
  PlayerSource copyWith({
    SourceId? id,
    Uri? uri,
    SourceType? type,
    SourceProtocol? protocol,
    SourceMediaType? mediaType,
    SourceFormat? format,
    SourceHeaders? headers,
    String? title,
    Map<String, Object?>? metadata,
    DateTime? createdAt,
  }) {
    return rebuild((builder) {
      if (id != null) {
        builder.id = id;
      }
      if (uri != null) {
        builder.uri = uri;
      }
      if (type != null) {
        builder.type = type;
      }
      if (protocol != null) {
        builder.protocol = protocol;
      }
      if (mediaType != null) {
        builder.mediaType = mediaType;
      }
      if (format != null) {
        builder.format = format;
      }
      if (headers != null) {
        builder.headers = headers;
      }
      if (title != null) {
        builder.title = title;
      }
      if (metadata != null) {
        builder.metadata = metadata;
      }
      if (createdAt != null) {
        builder.createdAt = createdAt;
      }
    });
  }
}

/// Extensions for [PlayerSource].
extension PlayerSourceExtension on PlayerSource {
  /// Whether the source has a non-empty URI.
  bool get hasUri => uri.toString().trim().isNotEmpty;

  /// Whether the source has a usable source identifier.
  bool get hasId => id != SourceId.unknown();

  /// Whether the source has a title.
  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  /// Whether the source contains request headers.
  bool get hasHeaders => headers != null;

  /// Whether the source contains additional metadata.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether this source represents a live source according to its type.
  ///
  /// This is based only on source information and should not be treated
  /// as authoritative media inspection data.
  bool get isLive => type == SourceType.live;

  /// Whether this source uses HTTP.
  bool get isHttp {
    return protocol == SourceProtocol.http || protocol == SourceProtocol.https;
  }

  /// Whether this source uses a file URI.
  bool get isFile => protocol == SourceProtocol.file;

  /// Whether this source is an application asset.
  bool get isAsset => protocol == SourceProtocol.asset;

  /// Whether this source uses HLS.
  bool get isHls => protocol == SourceProtocol.hls;

  /// Whether this source uses DASH.
  bool get isDash => protocol == SourceProtocol.dash;

  /// Whether this source uses RTMP.
  bool get isRtmp => protocol == SourceProtocol.rtmp;

  /// Whether this source uses RTSP.
  bool get isRtsp => protocol == SourceProtocol.rtsp;

  /// Whether this source uses WebRTC.
  bool get isWebRtc => protocol == SourceProtocol.webrtc;

  /// Whether this source uses UDP.
  bool get isUdp => protocol == SourceProtocol.udp;

  /// Whether this source uses a custom protocol.
  bool get isCustom => protocol == SourceProtocol.custom;

  /// Whether this source is network-based.
  ///
  /// This only describes the known protocol. A custom source may still
  /// perform network access and therefore is intentionally not classified
  /// as network-based here.
  bool get isNetworkSource {
    switch (protocol) {
      case SourceProtocol.http:
      case SourceProtocol.https:
      case SourceProtocol.hls:
      case SourceProtocol.dash:
      case SourceProtocol.rtmp:
      case SourceProtocol.rtsp:
      case SourceProtocol.webrtc:
      case SourceProtocol.udp:
        return true;

      case SourceProtocol.file:
      case SourceProtocol.asset:
      case SourceProtocol.unknown:
      case SourceProtocol.custom:
        return false;
    }
  }

  /// Whether this source is a local source.
  bool get isLocalSource {
    return isFile || isAsset;
  }

  /// Whether the source has enough information to be resolved.
  ///
  /// This does not guarantee that the source actually exists or can be
  /// opened. Actual validation belongs to the source resolver.
  bool get isValid {
    return hasId && hasUri;
  }

  /// Returns a metadata value.
  Object? metadataValue(String key) => metadata[key];

  /// Whether a metadata key exists.
  bool hasMetadataKey(String key) => metadata.containsKey(key);
}
