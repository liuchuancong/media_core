import 'package:built_value/built_value.dart';

part 'platform_network.g.dart';

/// Describes network playback capabilities.
///
/// [PlatformNetwork] represents what network
/// features are available on current platform.
///
/// Responsibilities:
///
/// - supported protocols
/// - network feature flags
/// - connection capability
///
/// It does not:
///
/// - open connections
/// - download media
///
/// Those belong to:
///
/// - NetworkClient
/// - SourceResolver
abstract class PlatformNetwork implements Built<PlatformNetwork, PlatformNetworkBuilder> {
  /// Builds PlatformNetwork from a [updates] callback — the codegen entry.
  factory PlatformNetwork([void Function(PlatformNetworkBuilder)? updates]) = _$PlatformNetwork;

  /// Creates PlatformNetwork from the fields it describes.
  factory PlatformNetwork.of({
    bool enabled = true,
    bool http = true,
    bool https = true,
    bool hls = true,
    bool dash = true,
    bool rtmp = false,
    bool websocket = false,
    bool proxy = true,
    bool tls = true,
    int maxConnections = 6,
  }) {
    return PlatformNetwork(
      (builder) => builder
        ..enabled = enabled
        ..http = http
        ..https = https
        ..hls = hls
        ..dash = dash
        ..rtmp = rtmp
        ..websocket = websocket
        ..proxy = proxy
        ..tls = tls
        ..maxConnections = maxConnections,
    );
  }

  PlatformNetwork._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformNetworkBuilder builder) => builder
    ..enabled = true
    ..http = true
    ..https = true
    ..hls = true
    ..dash = true
    ..rtmp = false
    ..websocket = false
    ..proxy = true
    ..tls = true
    ..maxConnections = 6;

  /// Whether network playback is enabled.
  bool get enabled;

  /// HTTP support.
  bool get http;

  /// HTTPS support.
  bool get https;

  /// HLS support.
  ///
  /// Example:
  ///
  /// - m3u8
  bool get hls;

  /// MPEG-DASH support.
  ///
  /// Example:
  ///
  /// - mpd
  bool get dash;

  /// RTMP support.
  ///
  /// Example:
  ///
  /// - live streaming
  bool get rtmp;

  /// WebSocket support.
  bool get websocket;

  /// Proxy support.
  bool get proxy;

  /// TLS/SSL support.
  bool get tls;

  /// Maximum parallel connections.
  int get maxConnections;

  /// Whether live streaming protocols are supported.
  bool get supportsLiveStream {
    return hls || rtmp || websocket;
  }

  /// Whether secure network is supported.
  bool get supportsSecureConnection {
    return https && tls;
  }

  /// Whether any network playback is possible.
  bool get canPlayback {
    return enabled && (http || https);
  }
}
