import 'dart:async';
import 'dart:io' show File;

import 'package:video_player/video_player.dart' as vp;
import 'package:media_core/media_core.dart';

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
      _emit(PlayerAdapterEvent.videoSizeChanged(
        width: size.width.toInt(),
        height: size.height.toInt(),
      ));
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

  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsHardwareDecoder: true,
    supportsSoftwareDecoder: true,
    supportsPictureInPicture: false,
    supportsFullscreen: true,
    supportedProtocols: {'http', 'https', 'hls', 'file', 'asset'},
    supportedFormats: {'mp4', 'webm', 'm3u8', 'mov', 'mkv', 'flv', 'ts'},
  );
}
