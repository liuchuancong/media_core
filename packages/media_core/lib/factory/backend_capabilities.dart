/// Describes backend playback capabilities.
///
/// A backend capability describes what a player backend
/// can support.
///
/// It is used by:
///
/// - BackendSelector
/// - BackendRegistry
/// - FallbackManager
///
/// It does not:
///
/// - create backend instances
/// - manage backend lifecycle
/// - execute playback
///
/// Those belong to:
///
/// - BackendFactory
/// - BackendInstance
/// - Adapter layer
final class BackendCapabilities {
  /// Creates backend capabilities.
  const BackendCapabilities({
    this.live = false,
    this.vod = false,
    this.seek = false,
    this.pause = false,
    this.speedControl = false,

    this.audioOnly = false,

    this.networkStream = false,
    this.localFile = false,

    this.hardwareDecode = false,
    this.softwareDecode = false,

    this.subtitle = false,
    this.audioTrack = false,

    this.rotation = false,
    this.snapshot = false,

    this.platforms = const <String>[],
  });

  /// Supports live streaming.
  final bool live;

  /// Supports video on demand.
  final bool vod;

  /// Supports seeking.
  final bool seek;

  /// Supports pause/resume.
  final bool pause;

  /// Supports playback speed control.
  final bool speedControl;

  /// Supports audio-only playback.
  final bool audioOnly;

  /// Supports network streams.
  final bool networkStream;

  /// Supports local files.
  final bool localFile;

  /// Supports hardware decoding.
  final bool hardwareDecode;

  /// Supports software decoding.
  final bool softwareDecode;

  /// Supports subtitle rendering.
  final bool subtitle;

  /// Supports multiple audio tracks.
  final bool audioTrack;

  /// Supports video rotation.
  final bool rotation;

  /// Supports snapshot capture.
  final bool snapshot;

  /// Supported platforms.
  ///
  /// Example:
  ///
  /// [
  ///   "android",
  ///   "windows",
  ///   "macos"
  /// ]
  final List<String> platforms;

  /// Whether backend can play network live stream.
  bool get canPlayLiveNetwork {
    return live && networkStream;
  }

  /// Whether backend can play local video.
  bool get canPlayLocal {
    return vod && localFile;
  }

  /// Whether backend supports decoding.
  bool get canDecode {
    return hardwareDecode || softwareDecode;
  }

  /// Whether backend is empty capability.
  bool get isEmpty {
    return !live && !vod && !networkStream && !localFile;
  }

  /// Checks whether platform is supported.
  bool supportsPlatform(String platform) {
    if (platforms.isEmpty) {
      return true;
    }

    return platforms.contains(platform);
  }

  /// Creates a copy with changed values.
  BackendCapabilities copyWith({
    bool? live,
    bool? vod,
    bool? seek,
    bool? pause,
    bool? speedControl,

    bool? audioOnly,

    bool? networkStream,
    bool? localFile,

    bool? hardwareDecode,
    bool? softwareDecode,

    bool? subtitle,
    bool? audioTrack,

    bool? rotation,
    bool? snapshot,

    List<String>? platforms,
  }) {
    return BackendCapabilities(
      live: live ?? this.live,

      vod: vod ?? this.vod,

      seek: seek ?? this.seek,

      pause: pause ?? this.pause,

      speedControl: speedControl ?? this.speedControl,

      audioOnly: audioOnly ?? this.audioOnly,

      networkStream: networkStream ?? this.networkStream,

      localFile: localFile ?? this.localFile,

      hardwareDecode: hardwareDecode ?? this.hardwareDecode,

      softwareDecode: softwareDecode ?? this.softwareDecode,

      subtitle: subtitle ?? this.subtitle,

      audioTrack: audioTrack ?? this.audioTrack,

      rotation: rotation ?? this.rotation,

      snapshot: snapshot ?? this.snapshot,

      platforms: platforms ?? this.platforms,
    );
  }

  @override
  String toString() {
    return 'BackendCapabilities('
        'live=$live, '
        'vod=$vod, '
        'seek=$seek, '
        'network=$networkStream, '
        'local=$localFile'
        ')';
  }
}
