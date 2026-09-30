import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, ValueListenable;

export 'package:media_core_media_kit/src/media_kit_player_config.dart' show MediaKitPlayerConfig, MediaKitProxyUrlResolver;
export 'package:media_core_media_kit/src/media_kit_video_config.dart' show MediaKitVideoConfig, MediaKitVideoControls;

/// [PlayerAdapter] implementation backed by the local media_kit
/// snapshot — the MPV engine.
///
/// This adapter also owns its video surface: it implements
/// [PlayerVideo] directly, so there is exactly one place that knows
/// how the texture is produced.
///
/// **Platform-specific settings:**
///
/// Two switches are meaningful on one platform only, and are ignored
/// everywhere else so a setting that was persisted on one device
/// cannot corrupt the picture on another:
///
/// - the host's own `vo` / `hwdec` picks via `extraProperties` / config —
///   `vo=mediacodec_embed` and `hwdec=mediacodec`, bypassing the
///   SurfaceProducer path.
/// - [MediaKitPlayerConfig.enableRtxVsr] — Windows only. Enables the
///   RTX Video Super Resolution filter through `d3d11vpp`.
///
/// Additionally, macOS unconditionally forces `hwdec=no` because the
/// bundled libmpv's VideoToolbox path is unstable with the Flutter
/// texture surface, and iOS normalisation pins the video output driver
/// to `libmpv` (see [MpvPlatformProfile]).

// Engine configuration lives in the `part` file next to this one:
// `media_kit_player_adapter_engine.dart` (decoder policy, native mpv
// properties). Overrides, stream wiring, the public surface and the
// capability table stay in the class body — the stream handlers call the
// protected `PlayerAdapterBase` emit API, which only the class itself may
// touch.
part 'media_kit_player_adapter_engine.dart';
final class MediaKitPlayerAdapter extends PlayerAdapterBase implements PlayerVideo {
  /// Creates the adapter.
  ///
  /// [config] carries open-time mpv options; [videoConfig] carries
  /// surface options. Both are reachable at any time through the
  /// matching getters / setters.
  ///
  /// [capabilities] is normalised before being handed to the base: see
  /// [_honestCapabilities]. A caller may pass a declaration that claims
  /// video-frame progress on a platform where the observer is never
  /// started, and the base must not report a capability the adapter
  /// cannot honour.
  MediaKitPlayerAdapter({
    super.id = kMediaKitPlayerBackendId,
    PlayerAdapterCapabilities capabilities = defaultCapabilities,
    mk.Player? player,
    this.config = const MediaKitPlayerConfig(),
    MediaKitVideoConfig videoConfig = const MediaKitVideoConfig(),
  }) : _injectedPlayer = player,
       _videoConfig = videoConfig,
       super(capabilities: _honestCapabilities(capabilities)) {
    _fitNotifier.value = videoConfig.fit;
  }

  /// Narrows [capabilities] to what this platform actually implements.
  ///
  /// The decoded-frame heartbeat is Windows-only (see
  /// [_frameProgressSupported]), so on every other platform
  /// `supportsVideoFrameProgress` must be reported as `false`.
  ///
  /// This matters beyond bookkeeping: the live watchdog bundle arms a
  /// frame-stall timer from this flag alone. Reporting `true` where no
  /// heartbeat can ever arrive makes the watchdog declare a stall on a
  /// perfectly healthy stream, and recovery then tears the stream down
  /// and reopens it on every timeout, forever.
  ///
  /// `supportsScreenshot` is narrowed the same way: mpv's `screenshot`
  /// needs the native backend, so the web build must not claim it.
  static PlayerAdapterCapabilities _honestCapabilities(PlayerAdapterCapabilities capabilities) {
    var result = capabilities;

    if (!_frameProgressSupported && result.supportsVideoFrameProgress) {
      result = result.copyWith(supportsVideoFrameProgress: false);
    }

    if (kIsWeb && result.supportsScreenshot) {
      result = result.copyWith(supportsScreenshot: false);
    }

    return result;
  }

  /// Whether this platform starts the decoded-frame observer.
  static bool get _frameProgressSupported => defaultTargetPlatform == TargetPlatform.windows;

