import 'source_type.dart';
import 'source_format.dart';
import 'source_headers.dart';
import 'source_protocol.dart';
import 'source_media_type.dart';
import '../identity/source_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_source.freezed.dart';

/// Represents a playable media source.
///
/// A [PlayerSource] describes where media content
/// comes from and how it should be accessed.
///
/// Responsibilities:
///
/// - identify media source
/// - describe source protocol
/// - describe media format
/// - provide request metadata
///
/// It does not:
///
/// - open connections
/// - resolve URLs
/// - inspect media streams
/// - create players
///
/// Those belong to:
///
/// - [SourceResolver]
/// - [SourceInspector]
/// - player adapters
@freezed
abstract class PlayerSource with _$PlayerSource {
  /// Creates a media source.
  const factory PlayerSource({
    /// Unique source identifier.
    required SourceId id,

    /// Source URI.
    required Uri uri,

    /// Source type.
    @Default(SourceType.unknown) SourceType type,

    /// Network protocol.
    @Default(SourceProtocol.unknown) SourceProtocol protocol,

    /// Media content type.
    @Default(SourceMediaType.unknown) SourceMediaType mediaType,

    /// Media format.
    @Default(SourceFormat.unknown) SourceFormat format,

    /// HTTP/request headers.
    SourceHeaders? headers,

    /// Optional source title.
    String? title,

    /// Optional source metadata.
    Map<String, Object?>? metadata,

    /// Whether this source supports seeking.
    @Default(false) bool seekable,

    /// Whether this source is live.
    @Default(false) bool live,

    /// Creation timestamp.
    DateTime? createdAt,
  }) = _PlayerSource;

  /// Creates an unknown source.
  factory PlayerSource.unknown() {
    return PlayerSource(id: SourceId.unknown(), uri: Uri());
  }
}

/// Extensions for [PlayerSource].
extension PlayerSourceExtension on PlayerSource {
  /// Whether this source has a valid URI.
  bool get hasUri {
    return uri.toString().isNotEmpty;
  }

  /// Whether this is a live source.
  bool get isLive {
    return live;
  }

  /// Whether this source contains headers.
  bool get hasHeaders {
    return headers != null;
  }

  /// Whether this source is network based.
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
}
