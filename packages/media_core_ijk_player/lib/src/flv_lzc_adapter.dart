import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flv_lzc/fijkplayer.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';

export 'fijk_player_config.dart' show FijkPlayerConfig, FijkProxyUrlResolver;

final class FlvLzcPlayerAdapter extends PlayerAdapterBase implements PlayerVideo {
  FlvLzcPlayerAdapter({
    super.id = kIjkPlayerBackendId,
    super.capabilities = defaultCapabilities,
    FijkPlayer? player,
    FijkPlayerConfig config = const FijkPlayerConfig(),
  }) : _injectedPlayer = player,
       _config = config;

  final FijkPlayer? _injectedPlayer;
  late final FijkPlayer _player = _injectedPlayer ?? FijkPlayer();

  // ---------------------------------------------------------------------------
  // Configuration — replace wholesale or tweak individual fields
  // ---------------------------------------------------------------------------

  FijkPlayerConfig _config;
  FijkPlayerConfig get config => _config;
  set config(FijkPlayerConfig value) => _config = value;

  // Convenience accessors kept for callers that used the old fields.
  FijkProxyUrlResolver? get proxyUrlResolver => _config.proxyUrlResolver;
  set proxyUrlResolver(FijkProxyUrlResolver? value) => _config = _config.copyWith(proxyUrlResolver: value);

  bool get enableCodec => _config.enableCodec;
  set enableCodec(bool v) => _config = _config.copyWith(enableCodec: v);

  bool get requestAudioFocus => _config.requestAudioFocus;
  set requestAudioFocus(bool v) => _config = _config.copyWith(requestAudioFocus: v);

  bool get requestScreenOn => _config.requestScreenOn;
  set requestScreenOn(bool v) => _config = _config.copyWith(requestScreenOn: v);

  // ---------------------------------------------------------------------------
  // Runtime setOption passthrough for edge cases
  // (mid-playback proxy switch, dynamic header swaps, ...)
  // ---------------------------------------------------------------------------

  Future<void> setPlayerOption(String key, Object value) => _player.setOption(FijkOption.playerCategory, key, value);

  Future<void> setHostOption(String key, Object value) => _player.setOption(FijkOption.hostCategory, key, value);

  Future<void> setFormatOption(String key, Object value) => _player.setOption(FijkOption.formatCategory, key, value);

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  StreamSubscription<Duration>? _positionSubscription;

  bool _sourceBuffering = false;
  bool _privateInput = false;

  Duration _lastDuration = Duration.zero;
  Duration _lastPosition = Duration.zero;

  // ---------------------------------------------------------------------------
  // PlayerVideo
  // ---------------------------------------------------------------------------