  final mk.Player? _injectedPlayer;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Open-time mpv options.
  ///
  /// Assigning a new value takes effect on the next open. Tweak
  /// individual entries through the convenience setters below
  /// (`enableCodec`, `customPlayerOutput`, ...).
  MediaKitPlayerConfig config;

  MediaKitVideoConfig _videoConfig;
  MediaKitVideoConfig get videoConfig => _videoConfig;
  set videoConfig(MediaKitVideoConfig value) {
    _videoConfig = value;
    if (_fitNotifier.value != value.fit) {
      _fitNotifier.value = value.fit;
    }
  }

  /// Resizes the native render target without recreating the player.
  ///
  /// Pass null to return to the intrinsic decoded size. Delegates to the
  /// video controller's native resize; the surface picks the change up in
  /// place.
  Future<void> setRenderTargetSize({int? width, int? height}) async {
    final controller = _videoController;
    if (controller == null) return;
    await controller.setSize(width: width, height: height);
  }

  // Convenience accessors — kept for callers that used the old fields.
  MediaKitProxyUrlResolver? get proxyUrlResolver => config.proxyUrlResolver;
  set proxyUrlResolver(MediaKitProxyUrlResolver? value) => config = config.copyWith(proxyUrlResolver: value);

  bool get enableCodec => config.enableCodec;
  set enableCodec(bool v) => config = config.copyWith(enableCodec: v);


  bool get customPlayerOutput => config.customPlayerOutput;
  set customPlayerOutput(bool v) => config = config.copyWith(customPlayerOutput: v);

  String? get videoHardwareDecoder => config.videoHardwareDecoder;
  set videoHardwareDecoder(String? v) => config = config.copyWith(videoHardwareDecoder: v);

  String get videoOutputDriver => config.videoOutputDriver;
  set videoOutputDriver(String v) => config = config.copyWith(videoOutputDriver: v);

  String? get audioOutputDriver => config.audioOutputDriver;
  set audioOutputDriver(String? v) => config = config.copyWith(audioOutputDriver: v);

  bool get enableRtxVsr => config.enableRtxVsr;
  set enableRtxVsr(bool v) => config = config.copyWith(enableRtxVsr: v);

  // VideoControllerConfiguration passthrough convenience accessors.
  double get videoScale => config.videoScale;
  set videoScale(double v) => config = config.copyWith(videoScale: v);

  int? get videoOutputWidth => config.videoOutputWidth;
  set videoOutputWidth(int? v) => config = config.copyWith(videoOutputWidth: v);

  int? get videoOutputHeight => config.videoOutputHeight;
  set videoOutputHeight(int? v) => config = config.copyWith(videoOutputHeight: v);

  bool get androidAttachSurfaceAfterVideoParameters => config.androidAttachSurfaceAfterVideoParameters;
  set androidAttachSurfaceAfterVideoParameters(bool v) =>
      config = config.copyWith(androidAttachSurfaceAfterVideoParameters: v);

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  mk.Player? _player;
  mkv.VideoController? _videoController;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _privateInput = false;
  bool _softwareDecoderNextOpen = false;

  /// What the device is, as far as the platform probe could say.
  ///
  /// Falls back to the process's own CPU count when nothing was probed, which
  /// is the one device fact a Dart process can read by itself.

  /// What the device can decode, and in hardware or not.
  ///
  /// Unknown when the host attached no provider; the adapter then leaves the
  /// engine's own behaviour alone instead of guessing.
  PlatformCodecCapabilities _codecs = PlatformCodecCapabilities.unknown;

  /// Codec of the video track mpv reported for the current source.
  ///
  /// The container says nothing about this: an MP4 carries H.264, HEVC or AV1,
  /// and which decoder to reach for depends on the codec.

  // ignore: unused_field
  bool _audioOutputSuppressed = false;

  String? _currentUrl;

  /// Whether the current source is a live (non-seekable) stream.
  ///
  /// Rate changes are ignored for live sources: mpv would happily
  /// pitch-shift a broadcast that has no meaningful playback speed.
  bool _liveSource = false;

  bool _playingNow = false;
  bool _bufferingNow = false;
  bool _hasOpened = false;

  int? _width;
  int? _height;

  double _lastEmittedVolume = -1.0;

