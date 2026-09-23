import 'dart:async';
import 'dart:io' show File;
import 'package:media_core/media_core.dart';
import 'package:video_player/video_player.dart' as vp;

/// [PlayerAdapter] implementation backed by the official
/// Flutter `video_player` plugin.
///
/// A new [VideoPlayerController] is created per source in [open]
/// and disposed in [close] or [dispose].
final class VideoPlayerAdapter implements PlayerAdapter {
  /// Creates the adapter.
  VideoPlayerAdapter({String id = 'video_player'}) : _id = id;

  final String _id;
  final _eventController = StreamController<PlayerAdapterEvent>.broadcast();

  vp.VideoPlayerController? _controller;
  PlayerAdapterContext? _context;

  PlayerState _state = PlayerState.idle;
  PlayerAdapterMetrics _metrics = const PlayerAdapterMetrics();

  bool _initialized = false;
  bool _disposed = false;

  // Previous value snapshot for diffing.
  bool _wasPlaying = false;
  bool _wasBuffering = false;
  Duration _lastPosition = Duration.zero;
  Duration? _lastDuration;
  int? _lastWidth;
  int? _lastHeight;

  @override
  String get id => _id;

  @override
  PlayerAdapterCapabilities get capabilities => defaultCapabilities;

  @override
  PlayerState get state => _state;

  @override
  PlayerAdapterMetrics get metrics => _metrics;

  @override
  Stream<PlayerAdapterEvent> get events => _eventController.stream;

  @override
  bool get initialized => _initialized;

  /// The underlying video_player controller.
  ///
  /// Null before [open] is called or after [close]/[dispose].
  vp.VideoPlayerController? get controller => _controller;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize(PlayerAdapterContext context) async {
    if (_initialized) return;
    _context = context;
    _state = PlayerState.idle.initializingState().readyState();
    _initialized = true;
  }

  @override
  Future<void> open(PlayerSource source) async {
    _requireReady();

    // Dispose any previous controller.
    await _disposeController();

    final vp.VideoPlayerController controller;
    if (source.isFile) {
      controller = vp.VideoPlayerController.file(File(source.uri.toFilePath()));
    } else if (source.isAsset) {
      // asset:///assets/x.mp4 → assets/x.mp4
      final path = source.uri.path.replaceFirst(RegExp(r'^/'), '');
      controller = vp.VideoPlayerController.asset(path);
    } else {
      controller = vp.VideoPlayerController.networkUrl(
        source.uri,
        httpHeaders: source.hasHeaders ? Map<String, String>.from(source.headers!.values) : const {},
      );
    }

    _controller = controller;
    controller.addListener(_onValueChange);

    await controller.initialize();

    _state = _state.withSource(true);
    _emit(PlayerAdapterEvent.opened(source: source.id.value));
    _emit(PlayerAdapterEvent.durationChanged(duration: controller.value.duration));

    final size = controller.value.size;
    if (size.width > 0 && size.height > 0) {
      _emit(PlayerAdapterEvent.videoSizeChanged(width: size.width.toInt(), height: size.height.toInt()));
    }

    // Apply initial config.
    final config = _context?.config ?? const PlayerAdapterConfig();
    if (config.volume != 1.0) {
      await controller.setVolume(config.volume);
    }
    if (config.playbackRate != 1.0) {
      await controller.setPlaybackSpeed(config.playbackRate);
    }
  }

  @override
  Future<void> play() async {
    _requireReady();
    await _controller?.play();
    _state = _state.playingState();
    _emit(const PlayerAdapterEvent.playing());
  }

  @override
  Future<void> pause() async {
    _requireReady();
    await _controller?.pause();
    _state = _state.pausedState();
    _emit(const PlayerAdapterEvent.paused());
  }

