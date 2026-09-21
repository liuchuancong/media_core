import 'dart:async';
import 'dart:ui' show Size;

import 'package:niuma_player/niuma_player.dart' as niuma;
import 'package:media_core/media_core.dart';

/// [PlayerAdapter] implementation backed by niuma_player.
///
/// niuma_player supports two backends: the official video_player
/// (ExoPlayer / AVPlayer) and its own native plugin (Android IJK
/// soft-decoder). This adapter forces the IJK path on Android
/// through [niuma.NiumaPlayerOptions.forceIjkOnAndroid]; on
/// platforms without a native IJK build niuma falls back to its
/// video_player backend automatically.
///
/// Playback state is observed through the controller's
/// [ValueNotifier] API: every [niuma.NiumaPlayerValue] change is
/// diffed (phase / position / duration / size / speed / buffered)
/// and translated into [PlayerAdapterEvent]s and [PlayerState]
/// transitions.
final class IjkPlayerAdapter implements PlayerAdapter {
  /// Creates an ijkplayer adapter.
  ///
  /// [forceIjk] forces the native IJK backend on Android (the
  /// default). Pass false to let niuma pick video_player first.
  IjkPlayerAdapter({String id = 'ijk', bool forceIjk = true})
      : _id = id,
        _forceIjk = forceIjk;

  final String _id;
  final bool _forceIjk;

  niuma.NiumaPlayerController? _controller;
  final _eventController = StreamController<PlayerAdapterEvent>.broadcast();

  PlayerState _state = PlayerState.idle;
  PlayerAdapterMetrics _metrics = const PlayerAdapterMetrics();

  bool _initialized = false;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize(PlayerAdapterContext context) async {
    if (_initialized) return;
    _state = PlayerState.idle.initializingState().readyState();
    _initialized = true;
  }

  @override
  Future<void> open(PlayerSource source) async {
    _requireReady();

    final dataSource = _toDataSource(source);

    if (_controller == null) {
      // The niuma controller is constructed with its source, then
      // initialized. Subsequent opens reuse it through load().
      final controller = niuma.NiumaPlayerController.dataSource(
        dataSource,
        options: niuma.NiumaPlayerOptions(forceIjkOnAndroid: _forceIjk),
      );
      _controller = controller;
      _resetDiff(controller.value);
      controller.addListener(() => _onValueChange(controller));
      await controller.initialize();
    } else {
      await controller.load(niuma.NiumaMediaSource.single(dataSource));
    }

    // Apply settings that arrived before the controller existed.
    if (_pendingVolume != null) {
      final volume = _pendingVolume!;
      _pendingVolume = null;
      await controller.setVolume(volume);
      _emit(PlayerAdapterEvent.volumeChanged(volume: volume));
    }
    if (_pendingRate != null && _pendingRate != 1.0) {
      final rate = _pendingRate!;
      _pendingRate = null;
      await controller.setPlaybackSpeed(rate);
      _emit(PlayerAdapterEvent.rateChanged(rate: rate));
    }

    _state = _state.openingState().withSource(true).readyState();
    _emit(PlayerAdapterEvent.opened(source: source.id.value));

    final value = controller.value;
    _emitDuration(value.duration);
    _emitSize(value.size);
  }

  @override
  Future<void> play() async {
    _requireReady();
    await controller.play();
    _state = _state.playingState();
    _emit(const PlayerAdapterEvent.playing());
  }

  @override
  Future<void> pause() async {
    _requireReady();
    await controller.pause();
    _state = _state.pausedState();
    _emit(const PlayerAdapterEvent.paused());
  }