  BoxFit _videoFit = BoxFit.contain;

  /// Fit as a listenable, so a custom [build] implementation can react
  /// to [setVideoFit] without owning the notifier.
  ValueListenable<BoxFit> get fitListenable => _fitNotifier;

  /// mpv events are consumed through subscriptions bound once for the
  /// whole adapter lifetime, so the base's source gate stays open.
  @override
  bool get gatesSourceEvents => false;

  // ---------------------------------------------------------------------------
  // PlayerVideo
  // ---------------------------------------------------------------------------

  final ValueNotifier<BoxFit> _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);

  /// The current viewport fit.
  BoxFit get videoFit => _videoFit;

  /// Applies the viewport fit through the surface.
  void setVideoFit(BoxFit fit) {
    if (_fitNotifier.value == fit && _videoConfig.fit == fit) return;
    _videoFit = fit;
    _fitNotifier.value = fit;
    _videoConfig = _videoConfig.copyWith(fit: fit);
  }

  /// Whether this adapter currently owns a video surface.
  @override
  bool get available => !isDisposed && !audioOnly && _videoController != null;

  /// Builds the video output widget.
  @override
  Widget build() {
    final controller = _videoController;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<BoxFit>(
      valueListenable: _fitNotifier,
      builder: (context, fit, _) {
        final cfg = _videoConfig;

        return mkv.Video(
          controller: controller,
          width: cfg.width,
          height: cfg.height,
          fit: fit,
          fill: cfg.fill,
          alignment: cfg.alignment,
          aspectRatio: cfg.aspectRatio,
          filterQuality: cfg.filterQuality,
          controls: cfg.controls ?? MediaKitVideoControls.none,
          wakelock: cfg.wakelock,
          pauseUponEnteringBackgroundMode: cfg.pauseUponEnteringBackgroundMode,
          resumeUponEnteringForegroundMode: cfg.resumeUponEnteringForegroundMode,
          subtitleViewConfiguration: cfg.subtitleViewConfiguration,
          onEnterFullscreen: cfg.onEnterFullscreen ?? mkv.defaultEnterNativeFullscreen,
          onExitFullscreen: cfg.onExitFullscreen ?? mkv.defaultExitNativeFullscreen,
        );
      },
    );
  }

  /// No-op: [mkv.Video] owns its own surface lifecycle.
  @override
  Future<void> attach() async {}

  /// Symmetric no-op for [attach].
  @override
  Future<void> detach() async {}

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// The underlying media_kit player.
  ///
  /// Throws [StateError] before [onInitialize].
  mk.Player get player {
    final p = _player;

    if (p == null) {
      throw StateError('MediaKitPlayerAdapter has not been initialized.');
    }

    return p;
  }

  /// The video controller surface widgets bind to.
  mkv.VideoController? get videoController => _videoController;

  /// Whether decoded video frames have been observed for the current
  /// source.
  bool get hasDecodedVideoFrame => _hasDecodedVideoFrame;

  bool _hasDecodedVideoFrame = false;

  /// Minimum spacing between published decoded-frame heartbeats.
  static const int frameHeartbeatIntervalMs = 1000;

  final Stopwatch _frameHeartbeatClock = Stopwatch();

  int _lastFrameHeartbeatMs = -frameHeartbeatIntervalMs;

  /// The resolved hardware decoder preference (already normalised for
  /// the current platform).
  String get preferredHardwareDecoder => _preferredHardwareDecoder;

  String _preferredHardwareDecoder = 'auto-safe';

  /// Whether the current platform drives the compat-mode surface.

  /// Whether the current platform supports the video frame progress
  /// heartbeat implementation.
  ///
  /// The native `estimated-vf-fps` observation is intentionally limited
  /// to Windows. Other platforms do not start the observer and do not
  /// emit video frame progress events.
  bool get _supportsVideoFrameProgress => _frameProgressSupported;

  /// Ensures the media_kit native libraries are loaded.
  static void ensureInitialized() {
    mk.MediaKit.ensureInitialized();
  }

  // ---------------------------------------------------------------------------
  // Engine contract
  // ---------------------------------------------------------------------------

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {
    _player = _injectedPlayer ?? mk.Player();

    // The device budget must be known before the video controller and the
    // native property contract are built, because both branch on it. It now
    // arrives with the adapter context: the kernel stamps what the platform
    // probe answered into every session.
    _codecs = context.codecs;

    _resolvePreferredHardwareDecoder();

    _videoController = _buildVideoController();

    _subscribeStreams();

    // Video frame progress is intentionally Windows-only.
    if (_supportsVideoFrameProgress) {
      _observeDecodedFrames();
    }

    await _applyHostDeclaredProperties();
  }

  @override
  Future<void> onBeforeOpen(PlayerSource source) async {
    final url = source.uri.toString();

    _liveSource = source.isLive;

    // A prepared software fallback belongs to the source it was
    // prepared for. `_currentUrl` is overwritten here, so the
    // comparison has to happen first.
    final sameSource = _softwareDecoderNextOpen && url == _currentUrl;

    _currentUrl = url;

    _hasDecodedVideoFrame = false;
    _lastFrameHeartbeatMs = -frameHeartbeatIntervalMs;

    _softwareDecoderNextOpen = sameSource;

    await _applyDecoderPolicy();
    await _applyProxy();
  }

  @override
  Future<void> onOpen(PlayerSource source) async {
    final recipe = source.metadata[kMediaKitCustomInputKey];
    final opener = config.customInputOpener;
    if (recipe != null || source.protocol == SourceProtocol.custom) {
      if (opener == null || recipe == null) {
        throw UnsupportedError(
          'Source carries a $kMediaKitCustomInputKey recipe but no '
          'MediaKitPlayerConfig.customInputOpener is registered.',
        );
      }
      await opener(player, recipe);
    } else {
      await player.open(
        mk.Media(source.uri.toString(), httpHeaders: source.hasHeaders ? source.headers!.values : null),
        play: true,
      );
    }

    _hasOpened = true;

    if (audioOnly) {
      await _applyAudioOnly(true);
    }
  }

  @override
  Future<void> onPlay() async {
    await player.play();
    emitPlaying();
  }

  @override
  Future<void> onPause() async {
    await player.pause();
    emitPaused();
  }

  @override
  Future<void> onStop() async {
    await player.stop();

    _playingNow = false;
    _bufferingNow = false;
    _hasOpened = false;

    _hasDecodedVideoFrame = false;
    _width = null;
    _height = null;

    _lastFrameHeartbeatMs = -frameHeartbeatIntervalMs;
  }

  @override
  Future<void> onSeek(Duration position) => player.seek(position);

  @override
  Future<void> onSetVolume(double volume) => player.setVolume(volume.clamp(0.0, 1.0) * 100.0);

  @override
  Future<void> onSetRate(double rate) {
    // Live streams have no meaningful playback speed; honouring the
    // command would pitch-shift a broadcast.
    if (_liveSource) {
      return Future<void>.value();
    }

    return player.setRate(rate);
  }

  @override
  Future<void> onClose() async {
    await player.stop();

    _hasOpened = false;
    _playingNow = false;
    _bufferingNow = false;

    // Reset all source-scoped presentation state so the next source
    // cannot inherit the previous source's frame / geometry state.
    _hasDecodedVideoFrame = false;
    _width = null;
    _height = null;

    _lastFrameHeartbeatMs = -frameHeartbeatIntervalMs;
  }

  @override
  Future<void> onDispose() async {
    await Future.wait(_subscriptions.map((subscription) => subscription.cancel()));

    _subscriptions.clear();

    // Stop the frame heartbeat clock before tearing down the player.
    if (_frameHeartbeatClock.isRunning) {
      _frameHeartbeatClock.stop();
    }

    _fitNotifier.dispose();

    // A player supplied through the constructor may be owned by the
    // caller. Only dispose players that were created by this adapter.
    if (_injectedPlayer == null) {
      await _player?.dispose();
    }

    _player = null;
    _videoController = null;
  }

  // ---------------------------------------------------------------------------
  // Extensions
  // ---------------------------------------------------------------------------

  /// Whether the next open bypasses the native proxy.
  void setPrivateInput(bool value) {
    _privateInput = value;
  }

  /// Marks that the next open of the current source should use software
  /// decoding.
  void prepareSoftwareDecoderFallback() {
    _softwareDecoderNextOpen = true;
  }

  /// Suppresses audio output for the next open.
  Future<void> setAudioOutputSuppressed(bool suppressed) async {
    _audioOutputSuppressed = suppressed;

    if (suppressed) {
      try {
        await player.setAudioTrack(mk.AudioTrack.no());
      } catch (_) {
        // Best-effort; some builds reject track selection before open.
      }
    }
  }

  @override
  Future<void> onAfterOpen(PlayerSource source) async {
    // The suppression flag belongs to the source lifecycle: a fresh open
    // (including a recovery replay of the same source) rebuilds the audio
    // pipeline, so it must be suppressed again or sound comes back.
    if (_audioOutputSuppressed) {
      try {
        await player.setAudioTrack(mk.AudioTrack.no());
      } catch (_) {
        // Best-effort.
      }
    }
  }

  @override
  Future<void> onSetAudioOnly(bool audioOnly) => _applyAudioOnly(audioOnly);

  Future<void> _applyAudioOnly(bool audioOnly) async {
    await player.setVideoTrack(audioOnly ? mk.VideoTrack.no() : mk.VideoTrack.auto());
  }

  /// Captures the current frame through mpv.
  ///
  /// mpv encodes the frame itself, so this returns the decoded picture at the
  /// stream's resolution — no widget needs to be on screen and no surface must
  /// be read. `image/jpeg` is what mpv encodes most cheaply, but PNG is
  /// available too, so both requested formats are honoured.
  ///
  /// Subtitles are included only when the adapter runs mpv's own subtitle
  /// renderer and the caller asked for them: burning them in is a deliberate
  /// choice, not a side effect of taking a screenshot.
  @override
  Future<Uint8List?> onCaptureFrame(ScreenshotRequest request) async {
    if (!_hasOpened) {
      return null;
    }

    final p = _player;

    if (p == null) {
      return null;
    }

    try {
      return await p.screenshot(
        format: request.mimeType,
        includeLibassSubtitles: request.includeSubtitles && _libassEnabled,
      );
    } catch (error) {
      // The web backend throws instead of declaring no capability; the caller
      // falls back to the rendered surface, which is the only route there.
      MediaCoreLog.warning(LogCategory.renderer, 'captureFrame failed: \$error', error: error);

      return null;
    }
  }

  /// Whether mpv renders subtitles itself.
  ///
  /// Only then can `screenshot` burn them into the image. Read from the live
  /// player rather than from this package's config, because libass is a
  /// media_kit-level setting an injector can change.
  bool get _libassEnabled {
    final configuration = _player?.platform?.configuration;

    return configuration?.libass ?? false;
  }

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

    _subscriptions.add(s.width.listen(_onWidth));

    _subscriptions.add(s.height.listen(_onHeight));

    _subscriptions.add(s.error.listen(_onError));

    _subscriptions.add(s.buffer.listen(_onBuffer));

    // The track list is where the codec becomes known, and the codec is what
    // decides whether hardware decoding was ever possible.
    _subscriptions.add(s.tracks.listen(_onTracks));
  }

  /// Records the video codec, and reacts when the device cannot decode it.
  ///
  /// Two things happen once the platform says this codec has no hardware
  /// decoder here: the next open of the same source starts in software instead
  /// of spending a failed hardware attempt on it, and — while no frame has been
  /// decoded yet — the current open switches over immediately, which is free
  /// because nothing has been shown.
  void _onTracks(mk.Tracks tracks) {
    for (final track in tracks.video) {
      final codec = VideoCodec.tryParse(track.codec);

      if (codec == null) {
        continue;
      }


      final hardware = _codecs.canDecodeInHardware(codec, width: _width ?? 0, height: _height ?? 0);

      if (hardware != false) {
        return;
      }

      _softwareDecoderNextOpen = true;

      MediaCoreLog.info(LogCategory.renderer, 'no hardware decoder for ${track.codec}; decoding in software');

      if (!_hasDecodedVideoFrame) {
        unawaited(_applyDecoderPolicy());
      }

      return;
    }
  }

  /// Starts the decoded-video heartbeat observer.
  ///
  /// This functionality is intentionally Windows-only.
  ///
  /// `estimated-vf-fps` is used as a video-output heartbeat. It is not
  /// treated as an exact decoded-frame counter.
  void _observeDecodedFrames() {
    if (!_supportsVideoFrameProgress) {
      return;
    }

    if (_frameHeartbeatClock.isRunning) {
      return;
    }

    _frameHeartbeatClock.start();

    const property = 'estimated-vf-fps';

    try {
      final native = player.platform;

      // `estimated-vf-fps` is used only as a video-output heartbeat.
      // It is not treated as an exact decoded-frame counter.
      //
      // Do not replace this with position / width / height changes:
      // those signals do not prove that video frames are progressing.
      // ignore: avoid_dynamic_calls
      (native as dynamic).observeProperty?.call(property, (dynamic value) async {
        _onNativeFrameSignal(property, value?.toString() ?? '');
      });
    } catch (error, stackTrace) {
      MediaCoreLog.warning(
        LogCategory.renderer,
        'observeProperty failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onNativeFrameSignal(String property, String value) {
    // Frame progress is Windows-only.
    if (!_supportsVideoFrameProgress) {
      return;
    }

    if (isDisposed) return;
    if (!_hasOpened || !_playingNow) return;
    if (property != 'estimated-vf-fps') return;

    final fps = double.tryParse(value.trim());

    if (fps == null || fps <= 0) return;

    final now = _frameHeartbeatClock.elapsedMilliseconds;

    if (now - _lastFrameHeartbeatMs < frameHeartbeatIntervalMs) {
      return;
    }

    _lastFrameHeartbeatMs = now;

    _hasDecodedVideoFrame = true;

    emitVideoFrameProgress();
  }

  void _onPlaying(bool playing) {
    if (_playingNow == playing) return;

    _playingNow = playing;

    if (playing) {
      emitPlaying();
    } else if (_hasOpened && !state.stopped && !state.completed) {
      emitPaused();
    }
  }

  void _onCompleted(bool completed) {
    if (!completed) return;

    _playingNow = false;

    emitCompleted();
  }

  void _onBuffering(bool buffering) {
    if (_bufferingNow == buffering) return;

    _bufferingNow = buffering;

    emitBuffering(buffering, resumePlaying: buffering ? null : _playingNow);
  }

  void _onPosition(Duration position) {
    // media_kit replays zeroed position/duration on stop(); without this
    // guard the previous source's teardown leaks into the next generation.
    if (!_hasOpened) return;

    emitPositionChanged(position);
  }

  void _onDuration(Duration duration) {
    if (!_hasOpened) return;

    emitDurationChanged(duration);
  }

  void _onVolume(double v) {
    final normalised = (v / 100.0).clamp(0.0, 1.0);

    if (normalised == _lastEmittedVolume) {
      return;
    }

    _lastEmittedVolume = normalised;

    emitVolumeChanged(normalised);
  }

  void _onWidth(int? w) {
    if (!_hasOpened) return;

    _width = w;
    _maybeEmitSize();
  }

  void _onHeight(int? h) {
    if (!_hasOpened) return;

    _height = h;
    _maybeEmitSize();
  }

  void _maybeEmitSize() {
    final w = _width;
    final h = _height;

    if (w == null || h == null || w <= 0 || h <= 0) {
      return;
    }

    emitVideoSizeChangedIfChanged(w, h);
  }

  void _onError(String message) {
    MediaCoreLog.warning(LogCategory.error, message);

    reportEngineError(message: message);
  }

  void _onBuffer(Duration buffered) {
    updateMetrics((m) => m.copyWith(buffered: buffered));
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
    // Frame progress is declared optimistically here and narrowed per
    // platform by the constructor: the heartbeat is Windows-only, so the
    // instance reports `true` on Windows and `false` everywhere else. Do
    // not read this constant as the running adapter's answer — read
    // `adapter.capabilities`.
    supportsVideoFrameProgress: true,
    supportsVideoSizeChanged: true,
    supportsVideoReconfig: false,
    supportsHwdecInfo: false,
    supportsVideoFilters: false,
    supportsScreenshot: true,

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
    supportedProtocols: MediaKitFormats.supportedProtocols,
    supportedFormats: MediaKitFormats.supportedFormats,
  );
}