  final ValueNotifier<BoxFit> _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);

  BoxFit _videoFit = BoxFit.contain;
  BoxFit get videoFit => _videoFit;

  void setVideoFit(BoxFit fit) {
    if (_videoFit == fit) return;
    _videoFit = fit;
    _fitNotifier.value = fit;
  }

  @override
  bool get available => !audioOnly && !isDisposed;

  @override
  Widget build() {
    return ValueListenableBuilder<BoxFit>(
      valueListenable: _fitNotifier,
      builder: (context, fit, _) {
        return FijkView(
          player: _player,
          fit: FijkHelper.getIjkBoxFit(fit),
          fs: false,
          color: Colors.black,
          panelBuilder: (_, _, _, _, _) => const SizedBox(),
        );
      },
    );
  }

  @override
  Future<void> attach() async {}

  @override
  Future<void> detach() async {}

  // ---------------------------------------------------------------------------
  // Engine contract
  // ---------------------------------------------------------------------------

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {
    _player.addListener(_onPlayerValue);
    _positionSubscription = _player.onCurrentPosUpdate.listen(_onPositionChanged);

    if (audioOnly) {
      await _applyAudioOnly(true);
    }
  }

  @override
  bool get engineReportsOpenFailure => _player.value.state == FijkState.error;

  @override
  Future<void> onOpen(PlayerSource source) async {
    final privateInput = _privateInput;
    _privateInput = false;

    _lastPosition = Duration.zero;
    _lastDuration = Duration.zero;
    _sourceBuffering = false;

    if (_player.state != FijkState.idle) {
      await _player.reset();
    }
    if (isDisposed) return;

    // Resolve the proxy for this open.
    final config = _config;
    final String proxyUrl;
    if (config.proxyUrlResolver != null) {
      proxyUrl = config.proxyUrlResolver!(privateInput: privateInput);
    } else {
      proxyUrl = config.proxyUrl;
    }

    await FijkHelper.applyConfig(
      _player,
      config,
      sourceHeaders: source.hasHeaders ? Map<String, String>.from(source.headers!.values) : null,
      proxyUrl: proxyUrl,
    );
    if (isDisposed) return;

    // A new data source starts a fresh prepare path, so re-assert
    // audio-only.
    if (audioOnly) {
      await _applyAudioOnly(true);
    }
    if (isDisposed) return;

    await _player.setDataSource(source.uri.toString(), autoPlay: false);
    if (isDisposed) return;

    await _player.start();
  }

  @override
  Future<void> onPlay() => _player.start();

  @override
  Future<void> onPause() => _player.pause();

  @override
  Future<void> onStop() async {
    _sourceBuffering = false;
    await _player.stop();
  }

  @override
  Future<void> onSeek(Duration position) => _player.seekTo(position.inMilliseconds);

  @override
  Future<void> onSetVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> onSetRate(double rate) async {
    // soundtouch must land before setSpeed so the engine picks the
    // correct audio pipeline on the first frame.
    final wantsSoundTouch = rate != 1.0;
    if (_config.soundtouch != wantsSoundTouch) {
      await _player.setOption(FijkOption.playerCategory, 'soundtouch', wantsSoundTouch ? 1 : 0);
    }
    await _player.setSpeed(rate);
  }

  @override
  Future<void> onClose() async {
    _sourceBuffering = false;
    _lastPosition = Duration.zero;
    _lastDuration = Duration.zero;
    await _player.reset();
  }

  @override
  Future<void> onDispose() async {
    _player.removeListener(_onPlayerValue);

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _fitNotifier.dispose();

    try {
      await _player.release();
    } catch (_) {
      // Release races surface here on some devices; disposal
      // continues regardless.
    }
  }

  // ---------------------------------------------------------------------------
  // Extensions
  // ---------------------------------------------------------------------------

  /// Marks the next open as an app-owned loopback input so
  /// [proxyUrlResolver] can decide whether to bypass the proxy.
  void setPrivateInput(bool value) => _privateInput = value;

  /// Restricts playback to the audio track through IJKPlayer's
  /// `disable-vid` option: the decoder is switched off, the stream is
  /// not merely hidden.
  @override
  Future<void> onSetAudioOnly(bool audioOnly) => _applyAudioOnly(audioOnly);

  Future<void> _applyAudioOnly(bool audioOnly) async {
    if (isDisposed) return;
    await _player.setOption(FijkOption.playerCategory, 'disable-vid', audioOnly ? 1 : 0);
  }

  /// The underlying FijkPlayer.
  FijkPlayer get fijkPlayer => _player;

  // ---------------------------------------------------------------------------
  // Position progress
  // ---------------------------------------------------------------------------

  void _onPositionChanged(Duration position) {
    if (!acceptsEngineEvents) return;
    if (position == _lastPosition) return;

    _lastPosition = position;
    emitPositionChanged(position);
  }

  // ---------------------------------------------------------------------------
  // Value listener
  // ---------------------------------------------------------------------------

  void _onPlayerValue() {
    if (!acceptsEngineEvents) return;

    final value = _player.value;
    final state = value.state;

    final size = value.size;
    if (size != null) {
      emitVideoSizeChangedIfChanged(size.width.toInt(), size.height.toInt());
    }

    final duration = value.duration;
    if (duration > Duration.zero && duration != _lastDuration) {
      _lastDuration = duration;
      emitDurationChanged(duration);
    }

    final isBufferingState = state == FijkState.asyncPreparing || state == FijkState.prepared;
    if (isBufferingState) {
      if (!_sourceBuffering) {
        _sourceBuffering = true;
        emitBuffering(true);
      }
    } else if (_sourceBuffering) {
      _sourceBuffering = false;
      emitBuffering(false);
    }

    switch (state) {
      case FijkState.started:
        emitPlaying();
      case FijkState.paused:
        emitPaused();
      case FijkState.completed:
      case FijkState.end:
        emitCompleted();
      case FijkState.error:
        final native = value.exception;
        reportEngineError(
          message:
              'fijk error ${native.code}: '
              '${native.message ?? 'native playback failure'}',
        );
      case FijkState.stopped:
      case FijkState.idle:
      case FijkState.initialized:
      case FijkState.asyncPreparing:
      case FijkState.prepared:
        break;
    }
  }

  /// Capabilities of the IJK engine (flv_lzc / fijkplayer), as exposed
  /// by this adapter.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: true,
    supportsAudioOnly: true,
    supportsVideoFrameProgress: false,
    supportsVideoSizeChanged: true,
    supportsVideoReconfig: false,
    supportsHwdecInfo: false,
    supportsVideoFilters: false,
    supportsScreenshot: false,
    supportsAudioReconfig: false,
    supportsAudioDeviceSelection: false,
    supportsAudioFilters: false,
    supportsTrackSelection: false,
    supportsSubtitleTrack: false,
    supportsExternalSubtitle: false,
    supportsCacheState: false,
    supportsBufferingProgress: false,
    supportsChapterControl: false,
    supportsLoop: false,
    supportsMetadata: false,
    supportsPlaylist: false,
    supportsPlaylistControl: false,
    supportsClientMessage: false,
    supportsLogMessages: false,
    supportsHardwareDecoder: true,
    supportsSoftwareDecoder: true,
    supportsPictureInPicture: false,
    supportsFullscreen: true,
    // Source matching.
    supportedProtocols: IjkFormats.supportedProtocols,
    supportedFormats: IjkFormats.supportedFormats,
  );
}
