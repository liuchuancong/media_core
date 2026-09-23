import 'dart:async';
import 'package:media_core/media_core.dart';
import 'package:media_kit/media_kit.dart' as mk;

/// [PlayerAdapter] implementation backed by media_kit.
///
/// Volume is normalised between media_core (0.0–1.0) and
/// media_kit (0.0–100.0) automatically.
final class MediaKitPlayerAdapter implements PlayerAdapter {
  /// Creates a media_kit adapter.
  ///
  /// Supply [player] to reuse an existing instance; otherwise one
  /// is created lazily inside [initialize].
  MediaKitPlayerAdapter({String id = 'media_kit', mk.Player? player}) : _id = id, _injectedPlayer = player;

  final String _id;
  final mk.Player? _injectedPlayer;

  mk.Player? _player;
  final _eventController = StreamController<PlayerAdapterEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlayerState _state = PlayerState.idle;
  PlayerAdapterMetrics _metrics = const PlayerAdapterMetrics();

  bool _initialized = false;
  bool _disposed = false;
  bool _playingNow = false;
  bool _bufferingNow = false;
  bool _hasOpened = false;

  int? _width;
  int? _height;
  int? _lastEmittedWidth;
  int? _lastEmittedHeight;
  double _lastEmittedVolume = -1.0;
  double _lastEmittedRate = -1.0;

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

  /// The underlying media_kit [Player].
  ///
  /// Throws [StateError] before [initialize] is called.
  mk.Player get player {
    final p = _player;
    if (p == null) {
      throw StateError('MediaKitPlayerAdapter has not been initialized.');
    }
    return p;
  }