  @override
  Future<void> stop() async {
    _requireReady();
    // niuma has no stop(); pause + rewind is the equivalent.
    await controller.pause();
    await controller.seekTo(Duration.zero);
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> seek(Duration position) async {
    _requireReady();
    await controller.seekTo(position);
    _emit(PlayerAdapterEvent.positionChanged(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireReady();
    final clamped = volume.clamp(0.0, 1.0);
    final c = _controller;
    if (c == null) {
      // No controller yet (niuma creates it with the source);
      // remember and apply on open.
      _pendingVolume = clamped;
      _emit(PlayerAdapterEvent.volumeChanged(volume: clamped));
      return;
    }
    await c.setVolume(clamped);
    _emit(PlayerAdapterEvent.volumeChanged(volume: clamped));
  }

  @override
  Future<void> setRate(double rate) async {
    _requireReady();
    final c = _controller;
    if (c == null) {
      _pendingRate = rate;
      _emit(PlayerAdapterEvent.rateChanged(rate: rate));
      return;
    }
    await c.setPlaybackSpeed(rate);
    _emit(PlayerAdapterEvent.rateChanged(rate: rate));
  }

  // Settings that arrived before a controller existed.
  double? _pendingVolume;
  double? _pendingRate;

  @override
  Future<void> close() async {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    _state = _state.stoppedState().withSource(false);
    await c.dispose();
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _state = _state.disposingState();

    await close();

    _state = _state.disposedState();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Value diffing (the event bridge)
  // ---------------------------------------------------------------------------

  niuma.PlayerPhase _lastPhase = niuma.PlayerPhase.idle;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  niuma.PlayerError? _lastError;
  double _lastSpeed = 1.0;

  void _resetDiff(niuma.NiumaPlayerValue value) {
    _lastPhase = value.phase;
    _lastPosition = value.position;
    _lastDuration = value.duration;
    _lastError = value.error;
    _lastSpeed = value.playbackSpeed;
  }

  void _onValueChange(niuma.NiumaPlayerController controller) {
    final value = controller.value;

    // Phase transitions drive the semantic state.
    if (value.phase != _lastPhase) {
      _lastPhase = value.phase;
      _onPhaseChange(value.phase, value.error);
    }

    // Position.
    if (value.position != _lastPosition) {
      _lastPosition = value.position;
      _emit(PlayerAdapterEvent.positionChanged(position: value.position));
    }

    // Duration.
    if (value.duration != _lastDuration) {
      _lastDuration = value.duration;
      _emitDuration(value.duration);
    }

    // Playback speed.
    if (value.playbackSpeed != _lastSpeed) {
      _lastSpeed = value.playbackSpeed;
      _emit(PlayerAdapterEvent.rateChanged(rate: value.playbackSpeed));
    }

    // Video size.
    _emitSize(value.size);

    // Error.
    if (value.error != _lastError) {
      _lastError = value.error;
      final error = value.error;
      if (error != null) {
        _state = _state.errorState();
        _emit(PlayerAdapterEvent.error(message: '${error.category.name}: ${error.message}'));
      }
    }

    // Buffered position → metrics.
    if (value.bufferedPosition != _metrics.buffered) {
      _metrics = _metrics.copyWith(buffered: value.bufferedPosition);
    }
  }

  void _onPhaseChange(niuma.PlayerPhase phase, niuma.PlayerError? error) {
    switch (phase) {
      case niuma.PlayerPhase.idle:
        _state = _state.readyState();
      case niuma.PlayerPhase.opening:
        _state = _state.withSource(true).bufferingState();
        _emit(const PlayerAdapterEvent.buffering(buffering: true));
      case niuma.PlayerPhase.ready:
        _state = _state.withSource(true).readyState();
        _emit(const PlayerAdapterEvent.buffering(buffering: false));
      case niuma.PlayerPhase.playing:
        _state = _state.withSource(true).playingState();
        _emit(const PlayerAdapterEvent.buffering(buffering: false));
        _emit(const PlayerAdapterEvent.playing());
      case niuma.PlayerPhase.paused:
        _state = _state.pausedState();
        _emit(const PlayerAdapterEvent.paused());
      case niuma.PlayerPhase.buffering:
        _state = _state.bufferingState();
        _emit(const PlayerAdapterEvent.buffering(buffering: true));
      case niuma.PlayerPhase.ended:
        _state = _state.completedState();
        _emit(const PlayerAdapterEvent.completed());
      case niuma.PlayerPhase.error:
        _state = _state.errorState();
        _emit(
          PlayerAdapterEvent.error(
            message: error == null ? 'IJK player error' : '${error.category.name}: ${error.message}',
          ),
        );
    }
  }

  void _emitDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _emit(PlayerAdapterEvent.durationChanged(duration: duration));
  }

  void _emitSize(Size size) {
    final w = size.width.toInt();
    final h = size.height.toInt();
    if (w <= 0 || h <= 0) return;
    _state = _state.withVideoEnabled(true);
    _emit(PlayerAdapterEvent.videoSizeChanged(width: w, height: h));
  }

  // ---------------------------------------------------------------------------
  // Identity / accessors
  // ---------------------------------------------------------------------------

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

  /// Whether a niuma controller exists (a source has been opened).
  bool get hasController => _controller != null;

  /// The underlying niuma_player controller.
  ///
  /// Throws [StateError] before [open] created it (niuma
  /// constructs its controller together with the source).
  niuma.NiumaPlayerController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('IjkPlayerAdapter has no open source yet.');
    }
    return c;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  niuma.NiumaDataSource _toDataSource(PlayerSource source) {
    if (source.isFile) {
      return niuma.NiumaDataSource.file(source.uri.toFilePath());
    }
    if (source.isAsset) {
      return niuma.NiumaDataSource.asset(source.uri.path.replaceFirst(RegExp(r'^/'), ''));
    }
    return niuma.NiumaDataSource.network(
      source.uri.toString(),
      headers: source.hasHeaders ? Map<String, String>.from(source.headers!.values) : null,
    );
  }

  void _emit(PlayerAdapterEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _requireReady() {
    if (!_initialized || _disposed) {
      throw StateError('IjkPlayerAdapter is not initialized or has been disposed.');
    }
  }

  /// Capabilities advertised by all ijkplayer adapters.
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
    supportedProtocols: {'http', 'https', 'hls', 'rtmp', 'rtsp', 'udp', 'file', 'asset'},
    supportedFormats: {'mp4', 'mkv', 'webm', 'flv', 'm3u8', 'mov', 'avi', 'ts', 'mp3', 'aac', 'flac', 'wav', 'ogg', 'opus', 'h265', 'hevc'},
  );
}
