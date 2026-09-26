import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'package:media_core/media_core.dart';
import 'package:media_core_fvp/media_core_fvp.dart';

/// [PlayerAdapter] implementation backed by fvp's `libmdk` player.
///
/// The engine ships a current FFmpeg and prefers the platform hardware decoder
/// (MediaCodec, VideoToolbox, D3D11, VAAPI) with FFmpeg and dav1d as software
/// fallbacks. That covers streams the older bundled engines drop — notably the
/// legacy `codec id 12` HEVC FLV that media_kit's libmpv plays as audio only —
/// so this adapter is what an app registers to recover such a source instead of
/// failing the room.
///
/// The adapter owns its video surface too: it implements [PlayerVideo], so the
/// texture lifecycle (create, release for audio-only, release on close) has one
/// owner.
///
/// One engine instance serves exactly one source. libmdk resolves the render
/// target size once per player and cannot change it afterwards, so every `open`
/// builds a fresh player and releases the previous one.
final class FvpPlayerAdapter extends PlayerAdapterBase implements PlayerVideo {
  /// Creates the adapter.
  FvpPlayerAdapter({
    super.id = kFvpPlayerBackendId,
    PlayerAdapterCapabilities capabilities = defaultCapabilities,
    this.config = const FvpPlayerConfig(),
    FvpVideoConfig videoConfig = const FvpVideoConfig(),
  }) : _videoConfig = videoConfig,
       super(capabilities: capabilities) {
    _fitNotifier.value = videoConfig.fit;
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Open-time engine configuration.
  ///
  /// Read on every open, so a change applies to the next source.
  FvpPlayerConfig config;

  /// Resolver for the engine's proxy URL, or null for a direct connection.
  FvpProxyUrlResolver? get proxyUrlResolver => config.proxyUrlResolver;
  set proxyUrlResolver(FvpProxyUrlResolver? value) => config = config.copyWith(proxyUrlResolver: value);

  /// Whether hardware decoding is preferred.
  bool get enableCodec => config.enableCodec;
  set enableCodec(bool value) => config = config.copyWith(enableCodec: value);

  FvpVideoConfig _videoConfig;

  /// Surface configuration.
  FvpVideoConfig get videoConfig => _videoConfig;
  set videoConfig(FvpVideoConfig value) {
    _videoConfig = value;

    if (_fitNotifier.value != value.fit) {
      _fitNotifier.value = value.fit;
    }
  }

  // ---------------------------------------------------------------------------
  // Engine state
  // ---------------------------------------------------------------------------

  /// The engine serving the current source.
  mdk.Player? _player;

  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  Timer? _positionTimer;

  bool _hasOpened = false;
  bool _openFailed = false;
  bool _privateInput = false;
  bool _softwareDecoderNextOpen = false;
  bool _playingNow = false;
  bool _bufferingNow = false;
  bool _audioOutputSuppressed = false;

  /// Whether the current source is a live (non-seekable) stream.
  bool _liveSource = false;

  double _volume = 1.0;
  double _lastEmittedVolume = -1.0;

  /// The engine's current texture, or null while there is no video output.
  final ValueNotifier<int?> _textureNotifier = ValueNotifier<int?>(null);

  /// Geometry of the current source, from the engine's media info.
  final ValueNotifier<Size?> _sizeNotifier = ValueNotifier<Size?>(null);

  final ValueNotifier<BoxFit> _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);

  BoxFit _videoFit = BoxFit.contain;

  /// How long the adapter waits for the engine to publish video geometry.
  static const Duration _geometryTimeout = Duration(seconds: 10);

  /// Fit as a listenable, so a custom surface can react to [setVideoFit]
  /// without owning the notifier.
  ValueListenable<BoxFit> get fitListenable => _fitNotifier;

  /// The current video texture, or null while there is none.
  ValueListenable<int?> get textureListenable => _textureNotifier;

  /// Geometry of the video in the current source.
  ValueListenable<Size?> get sizeListenable => _sizeNotifier;

  /// Media information of the current source, or null before one opened.
  mdk.MediaInfo? get mediaInfo => _player?.mediaInfo;

  /// Whether the engine still has a source loaded.
  bool get hasSource => _hasOpened;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {
    // The engine is created per source: libmdk fixes the render target size for
    // the lifetime of a player, so reusing one across sources would paint the
    // second stream into the first stream's geometry.
  }

