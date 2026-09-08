/// Represents the transport protocol of a media source.
///
/// A [SourceProtocol] describes how media data
/// is delivered.
///
/// It does not:
///
/// - open connections
/// - negotiate protocols
/// - validate streams
///
/// Those belong to:
///
/// - [SourceResolver]
/// - player adapters
enum SourceProtocol {
  /// Unknown protocol.
  unknown,

  /// Local file protocol.
  file,

  /// Application asset protocol.
  asset,

  /// HTTP protocol.
  http,

  /// HTTPS protocol.
  https,

  /// HTTP Live Streaming.
  ///
  /// Usually represented by `.m3u8`.
  hls,

  /// Dynamic Adaptive Streaming over HTTP.
  ///
  /// Usually represented by `.mpd`.
  dash,

  /// Real Time Messaging Protocol.
  rtmp,

  /// Real Time Streaming Protocol.
  rtsp,

  /// WebRTC protocol.
  webrtc,

  /// UDP based stream.
  udp,

  /// Custom protocol.
  custom,
}

/// Extensions for [SourceProtocol].
extension SourceProtocolExtension on SourceProtocol {
  /// Whether this protocol requires network access.
  bool get requiresNetwork {
    switch (this) {
      case SourceProtocol.http:
      case SourceProtocol.https:
      case SourceProtocol.hls:
      case SourceProtocol.dash:
      case SourceProtocol.rtmp:
      case SourceProtocol.rtsp:
      case SourceProtocol.webrtc:
      case SourceProtocol.udp:
        return true;

      case SourceProtocol.unknown:
      case SourceProtocol.file:
      case SourceProtocol.asset:
      case SourceProtocol.custom:
        return false;
    }
  }

  /// Whether this protocol is a streaming protocol.
  bool get isStreaming {
    switch (this) {
      case SourceProtocol.hls:
      case SourceProtocol.dash:
      case SourceProtocol.rtmp:
      case SourceProtocol.rtsp:
      case SourceProtocol.webrtc:
      case SourceProtocol.udp:
        return true;

      case SourceProtocol.unknown:
      case SourceProtocol.file:
      case SourceProtocol.asset:
      case SourceProtocol.http:
      case SourceProtocol.https:
      case SourceProtocol.custom:
        return false;
    }
  }

  /// Whether this protocol supports live playback.
  bool get supportsLive {
    switch (this) {
      case SourceProtocol.hls:
      case SourceProtocol.rtmp:
      case SourceProtocol.rtsp:
      case SourceProtocol.webrtc:
      case SourceProtocol.udp:
        return true;

      case SourceProtocol.unknown:
      case SourceProtocol.file:
      case SourceProtocol.asset:
      case SourceProtocol.http:
      case SourceProtocol.https:
      case SourceProtocol.dash:
      case SourceProtocol.custom:
        return false;
    }
  }

  /// Returns readable protocol name.
  String get displayName {
    switch (this) {
      case SourceProtocol.unknown:
        return 'unknown';

      case SourceProtocol.file:
        return 'file';

      case SourceProtocol.asset:
        return 'asset';

      case SourceProtocol.http:
        return 'http';

      case SourceProtocol.https:
        return 'https';

      case SourceProtocol.hls:
        return 'hls';

      case SourceProtocol.dash:
        return 'dash';

      case SourceProtocol.rtmp:
        return 'rtmp';

      case SourceProtocol.rtsp:
        return 'rtsp';

      case SourceProtocol.webrtc:
        return 'webrtc';

      case SourceProtocol.udp:
        return 'udp';

      case SourceProtocol.custom:
        return 'custom';
    }
  }
}
