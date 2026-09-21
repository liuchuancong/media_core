import 'dart:async';

import 'package:media_core/media_core.dart';

/// [PlayerAdapter] implementation backed by a lightweight IJK player.
///
/// This is a generic IJK player implementation that works with
/// the common IJK player patterns found in many Flutter video players.
final class IjkPlayerAdapter implements PlayerAdapter {
  /// Creates an ijkplayer adapter.
  IjkPlayerAdapter({String id = 'ijk'}) : _id = id;

  final String _id;
  final _eventController = StreamController<PlayerAdapterEvent>.broadcast();

  PlayerState _state = PlayerState.idle;
  PlayerAdapterMetrics _metrics = const PlayerAdapterMetrics();

  bool _initialized = false;
  bool _disposed = false;

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

    _state = _state.openingState().withSource(true).readyState();
    _emit(PlayerAdapterEvent.opened(source: source.id.value));
  }

  @override
  Future<void> play() async {
    _requireReady();
    _state = _state.playingState();
    _emit(const PlayerAdapterEvent.playing());
  }

  @override
  Future<void> pause() async {
    _requireReady();
    _state = _state.pausedState();
    _emit(const PlayerAdapterEvent.paused());
  }

  @override
  Future<void> stop() async {
    _requireReady();
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> seek(Duration position) async {
    _requireReady();
    _emit(PlayerAdapterEvent.positionChanged(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireReady();
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped != _lastEmittedVolume) {
      _lastEmittedVolume = clamped;
      _emit(PlayerAdapterEvent.volumeChanged(volume: clamped));
    }
  }

  @override
  Future<void> setRate(double rate) async {
    _requireReady();
    if (rate != _lastEmittedRate) {
      _lastEmittedRate = rate;
      _emit(PlayerAdapterEvent.rateChanged(rate: rate));
    }
  }

  @override
  Future<void> close() async {
    if (!_initialized) return;
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _state = _state.disposingState();

    _state = _state.disposedState();
    if (!_eventController.isClosed) {
      await _eventController.close();
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
      throw StateError('IjkPlayerAdapter is not initialized or has been disposed.');
    }
  }

  // Dedup state.
  double _lastEmittedVolume = -1.0;
  double _lastEmittedRate = -1.0;

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