  @override
  Future<void> onBeforeOpen(PlayerSource source) async {
    _liveSource = source.isLive;
    _openFailed = false;
    _playingNow = false;
    _bufferingNow = false;
    _lastEmittedVolume = -1.0;
  }

  @override
  Future<void> onOpen(PlayerSource source) async {
    final player = await _createEngine();
    final url = source.uri.toString();

    player
      ..setProperty('avio.headers', encodeHeaders(source.hasHeaders ? source.headers!.values : const <String, String>{}))
      // FFmpeg ignores an empty `http_proxy`, which is what a loopback relay
      // wants: the relay owns the proxied connection.
      ..setProperty('avio.http_proxy', _proxyUrl())
      ..setActiveTracks(mdk.MediaType.video, audioOnly ? const <int>[] : const <int>[0])
      ..volume = _volume
      ..media = url;

    _hasOpened = true;

    final result = await player.prepare();

    if (isDisposed || _player != player) return;

    if (result < 0) {
      _hasOpened = false;
      _openFailed = true;

      // Reported inside the open window, so the base turns it into a failed
      // open: the controller then escalates to the next line or engine instead
      // of leaving the user with audio and no picture.
      reportEngineError(
        message: 'fvp prepare failed ($result) for $url',
        code: PlayerErrorCode.backendOpenFailed,
      );
      return;
    }

    player.state = mdk.PlaybackState.playing;

    _startPositionPolling(player);
  }

  @override
  Future<void> onAfterOpen(PlayerSource source) async {
    final player = _player;

    if (player == null || isDisposed) return;

    // Outside the open window and not awaited: the texture needs the engine's
    // video geometry, which libmdk publishes through its media-status stream.
    // Blocking the open on it would stall every source whose geometry arrives
    // late, and a missing texture is not an open failure.
    unawaited(_attachTexture(player));

    // A fresh open rebuilds the audio pipeline, so a suppressed output and the
    // audio-only track choice are applied again or sound comes back.
    player
      ..setActiveTracks(mdk.MediaType.video, audioOnly ? const <int>[] : const <int>[0])
      ..volume = _audioOutputSuppressed ? 0.0 : _volume;
  }

  @override
  Future<void> onPlay() async {
    final player = _player;

    if (player == null) return;

    player.state = mdk.PlaybackState.playing;

    _setPlaying(true);
  }

  @override
  Future<void> onPause() async {
    final player = _player;

    if (player == null) return;

    player.state = mdk.PlaybackState.paused;

    _setPlaying(false);
  }

  @override
  Future<void> onStop() async {
    _hasOpened = false;
    _playingNow = false;
    _bufferingNow = false;

    _stopPositionPolling();

    _player?.state = mdk.PlaybackState.stopped;
  }

  @override
  Future<void> onSeek(Duration position) async {
    final player = _player;

    if (player == null) return;

    await player.seek(position: position.inMilliseconds);
  }

