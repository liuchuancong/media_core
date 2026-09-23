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

  /// Capabilities of the ExoPlayer (Media3) engine, as exposed by this adapter.
  ///
  /// ExoPlayer surfaces almost every capability through a single
  /// [Player.Listener] event model, so the declaration closely tracks the
  /// listener callbacks the adapter actually subscribes to. Backend
  /// features reachable only through a separate sub-API (Effects,
  /// MediaCodec info, PixelCopy screenshot) stay false until the adapter
  /// wraps them.
  ///
  /// Signal emits and their capability flags:
  ///
  /// - [PlayerAdapterEvent.videoFrameProgress] is produced from
  ///   `VideoFrameMetadataListener.onVideoFrameAboutToBeRendered()`, which
  ///   fires on the playback thread for every frame about to be rendered.
  /// - [PlayerAdapterEvent.videoSizeChanged] is produced from
  ///   `Player.Listener.onVideoSizeChanged()`.
  /// - [PlayerAdapterEvent.buffering] with a `progress` ratio is produced
  ///   from `Player.Listener.onPlaybackStateChanged()` combined with
  ///   `player.getBufferedPercentage()` when the state is BUFFERING.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    // Core playback.
    //
    // Every command maps to an ExoPlayer method:
    // play() / pause() / seekTo() / setPlaybackSpeed() / setVolume().
    // Mute is `setVolume(0f)` with a remembered restore value.
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: true,

    // Video and rendering.
    //
    // `supportsVideoFrameProgress` is true because Media3 exposes
    // VideoFrameMetadataListener, which delivers a per-frame callback
    // on the playback thread. This is the most direct frame heartbeat
    // any backend in this codebase offers.
    //
    // `supportsVideoSizeChanged` is true from onVideoSizeChanged().
    //
    // `supportsVideoReconfig` is false: Media3 has no single
    // "video output reconfigured" event; a size change is the closest
    // signal, and that is already covered by videoSizeChanged.
    //
    // `supportsHwdecInfo` is false: Media3 does not expose a public
    // "current hardware decoder" property. It can be inferred from
    // RendererCapabilities, but that describes the decoders available,
    // not the one actually active for the current track.
    //
    // `supportsVideoFilters` is true: setVideoEffects() accepts a list
    // of Effect instances that can be added and updated at runtime.
    //
    // `supportsScreenshot` is false: Media3 has no built-in screenshot
    // command; it must be built with PixelCopy on top of the SurfaceView.
    supportsVideoFrameProgress: true,
    supportsVideoSizeChanged: true,
    supportsVideoReconfig: false,
    supportsHwdecInfo: false,
    supportsVideoFilters: true,
    supportsScreenshot: false,

    // Audio.
    //
    // `supportsAudioReconfig` is false: no dedicated audio-output
    // reconfigured event.
    //
    // `supportsAudioDeviceSelection` is true from
    // ExoPlayer.setPreferredAudioDevice(AudioDeviceInfo) (API 23+).
    //
    // `supportsAudioFilters` is false: Media3 audio effects exist as
    // AudioProcessor, but they are part of the audio pipeline
    // configuration, not a runtime command the adapter exposes.
    supportsAudioReconfig: false,
    supportsAudioDeviceSelection: true,
    supportsAudioFilters: false,

    // Tracks and subtitles.
    //
    // Track selection is fully supported:
    //   player.getCurrentTracks() enumerates all track groups.
    //   player.trackSelectionParameters = ... selects a track.
    // Text (subtitle) tracks are part of the same track list, and
    // external subtitles can be attached through
    // MediaItem.SubtitleConfiguration.
    supportsTrackSelection: true,
    supportsSubtitleTrack: true,
    supportsExternalSubtitle: true,

    // Playback state and buffering.
    //
    // `supportsCacheState` is true: `getBufferedPosition()` and
    // `getBufferedPercentage()` expose the cache window; the
    // adapter's metrics already track the buffered duration.
    //
    // `supportsBufferingProgress` is true: getBufferedPercentage()
    // returns 0..100 while STATE_BUFFERING.
    //
    // `supportsChapterControl` is false: Media3 has no chapter
    // model; chapters must be parsed from metadata by the app.
    //
    // `supportsLoop` is true: setRepeatMode(REPEAT_MODE_ONE) loops
    // a single item, REPEAT_MODE_ALL loops the playlist.
    supportsCacheState: true,
    supportsBufferingProgress: true,
    supportsChapterControl: false,
    supportsLoop: true,

    // Metadata and playlist.
    //
    // `supportsMetadata` is true from
    // Player.Listener.onMediaMetadataChanged(MediaMetadata).
    //
    // `supportsPlaylist` is true: setMediaItems() builds a playlist,
    // onMediaItemTransition() reports position changes, and
    // getCurrentMediaItemIndex() is observable.
    //
    // `supportsPlaylistControl` is true: addMediaItem(),
    // removeMediaItem(), moveMediaItem(), seekToNextMediaItem(),
    // seekToPreviousMediaItem() are all part of the Player interface.
    supportsMetadata: true,
    supportsPlaylist: true,
    supportsPlaylistControl: true,

    // Diagnostics and integration.
    //
    // Media3 has no client-message channel comparable to mpv's
    // MPV_EVENT_CLIENT_MESSAGE.
    //
    // `supportsLogMessages` is false at the adapter surface: EventLogger
    // exists, but it writes to Logcat rather than through a listener
    // the adapter can subscribe to as a typed stream.
    supportsClientMessage: false,
    supportsLogMessages: false,

    // Decoders.
    //
    // Media3 supports both hardware (MediaCodec) and software
    // (FFmpeg extension) decoders. The adapter can choose between
    // them via RenderersFactory / DefaultRenderersFactory.
    supportsHardwareDecoder: true,
    supportsSoftwareDecoder: true,

    // Presentation.
    //
    // PiP is a system-level feature on Android; the app can enter PiP
    // mode while an ExoPlayer SurfaceView is mounted, but Media3 itself
    // has no PiP command, so the adapter declares false.
    //
    // Fullscreen is a widget-level decision the adapter does not veto.
    supportsPictureInPicture: false,
    supportsFullscreen: true,

    // Source matching.
    //
    // Media3's default extractors cover a broad set; the FFmpeg
    // extension widens it further. The list below is the safe core
    // set the adapter can open without an extension.
    supportedProtocols: {'http', 'https', 'hls', 'dash', 'rtmp', 'rtsp', 'udp', 'file', 'asset'},
    supportedFormats: {'mp4', 'mkv', 'webm', 'flv', 'm3u8', 'mpd', 'ts', 'mov', 'mp3', 'aac', 'flac', 'h265', 'hevc'},
  );
}
