import 'source_type.dart';
import 'source_format.dart';
import 'source_request.dart';
import 'source_location.dart';
import 'source_protocol.dart';
import 'source_descriptor.dart';
import '../identity/source_id.dart';

/// Resolves source requests into source descriptors.
///
/// [SourceResolver] converts a high-level source request
/// into a normalized source description.
///
/// Responsibilities:
///
/// - normalize source location
/// - infer protocol
/// - infer format
/// - create source descriptor
///
/// It does not:
///
/// - open network connections
/// - inspect media streams
/// - detect codecs
/// - create players
///
/// Those belong to:
///
/// - SourceInspector
/// - Network layer
/// - PlayerAdapter
final class SourceResolver {
  /// Creates a source resolver.
  const SourceResolver();

  /// Resolves a source request.
  ///
  /// Throws [ArgumentError] when the request
  /// cannot be resolved.
  Future<SourceDescriptor> resolve(SourceRequest request) async {
    final location = _resolveLocation(request);

    if (!location.isValid) {
      throw ArgumentError('Unable to resolve source location');
    }

    final protocol = _resolveProtocol(location);

    final format = _resolveFormat(location);

    return SourceDescriptor(
      id: request.sourceId ?? SourceId.generate(),
      location: location,
      type: _resolveType(request, protocol),
      protocol: protocol,
      format: format,
      headers: request.headers,
      live: request.live,
      seekable: !request.live,
      attributes: request.attributes,
    );
  }

  /// Resolves source location.
  SourceLocation _resolveLocation(SourceRequest request) {
    if (request.uri != null) {
      return SourceLocation.network(request.uri!);
    }

    return SourceLocation.empty();
  }

  /// Resolves protocol from location.
  SourceProtocol _resolveProtocol(SourceLocation location) {
    final uri = location.uri;

    if (uri == null) {
      return SourceProtocol.unknown;
    }

    switch (uri.scheme.toLowerCase()) {
      case 'http':
        return SourceProtocol.http;

      case 'https':
        return SourceProtocol.https;

      case 'rtmp':
        return SourceProtocol.rtmp;

      case 'rtsp':
        return SourceProtocol.rtsp;

      case 'file':
        return SourceProtocol.file;

      default:
        return SourceProtocol.unknown;
    }
  }

  /// Resolves container format.
  SourceFormat _resolveFormat(SourceLocation location) {
    final uri = location.uri;

    if (uri == null) {
      return SourceFormat.unknown;
    }

    final path = uri.path.toLowerCase();

    if (path.endsWith('.m3u8')) {
      return SourceFormat.hls;
    }

    if (path.endsWith('.mpd')) {
      return SourceFormat.dash;
    }

    if (path.endsWith('.flv')) {
      return SourceFormat.flv;
    }

    if (path.endsWith('.mp4')) {
      return SourceFormat.mp4;
    }

    if (path.endsWith('.ts')) {
      return SourceFormat.ts;
    }

    if (path.endsWith('.mkv')) {
      return SourceFormat.mkv;
    }

    return SourceFormat.unknown;
  }

  /// Resolves source type.
  SourceType _resolveType(SourceRequest request, SourceProtocol protocol) {
    if (request.live) {
      return SourceType.live;
    }

    if (protocol.requiresNetwork) {
      return SourceType.network;
    }

    return SourceType.unknown;
  }
}