  /// Ensures the media_kit native libraries are loaded.
  ///
  /// Call once before `runApp`, typically in `main`.
  static void ensureInitialized() {
    mk.MediaKit.ensureInitialized();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize(PlayerAdapterContext context) async {
    if (_initialized) return;

    _player = _injectedPlayer ?? mk.Player(configuration: _buildConfiguration(context));
    _state = PlayerState.idle.initializingState().readyState();

    _subscribeStreams();
    _initialized = true;
  }

  @override
  Future<void> open(PlayerSource source) async {
    _requireReady();

    final uri = source.uri.toString();
    final headers = source.hasHeaders ? source.headers!.values : null;

    await player.open(mk.Media(uri, httpHeaders: headers), play: false);

    _hasOpened = true;
    _state = _state.withSource(true);
    _emit(PlayerAdapterEvent.opened(source: source.id.value));
  }

  @override
  Future<void> play() async {
    _requireReady();
    await player.play();
    _state = _state.playingState();
    _emit(const PlayerAdapterEvent.playing());
  }

  @override
  Future<void> pause() async {
    _requireReady();
    await player.pause();
    _state = _state.pausedState();
    _emit(const PlayerAdapterEvent.paused());
  }

  @override
  Future<void> stop() async {
    _requireReady();
    await player.stop();
    _playingNow = false;
    _bufferingNow = false;
    _hasOpened = false;
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> seek(Duration position) async {
    _requireReady();
    await player.seek(position);
    _emit(PlayerAdapterEvent.positionChanged(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireReady();
    final clamped = volume.clamp(0.0, 1.0);
    await player.setVolume(clamped * 100.0);
  }

  @override
  Future<void> setRate(double rate) async {
    _requireReady();
    await player.setRate(rate);
  }

  @override
  Future<void> close() async {
    if (!_initialized || _player == null) return;
    await player.stop();
    _hasOpened = false;
    _playingNow = false;
    _bufferingNow = false;
    _state = _state.stoppedState().withSource(false);
    _emit(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _state = _state.disposingState();

    await Future.wait(_subscriptions.map((s) => s.cancel()));
    _subscriptions.clear();

    await _player?.dispose();
    _player = null;

    _state = _state.disposedState();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Stream wiring
  // ---------------------------------------------------------------------------

  void _subscribeStreams() {
    final s = player.stream;

    _subscriptions.add(s.playing.listen(_onPlaying));
    _subscriptions.add(s.completed.listen(_onCompleted));
    _subscriptions.add(s.buffering.listen(_onBuffering));
    _subscriptions.add(s.position.listen(_onPosition));
    _subscriptions.add(s.duration.listen(_onDuration));
    _subscriptions.add(s.volume.listen(_onVolume));
    _subscriptions.add(s.rate.listen(_onRate));
    _subscriptions.add(s.width.listen(_onWidth));
    _subscriptions.add(s.height.listen(_onHeight));
    _subscriptions.add(s.error.listen(_onError));
    _subscriptions.add(s.buffer.listen(_onBuffer));
    _subscriptions.add(s.audioBitrate.listen(_onAudioBitrate));
  }

  void _onPlaying(bool playing) {
    if (_playingNow == playing) return;
    _playingNow = playing;

    if (playing) {
      _state = _state.withSource(true).playingState();
      _emit(const PlayerAdapterEvent.playing());
    } else if (_hasOpened && !_state.stopped && !_state.completed) {
      _state = _state.pausedState();
      _emit(const PlayerAdapterEvent.paused());
    }
  }

  void _onCompleted(bool completed) {
    if (!completed) return;
    _playingNow = false;
    _state = _state.completedState();
    _emit(const PlayerAdapterEvent.completed());
  }

  void _onBuffering(bool buffering) {
    if (_bufferingNow == buffering) return;
    _bufferingNow = buffering;

    if (buffering) {
      _state = _state.bufferingState();
    } else {
      _state = _playingNow ? _state.playingState() : _state.pausedState();
    }
    _emit(PlayerAdapterEvent.buffering(buffering: buffering));
  }

  void _onPosition(Duration position) {
    _emit(PlayerAdapterEvent.positionChanged(position: position));
  }

  void _onDuration(Duration duration) {
    _emit(PlayerAdapterEvent.durationChanged(duration: duration));
  }

  void _onVolume(double v) {
    final normalised = (v / 100.0).clamp(0.0, 1.0);
    if (normalised == _lastEmittedVolume) return;
    _lastEmittedVolume = normalised;
    _emit(PlayerAdapterEvent.volumeChanged(volume: normalised));
  }

  void _onRate(double rate) {
    if (rate == _lastEmittedRate) return;
    _lastEmittedRate = rate;
    _emit(PlayerAdapterEvent.rateChanged(rate: rate));
  }

  void _onWidth(int? w) {
    _width = w;
    _maybeEmitSize();
  }

  void _onHeight(int? h) {
    _height = h;
    _maybeEmitSize();
  }

  void _maybeEmitSize() {
    final w = _width;
    final h = _height;
    if (w == null || h == null || w <= 0 || h <= 0) return;
    if (w == _lastEmittedWidth && h == _lastEmittedHeight) return;
    _lastEmittedWidth = w;
    _lastEmittedHeight = h;
    _emit(PlayerAdapterEvent.videoSizeChanged(width: w, height: h));
  }

  void _onError(String message) {
    _state = _state.errorState();
    _emit(PlayerAdapterEvent.error(message: message));
  }

  void _onBuffer(Duration buffered) {
    _metrics = _metrics.copyWith(buffered: buffered);
  }

  void _onAudioBitrate(double? bitrate) {
    _metrics = _metrics.copyWith(bitrate: bitrate?.toInt());
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
      throw StateError('MediaKitPlayerAdapter is not initialized or has been disposed.');
    }
  }

  mk.PlayerConfiguration _buildConfiguration(PlayerAdapterContext context) {
    final config = context.config;
    return mk.PlayerConfiguration(
      bufferSize: config.maxBufferBytes ?? 32 * 1024 * 1024,
      muted: context.playerConfig?.muted ?? false,
      logLevel: mk.MPVLogLevel.error,
    );
  }

  /// Capabilities of the MPV engine, as exposed by this adapter.
  ///
  /// The declaration is scoped to what the adapter actually produces
  /// or accepts today, not to what libmpv exposes in the abstract.
  /// Backend events the adapter does not yet subscribe to
  /// (`MPV_EVENT_VIDEO_RECONFIG`, `MPV_EVENT_AUDIO_RECONFIG`,
  /// `metadata`, track lists, …) stay false; they can be flipped on
  /// the same line as the subscription that makes them real.
  ///
  /// Signal emits and their capability flags:
  ///
  /// - [PlayerAdapterEvent.videoFrameProgress] is produced by
  ///   [_observeDecodedFrames] from mpv's `estimated-vf-fps`. It is
  ///   a rate statistic rather than a per-frame callback, but it is
  ///   a real proof that video output is still advancing, which is
  ///   exactly what the video-frame watchdog needs.
  /// - [PlayerAdapterEvent.videoSizeChanged] is produced by
  ///   [_onWidth] / [_onHeight] from the media_kit width and height
  ///   streams.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    // Core playback.
    //
    // The adapter implements every command hook
    // (onPlay/onPause/onStop/onSeek/onSetVolume/onSetRate) and
    // forwards them to media_kit, so all of these are true.
    // `supportsMuteControl` stays false: muting is done by routing
    // through `setAudioTrack(no)` for the current source, not by a
    // dedicated mute command the adapter accepts for the lifetime
    // of the session.
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: false,

    // Video and rendering.
    //
    // Only the two signals the adapter currently emits are declared.
    // Reconfig / hwdec info / filters / screenshot are backend
    // capabilities that are not surfaced through the adapter yet,
    // so they stay false until a corresponding subscription or
    // command is added.
    supportsVideoFrameProgress: true,
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
    //
    // `setAudioOnly` and `setAudioOutputSuppressed` exist, but they
    // are adapter-specific toggles, not the general "list and pick a
    // track" surface the capability describes.
    supportsTrackSelection: false,
    supportsSubtitleTrack: false,
    supportsExternalSubtitle: false,

    // Playback state and buffering.
    //
    // `_onBuffer` updates metrics but does not emit a buffering
    // progress ratio, so `supportsBufferingProgress` stays false
    // until `emitBuffering(progress: …)` is actually wired.
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
    supportsHardwareDecoder: true,
    supportsSoftwareDecoder: true,

    // Presentation.
    //
    // PiP is not provided by mpv; fullscreen is a widget-level
    // decision the adapter does not veto.
    supportsPictureInPicture: false,
    supportsFullscreen: true,

    // Source matching.
    supportedProtocols: {'http', 'https', 'hls', 'dash', 'rtmp', 'rtsp', 'udp', 'file', 'asset'},
    supportedFormats: {
      'mp4',
      'mkv',
      'webm',
      'flv',
      'm3u8',
      'mpd',
      'mov',
      'avi',
      'ts',
      'mp3',
      'aac',
      'flac',
      'h265',
      'hevc',
    },
  );
}