  @override
  Future<void> stop() async {
    _requireReady();
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> seek(Duration position) async {
    _requireReady();
    await _controller?.seekTo(position);
    _emit(PlayerAdapterEvent.positionChanged(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireReady();
    await _controller?.setVolume(volume.clamp(0.0, 1.0));
    _emit(PlayerAdapterEvent.volumeChanged(volume: volume.clamp(0.0, 1.0)));
  }

  /// Ignored: the plugin has no video-track control.
  ///
  /// [vp.VideoPlayerController] can only start, pause, seek, set the
  /// speed and set the volume; the video decoder follows the source.
  /// Hiding the surface is a rendering decision the presentation layer
  /// makes, not an audio-only mode, so the adapter declares
  /// [PlayerAdapterCapabilities.supportsAudioOnly] as false and keeps
  /// this method a documented no-op.
  @override
  Future<void> setAudioOnly(bool audioOnly) async {}

  @override
  Future<void> setRate(double rate) async {
    _requireReady();
    await _controller?.setPlaybackSpeed(rate);
    _emit(PlayerAdapterEvent.rateChanged(rate: rate));
  }

  @override
  Future<void> close() async {
    await _disposeController();
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _state = _state.disposingState();

    await _disposeController();

    _state = _state.disposedState();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Value diffing
  // ---------------------------------------------------------------------------

  void _onValueChange() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;

    // Error.
    if (v.errorDescription != null) {
      _state = _state.errorState();
      _emit(PlayerAdapterEvent.error(message: v.errorDescription!));
      return;
    }

    // Playing / Paused.
    if (v.isPlaying != _wasPlaying) {
      _wasPlaying = v.isPlaying;
      if (v.isPlaying) {
        _state = _state.playingState();
        _emit(const PlayerAdapterEvent.playing());
      } else {
        _state = _state.pausedState();
        _emit(const PlayerAdapterEvent.paused());
      }
    }

    // Buffering.
    if (v.isBuffering != _wasBuffering) {
      _wasBuffering = v.isBuffering;
      _state = v.isBuffering ? _state.bufferingState() : (v.isPlaying ? _state.playingState() : _state.pausedState());
      _emit(PlayerAdapterEvent.buffering(buffering: v.isBuffering));
    }

    // Position.
    if (v.position != _lastPosition) {
      _lastPosition = v.position;
      _emit(PlayerAdapterEvent.positionChanged(position: v.position));
    }

    // Duration.
    if (v.duration != _lastDuration) {
      _lastDuration = v.duration;
      _emit(PlayerAdapterEvent.durationChanged(duration: v.duration));
    }

    // Size.
    final w = v.size.width.toInt();
    final h = v.size.height.toInt();
    if (w != _lastWidth || h != _lastHeight) {
      if (w > 0 && h > 0) {
        _lastWidth = w;
        _lastHeight = h;
        _emit(PlayerAdapterEvent.videoSizeChanged(width: w, height: h));
      }
    }

    // Buffered → metrics.
    if (v.buffered.isNotEmpty) {
      final end = v.buffered.last.end;
      _metrics = _metrics.copyWith(buffered: end);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emit(PlayerAdapterEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _requireReady() {
    if (!_initialized || _disposed) {
      throw StateError('VideoPlayerAdapter is not initialized or has been disposed.');
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    if (c == null) return;
    c.removeListener(_onValueChange);
    _controller = null;
    await c.dispose();
  }

  /// Capabilities of this adapter, not of the ExoPlayer/AVPlayer pair
  /// underneath it.
  ///
  /// The backend is the official Flutter `video_player` plugin, whose
  /// whole public surface is [vp.VideoPlayerController] plus the
  /// [vp.VideoPlayerValue] it notifies: position, duration, size,
  /// buffered range, buffering flag, playing flag, speed, volume and
  /// error. Nothing else is reachable — no track list, no effects, no
  /// decoder selection, no repeat mode — so every capability that would
  /// need one of those sub-APIs is declared false here even though the
  /// platform player implements it. An earlier revision of this list
  /// described the Media3 API surface instead of this adapter's, which
  /// promised signals the adapter could never emit.
  ///
  /// Signal emits and their capability flags:
  ///
  /// - [PlayerAdapterEvent.videoSizeChanged] is produced from
  ///   `VideoPlayerValue.size`.
  /// - [PlayerAdapterEvent.buffering] is produced from
  ///   `VideoPlayerValue.isBuffering` without a ratio, because the value
  ///   exposes the buffered *range*, not a completion percentage.
  /// - [PlayerAdapterEvent.videoFrameProgress] is not produced: the
  ///   plugin publishes no per-frame callback, and a position update is
  ///   not proof that a frame was decoded.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    // Core playback.
    //
    // play() / pause() / seekTo() / setPlaybackSpeed() / setVolume() are
    // all part of the controller API. `supportsMuteControl` is false:
    // the plugin can only lower the volume, it has no mute switch.
    // `supportsAudioOnly` is false: there is no video-track control, so
    // the decoder cannot be switched off. See [setAudioOnly].
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: false,
    supportsAudioOnly: false,

    // Video and rendering.
    supportsVideoFrameProgress: false,
    supportsVideoSizeChanged: true,
    supportsVideoReconfig: false,
    supportsHwdecInfo: false,
    supportsVideoFilters: false,
    supportsScreenshot: false,

    // Audio.
    supportsAudioReconfig: false,
    supportsAudioDeviceSelection: false,
    supportsAudioFilters: false,

    // Tracks and subtitles.
    supportsTrackSelection: false,
    supportsSubtitleTrack: false,
    supportsExternalSubtitle: false,

    // Playback state and buffering.
    //
    // The buffered range is copied into metrics, but no ratio is ever
    // published, and the plugin has no repeat mode.
    supportsCacheState: false,
    supportsBufferingProgress: false,
    supportsChapterControl: false,
    supportsLoop: false,

    // Metadata and playlist.
    supportsMetadata: false,
    supportsPlaylist: false,
    supportsPlaylistControl: false,

    // Diagnostics and integration.
    supportsClientMessage: false,
    supportsLogMessages: false,

    // Decoders.
    //
    // Decoding goes through the platform player (MediaCodec on Android,
    // VideoToolbox on iOS); the plugin exposes no decoder choice, so
    // this describes the backend rather than a switch the adapter owns.
    supportsHardwareDecoder: true,
    supportsSoftwareDecoder: true,

    // Presentation.
    supportsPictureInPicture: false,
    supportsFullscreen: true,

    // Source matching.
    //
    // The plugin opens http(s) sources, HLS playlists on both mobile
    // platforms, and local files or assets. DASH, RTSP and RTMP are
    // deliberately absent: they need player modules the plugin does not
    // ship.
    supportedProtocols: {'http', 'https', 'hls', 'file', 'asset'},
    supportedFormats: {'mp4', 'm4v', 'mov', 'ts', 'webm'},
  );
}