  @override
  Future<void> onSetVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _player?.volume = _volume;
  }

  @override
  Future<void> onSetRate(double rate) async {
    // Live streams have no meaningful playback speed; honouring the command
    // would pitch-shift a broadcast.
    if (_liveSource) return;

    _player?.playbackRate = rate;
  }

  @override
  Future<void> onSetAudioOnly(bool audioOnly) async {
    final player = _player;

    if (player == null) return;

    player.setActiveTracks(mdk.MediaType.video, audioOnly ? const <int>[] : const <int>[0]);

    if (audioOnly) {
      await _releaseTexture();
    } else if (_hasOpened) {
      await _attachTexture(player);
    }
  }

  /// Marks the next open as a private input.
  ///
  /// A private input is a loopback source (an app-owned relay): the engine must
  /// not send it through the proxy, so the resolver is asked with
  /// `privateInput: true`. The flag is consumed by the next open.
  void setPrivateInput(bool value) => _privateInput = value;

  /// Marks the next open of the current source to decode in software.
  ///
  /// Used when a hardware decoder failed for the source that is about to be
  /// replayed; the engine then starts its software decoders directly instead of
  /// trying the hardware one again.
  void prepareSoftwareDecoderFallback() => _softwareDecoderNextOpen = true;

  /// Mutes the engine output without touching the stored volume.
  ///
  /// Used around engine switches: the outgoing engine must go silent before the
  /// incoming one has produced a frame.
  Future<void> setAudioOutputSuppressed(bool suppressed) async {
    _audioOutputSuppressed = suppressed;
    _player?.volume = suppressed ? 0.0 : _volume;
  }

  /// Whether audio output is currently suppressed.
  bool get audioOutputSuppressed => _audioOutputSuppressed;

  @override
  Future<void> onClose() async {
    _hasOpened = false;
    _playingNow = false;
    _bufferingNow = false;

    _stopPositionPolling();

    await _releaseTexture();
    await _disposeEngine();
  }

  @override
  Future<void> onDispose() async {
    _stopPositionPolling();

    await _releaseTexture();
    await _disposeEngine();

    _textureNotifier.dispose();
    _sizeNotifier.dispose();
    _fitNotifier.dispose();
  }

  // ---------------------------------------------------------------------------
  // Engine
  // ---------------------------------------------------------------------------

  /// Creates the engine for the source about to open, releasing the previous
  /// one.
  Future<mdk.Player> _createEngine() async {
    await _disposeEngine();

    final player = mdk.Player();

    _player = player;

    final softwareOnly = _softwareDecoderNextOpen;

    _softwareDecoderNextOpen = false;

    player.videoDecoders = config.videoDecoders ?? videoDecoders(hardware: !softwareOnly && config.enableCodec);

    for (final entry in FvpPlayerConfig.defaultLiveProperties.entries) {
      player.setProperty(entry.key, entry.value);
    }

    for (final entry in config.extraProperties.entries) {
      player.setProperty(entry.key, entry.value);
    }

    _bind(player);

    return player;
  }

  Future<void> _disposeEngine() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    _subscriptions.clear();

    final player = _player;

    _player = null;

    if (player == null) return;

    player.volume = 0.0;
    player.dispose();
  }

  /// Video decoder priority for the platform.
  ///
  /// Hardware first with software fallbacks, or software only when the caller
  /// turned hardware decoding off.
  static List<String> videoDecoders({required bool hardware}) {
    if (!hardware) return const <String>['FFmpeg', 'dav1d'];

    if (Platform.isAndroid) return const <String>['AMediaCodec', 'FFmpeg', 'dav1d'];
    if (Platform.isIOS || Platform.isMacOS) return const <String>['VT', 'FFmpeg', 'dav1d'];
    if (Platform.isWindows) return const <String>['MFT:d3d=11', 'D3D11', 'DXVA', 'FFmpeg', 'dav1d'];

    return const <String>['VAAPI', 'VDPAU', 'FFmpeg', 'dav1d'];
  }

  /// `avio.headers` takes CRLF-terminated lines; values that would inject extra
  /// header lines are dropped.
  static String encodeHeaders(Map<String, String> headers) {
    final buffer = StringBuffer();

    headers.forEach((name, value) {
      if (name.isEmpty || RegExp(r'[\r\n:]').hasMatch(name) || RegExp(r'[\r\n]').hasMatch(value)) return;

      buffer.write('$name: $value\r\n');
    });

    return buffer.toString();
  }

  String _proxyUrl() {
    final privateInput = _privateInput;

    _privateInput = false;

    try {
      return config.proxyUrlResolver?.call(privateInput: privateInput) ?? '';
    } catch (_) {
      return '';
    }
  }

  void _bind(mdk.Player player) {
    _subscriptions.add(player.onStateChanged.listen(_onEngineState));

    _subscriptions.add(player.onMediaStatus.listen(_onMediaStatus));

    _subscriptions.add(
      player.onEvent.listen((event) {
        // libmdk reports a failed decoder open as a negative event and then
        // tries the next decoder in the list, so these are informational:
        // MediaStatus.invalid is the terminal signal.
        if (event.error < 0) {
          debugPrint('fvp: ${event.category} ${event.error} ${event.detail}');
        }
      }),
    );
  }

  void _onEngineState(({mdk.PlaybackState oldValue, mdk.PlaybackState newValue}) event) {
    if (!acceptsEngineEvents) return;

    switch (event.newValue) {
      case mdk.PlaybackState.playing:
        _setPlaying(true);
      case mdk.PlaybackState.paused:
        _setPlaying(false);
      case mdk.PlaybackState.stopped:
      case mdk.PlaybackState.notRunning:
      case mdk.PlaybackState.running:
        // A teardown or a state the engine has not settled into yet. The base
        // reports the command-driven stop itself, so this only clears the
        // local flag.
        _playingNow = false;
    }
  }

  /// Publishes a playing/paused transition once.
  ///
  /// Both the command path and the engine stream report the same transition;
  /// consumers must not see two `playing` events for one start.
  void _setPlaying(bool playing) {
    if (_playingNow == playing) return;

    _playingNow = playing;

    if (playing) {
      emitPlaying();
      return;
    }

    if (_hasOpened && !state.stopped && !state.completed) emitPaused();
  }

  void _onMediaStatus(({mdk.MediaStatus oldValue, mdk.MediaStatus newValue}) event) {
    if (!acceptsEngineEvents) return;

    final status = event.newValue;

    if (status.test(mdk.MediaStatus.invalid)) {
      _hasOpened = false;

      // Authoritative for the source being opened; see
      // [engineReportsOpenFailure].
      _openFailed = true;

      reportEngineError(message: 'fvp: invalid or unsupported media');
      return;
    }

    if (status.test(mdk.MediaStatus.end) && !event.oldValue.test(mdk.MediaStatus.end)) {
      _playingNow = false;

      emitCompleted();
      return;
    }

    final player = _player;

    if (player != null && status.test(mdk.MediaStatus.loaded)) {
      // The engine has the media now, so the video geometry for the texture is
      // available even if it was not when the source opened.
      unawaited(_attachTexture(player));
    }

    final buffering =
        status.test(mdk.MediaStatus.buffering) ||
        status.test(mdk.MediaStatus.loading) ||
        status.test(mdk.MediaStatus.stalled);

    if (buffering == _bufferingNow) return;

    _bufferingNow = buffering;

    emitBuffering(buffering, resumePlaying: buffering ? null : _playingNow);
  }

  // ---------------------------------------------------------------------------
  // Position, duration and volume
  // ---------------------------------------------------------------------------

  /// libmdk reports neither position nor duration as a stream, so the adapter
  /// samples them while a source is open.
  ///
  /// The live watchdog derives stalls from position progress: without this
  /// poller a healthy live stream looks stalled as soon as the engine stops
  /// emitting state changes.
  void _startPositionPolling(mdk.Player player) {
    _stopPositionPolling();

    final duration = _durationOf(player);

    if (duration > Duration.zero) emitDurationChanged(duration);

    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (isDisposed || _player != player || !_hasOpened || !_playingNow) return;

      emitPositionChanged(Duration(milliseconds: player.position));

      final buffered = player.buffered();

      if (buffered > 0) {
        updateMetrics((metrics) => metrics.copyWith(buffered: Duration(milliseconds: buffered)));
      }

      final volume = player.volume;

      if (volume != _lastEmittedVolume) {
        _lastEmittedVolume = volume;

        emitVolumeChanged(volume.clamp(0.0, 1.0));
      }
    });
  }

  void _stopPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Media duration, or zero when the engine has none or the source is live.
  ///
  /// libmdk reports no meaningful duration for a live source, and the watchdog
  /// must not mistake that for a bounded file.
  static Duration _durationOf(mdk.Player player) {
    try {
      if (player.isLive) return Duration.zero;

      final milliseconds = player.mediaInfo.duration;

      return milliseconds > 0 ? Duration(milliseconds: milliseconds) : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Whether the engine still reports a failure for the source that [onOpen]
  /// just handed over.
  ///
  /// libmdk answers `prepare()` with a negative result for a source it cannot
  /// open, and reports `MediaStatus.invalid` for one it cannot decode. Both are
  /// authoritative, so the base turns them into a failed open and the
  /// controller can escalate to the next line or engine; without this a broken
  /// source would look like a successful open with no picture.
  @override
  bool get engineReportsOpenFailure => _openFailed;

  // ---------------------------------------------------------------------------
  // PlayerVideo
  // ---------------------------------------------------------------------------

  /// Whether this adapter currently owns a video surface.
  @override
  bool get available => !isDisposed && !audioOnly && _textureNotifier.value != null;

  /// No-op: the texture is owned by the adapter and lives as long as the
  /// source does.
  @override
  Future<void> attach() async {}

  /// Symmetric no-op for [attach].
  ///
  /// Releasing the texture is a source-level decision ([onSetAudioOnly] /
  /// [onClose]), never a layout one: a widget being rebuilt must not throw the
  /// decoded surface away.
  @override
  Future<void> detach() async {}

  /// Builds the video output widget.
  @override
  Widget build() {
    return ValueListenableBuilder<int?>(
      valueListenable: _textureNotifier,
      builder: (context, textureId, _) => ValueListenableBuilder<Size?>(
        valueListenable: _sizeNotifier,
        builder: (context, size, _) => ValueListenableBuilder<BoxFit>(
          valueListenable: _fitNotifier,
          builder: (context, fit, _) => buildSurface(textureId: textureId, size: size, fit: fit),
        ),
      ),
    );
  }

  /// Builds the surface for one frame geometry.
  ///
  /// Exposed so a caller that owns the widget tree can drive it from
  /// [textureListenable], [sizeListenable] and [fitListenable] itself.
  Widget buildSurface({required int? textureId, required Size? size, required BoxFit fit}) {
    final cfg = _videoConfig;

    if (textureId == null || size == null || size.isEmpty) {
      return ColoredBox(color: cfg.fill, child: const SizedBox.expand());
    }

    return ColoredBox(
      color: cfg.fill,
      child: Align(
        alignment: cfg.alignment,
        child: FittedBox(
          fit: fit,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Texture(textureId: textureId, filterQuality: cfg.filterQuality),
          ),
        ),
      ),
    );
  }

  /// The current viewport fit.
  BoxFit get videoFit => _videoFit;

  /// Applies the viewport fit through the surface.
  void setVideoFit(BoxFit fit) {
    if (_fitNotifier.value == fit && _videoConfig.fit == fit) return;

    _videoFit = fit;
    _fitNotifier.value = fit;
    _videoConfig = _videoConfig.copyWith(fit: fit);
  }

  /// Creates the texture for [player] and publishes its geometry.
  ///
  /// Idempotent for one engine instance: the media-status stream and the open
  /// path can both ask for it, and only the first call creates the texture.
  Future<void> _attachTexture(mdk.Player player) async {
    if (isDisposed || _player != player || audioOnly) return;
    if (_textureNotifier.value != null) return;

    // Bounded: a source whose geometry never arrives must not hold the texture
    // path open forever. A later media-status transition retries.
    final size = await player.textureSize.timeout(_geometryTimeout, onTimeout: () => null);

    if (isDisposed || _player != player) return;

    // A source without a video stream: the engine still plays audio, and there
    // is nothing to paint.
    if (size == null || size.width <= 0 || size.height <= 0) return;

    final textureId = await player.updateTexture(
      width: _videoConfig.maxWidth,
      height: _videoConfig.maxHeight,
      tunnel: _videoConfig.tunnel,
      fit: _videoConfig.fitMaxSize,
    );

    if (isDisposed || _player != player) return;

    if (textureId < 0) {
      reportEngineError(message: 'fvp: video texture could not be created');
      return;
    }

    _textureNotifier.value = textureId;
    _sizeNotifier.value = size;

    emitVideoSizeChangedIfChanged(size.width.toInt(), size.height.toInt());
  }

  /// Releases the texture and its geometry.
  ///
  /// Bounded as well: releasing must never block a close or a dispose, and the
  /// engine drops its own texture when the player is disposed anyway.
  Future<void> _releaseTexture() async {
    final player = _player;
    final owned = _textureNotifier.value != null;

    _textureNotifier.value = null;
    _sizeNotifier.value = null;

    if (player == null || !owned) return;

    try {
      await player.updateTexture(width: -1).timeout(_geometryTimeout);
    } on TimeoutException {
      debugPrint('fvp: releasing the video texture timed out');
    }
  }

  // ---------------------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------------------

  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    // Core playback.
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: false,
    supportsAudioOnly: true,

    // Video and rendering.
    //
    // libmdk exposes no decoded-frame callback, so the frame heartbeat stays
    // off: claiming it would arm the watchdog with a signal that can never
    // arrive, and recovery would then tear down healthy streams.
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
    supportsPictureInPicture: false,
    supportsFullscreen: true,

    // Source matching.
    supportedProtocols: FvpFormats.supportedProtocols,
    supportedFormats: FvpFormats.supportedFormats,
  );
}
