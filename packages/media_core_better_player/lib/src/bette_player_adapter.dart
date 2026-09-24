import 'dart:async';
import 'better_player_config.dart';
import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';
import 'package:better_player_plus/better_player_plus.dart';

export 'better_player_config.dart' show BetterPlayerConfig, BetterPlayerDataSourceBuilder;

/// [PlayerAdapter] implementation backed by better_player_plus —
/// the ExoPlayer engine.
///
/// This adapter also owns its video surface: it implements
/// [PlayerVideo] directly, so there is exactly one place that knows
/// how the texture is produced.
///
/// Engine semantics:
///
/// - source-scoped event acceptance with deferred errors
///   (ExoPlayer can emit an exception synchronously while
///   setupDataSource is still pending) — provided by the base
/// - fit applied through `setOverriddenFit`, never a wrapper widget
/// - audio-output suppression starts the source muted, avoiding
///   an audible burst during initialization
/// - live streams flagged through the data source
/// - an honest capability declaration ([defaultCapabilities])
final class BetterPlayerAdapter extends PlayerAdapterBase implements PlayerVideo {
  BetterPlayerAdapter({
    super.id = 'exo',
    super.capabilities = defaultCapabilities,
    BetterPlayerController? controller,
    BetterPlayerConfig playerConfig = const BetterPlayerConfig(),
  }) : _injectedController = controller,
       config = playerConfig;

  final BetterPlayerController? _injectedController;

  BetterPlayerController? _controller;
  PlayerAdapterContext? _context;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  BetterPlayerConfig config;

  BoxFit get videoFit => _videoFit;

  /// Applies the viewport fit through `setOverriddenFit`.
  ///
  /// Safe to call before [onInitialize]: the value is remembered and
  /// applied when the controller is created.
  void setVideoFit(BoxFit fit) {
    if (_videoFit == fit) return;

    _videoFit = fit;
    _controller?.setOverriddenFit(fit);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _audioOutputSuppressed = false;
  BoxFit _videoFit = BoxFit.contain;

  // Value-diff state. BetterPlayerEvent only carries *transitions*;
  // position / duration / buffered change silently between events and
  // are diffed off the wrapped controller's value below.
  Duration _lastPosition = Duration.zero;
  Duration? _lastDuration;

  // Prevents the same native exception from being reported through
  // both the BetterPlayer event stream and the open-failure state.
  String? _lastReportedError;

  /// The underlying [BetterPlayerController].
  ///
  /// Throws [StateError] before [onInitialize].
  BetterPlayerController get controller {
    final c = _controller;

    if (c == null) {
      throw StateError('BetterPlayerAdapter has not been initialized.');
    }

    return c;
  }

  /// The underlying controller, or `null` before [onInitialize].
  BetterPlayerController? get controllerOrNull => _controller;

  // ---------------------------------------------------------------------------
  // PlayerVideo
  // ---------------------------------------------------------------------------

  /// Whether this adapter currently owns a video surface.
  ///
  /// False until [onInitialize] created the controller, and false
  /// after the adapter has been disposed.
  @override
  bool get available => !isDisposed && _controller != null;

  /// Builds the video output widget.
  ///
  /// The returned widget is owned by this adapter and must be inserted
  /// into the application's widget tree by the surface layer.
  @override
  Widget build() {
    final c = _controller;

    if (c == null) {
      return const SizedBox.shrink();
    }

    return BetterPlayer(controller: c);
  }

  /// No-op: BetterPlayer owns its own surface lifecycle.
  @override
  Future<void> attach() async {}

  /// Symmetric no-op for [attach].
  @override
  Future<void> detach() async {}

  // ---------------------------------------------------------------------------
  // Engine contract
  // ---------------------------------------------------------------------------

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {
    _context = context;
    _lastReportedError = null;

    final injected = _injectedController;

    if (injected != null) {
      _controller = injected;

      // The injected controller is externally created, but the adapter
      // still owns the presentation fit requested through PlayerVideo.
      injected.setOverriddenFit(_videoFit);
    } else {
      final cfg = config;

      final base =
          cfg.configuration ??
          const BetterPlayerConfiguration(
            handleLifecycle: false,
            fullScreenByDefault: false,
            looping: false,
            controlsConfiguration: BetterPlayerControlsConfiguration(showControls: false),
          );

      _controller = BetterPlayerController(
        base.copyWith(autoPlay: base.autoPlay && !_audioOutputSuppressed, fit: _videoFit),
        betterPlayerPlaylistConfiguration: cfg.playlistConfiguration,
        betterPlayerDataSource: cfg.dataSource,
      );
    }

    controller.addEventsListener(_onEngineEvent);
  }

  @override
  bool get engineReportsOpenFailure => _controller?.videoPlayerController?.value.hasError == true;

  @override
  Future<void> onOpen(PlayerSource source) async {
    // A new source starts a new error reporting scope.
    _lastReportedError = null;

    // A controller can be reused for multiple sources. Make sure the
    // value listener is registered exactly once for the current source.
    final oldVpc = controller.videoPlayerController;
    oldVpc?.removeListener(_onValueChange);

    // Prefer an explicitly configured data source; otherwise map the
    // framework-provided source.
    var dataSource = config.dataSource;

    if (dataSource == null) {
      final resolved = _resolveSource(source);

      if (resolved == null) {
        throw StateError(
          'BetterPlayerAdapter cannot open ${source.uri} '
          '(unsupported source type).',
        );
      }

      dataSource = BetterPlayerDataSource(
        resolved.$1,
        resolved.$2,
        headers: source.hasHeaders ? Map<String, String>.from(source.headers!.values) : null,
        // `isLive` is a source-level hint; do not hardcode it.
        liveStream: source.isLive,
      );
    }

    // Per-open rewrite on top of whichever source was chosen above.
    final transform = config.configureDataSource;

    if (transform != null) {
      dataSource = transform(source, dataSource);
    }

    await controller.setupDataSource(dataSource);

    if (isDisposed) return;

    // Attach the value listener only after setupDataSource so the first
    // snapshot reflects an initialized controller.
    final vpc = controller.videoPlayerController;

    if (vpc != null) {
      vpc.removeListener(_onValueChange);
      vpc.addListener(_onValueChange);

      final value = vpc.value;

      _lastPosition = value.position;
      _lastDuration = value.duration;

      final size = value.size;

      if (size != null && size.width > 0 && size.height > 0) {
        emitVideoSizeChangedIfChanged(size.width.toInt(), size.height.toInt());
      }
    }

    if (isDisposed) return;

    // Apply the context config once — nothing in better_player_plus
    // does this automatically.
    final contextConfig = _context?.config ?? const PlayerAdapterConfig();

    if (contextConfig.volume != 1.0) {
      await controller.setVolume(contextConfig.volume);
    }

    if (isDisposed) return;

    if (contextConfig.playbackRate != 1.0) {
      await controller.setSpeed(contextConfig.playbackRate);
    }
  }

  @override
  Future<void> onAfterOpen(PlayerSource source) async {
    // Audio suppression is intentionally applied after the source has
    // been created, so the native player never emits audible output
    // during source initialization.
    await setVolume(_audioOutputSuppressed ? 0.0 : 1.0);

    if (isDisposed) return;

    if (_audioOutputSuppressed) {
      await play();
    }
  }

  @override
  Future<void> onPlay() => controller.play();

  @override
  Future<void> onPause() => controller.pause();

  @override
  Future<void> onStop() async {
    await controller.pause();

    if (isDisposed) return;

    await controller.seekTo(Duration.zero);
  }

  @override
  Future<void> onSeek(Duration position) => controller.seekTo(position);

  @override
  Future<void> onSetVolume(double volume) => controller.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> onSetRate(double rate) => controller.setSpeed(rate);

  @override
  Future<void> onClose() async {
    // Detach the value listener before winding the controller down so a
    // late tick cannot leak into the next source's diff state.
    controller.videoPlayerController?.removeListener(_onValueChange);

    _lastPosition = Duration.zero;
    _lastDuration = null;
    _lastReportedError = null;

    await controller.pause();

    if (isDisposed) return;

    // Reset the native position when possible. A source that has already
    // failed may reject seekTo, so closing should not be made fragile by
    // a best-effort cleanup operation.
    try {
      await controller.seekTo(Duration.zero);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  @override
  Future<void> onDispose() async {
    // better_player returns early from dispose() when autoDispose is false,
    // and this adapter sets it false to own the lifecycle itself. Without
    // forceDispose the native ExoPlayer survives — decoder, surface and
    // audio included — so the next engine switch fights it for the hardware
    // decoder and a closed room keeps playing behind the UI.
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      controller.videoPlayerController?.removeListener(_onValueChange);
      controller.removeEventsListener(_onEngineEvent);
      controller.dispose(forceDispose: true);
    }

    _context = null;
    _lastPosition = Duration.zero;
    _lastDuration = null;
    _lastReportedError = null;
  }

  // ---------------------------------------------------------------------------
  // Extensions
  // ---------------------------------------------------------------------------

  /// Suppresses audio output for the next open.
  void setAudioOutputSuppressed(bool suppressed) {
    _audioOutputSuppressed = suppressed;
  }

  // Audio-only is not implemented for this engine, and the capability
  // declaration says so: better_player_plus exposes no video-track
  // control at any layer — `setTrack` only picks among adaptive video
  // variants, and the platform channel behind it has no "disable video
  // renderer" method — so the decoder cannot be switched off. The
  // audio-only playback mode is therefore honored by the presentation
  // layer, which stops mounting this engine's surface and shows the
  // audio panel instead; video keeps decoding underneath.

  // ---------------------------------------------------------------------------
  // Source resolution
  // ---------------------------------------------------------------------------

  /// Maps a [PlayerSource] onto a better_player data-source type + URI.
  ///
  /// Returns `null` for unsupported schemes so [onOpen] can fail
  /// loudly instead of handing garbage to ExoPlayer.
  (BetterPlayerDataSourceType, String)? _resolveSource(PlayerSource source) {
    if (source.isFile) {
      return (BetterPlayerDataSourceType.file, source.uri.toFilePath());
    }

    if (source.isNetworkSource) {
      return (BetterPlayerDataSourceType.network, source.uri.toString());
    }

    // The installed better_player_plus version exposes:
    //
    //   network
    //   file
    //   memory
    //
    // It does NOT expose an `asset` data-source type. If asset playback
    // is required later, the asset bytes must first be loaded and passed
    // through the memory data-source API.
    if (source.isAsset) {
      return null;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Engine events (transitions only)
  // ---------------------------------------------------------------------------

  void _onEngineEvent(BetterPlayerEvent event) {
    if (!acceptsEngineEvents) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
      case BetterPlayerEventType.changedResolution:
        final size = _controller?.videoPlayerController?.value.size;

        if (size != null && size.width > 0 && size.height > 0) {
          emitVideoSizeChangedIfChanged(size.width.toInt(), size.height.toInt());
        }

      case BetterPlayerEventType.play:
        emitPlaying();

      case BetterPlayerEventType.pause:
        emitPaused();

      case BetterPlayerEventType.bufferingStart:
        emitBuffering(true);

      case BetterPlayerEventType.bufferingEnd:
        emitBuffering(false, resumePlaying: state.playing);

      case BetterPlayerEventType.finished:
        emitCompleted();

      case BetterPlayerEventType.exception:
        final message = event.parameters?['exception']?.toString() ?? 'BetterPlayer Error';

        // BetterPlayer may expose the same native failure both as an
        // exception event and through videoPlayerController.value.hasError.
        // Keep one error flowing into media_core for the same message.
        if (_lastReportedError == message) return;

        _lastReportedError = message;
        reportEngineError(message: message);

      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Value listener (position / duration / buffered)
  //
  // The engine events above only tell us *what mode* the player is in.
  // The wrapped controller's value is where the numbers live.
  // ---------------------------------------------------------------------------

  void _onValueChange() {
    if (!acceptsEngineEvents) return;

    final vpc = _controller?.videoPlayerController;

    if (vpc == null) return;

    final v = vpc.value;

    // Position.
    if (v.position != _lastPosition) {
      _lastPosition = v.position;
      emitPositionChanged(v.position);
    }

    // Duration (live streams report zero or null).
    final duration = v.duration;

    if (duration != _lastDuration) {
      _lastDuration = duration;

      if (duration != null && duration > Duration.zero) {
        emitDurationChanged(duration);
      }
    }

    // Buffered range → metrics. Never emitted as a ratio, so
    // supportsBufferingProgress stays false.
    if (v.buffered.isNotEmpty) {
      final end = v.buffered.last.end;

      if (end != metrics.buffered) {
        updateMetrics((m) => m.copyWith(buffered: end));
      }
    }

    // Size. Also emitted here (not only on the change events) because a
    // mid-stream reconfig can land on a value tick before any
    // changedResolution event arrives.
    final size = v.size;

    if (size != null && size.width > 0 && size.height > 0) {
      emitVideoSizeChangedIfChanged(size.width.toInt(), size.height.toInt());
    }
  }

  // ---------------------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------------------

  /// Capabilities of the ExoPlayer engine, as exposed by this adapter.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    // Core playback.
    supportsLive: true,
    supportsSeek: true,
    supportsPause: true,
    supportsStop: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsMuteControl: true,

    // better_player_plus exposes no video-track control, so the decoder
    // cannot be switched off and the adapter will not accept a command
    // it cannot carry out.
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
    supportsSoftwareDecoder: false,

    // Presentation.
    supportsPictureInPicture: false,
    supportsFullscreen: true,

    // Source matching.
    supportedProtocols: {'http', 'https', 'hls', 'dash', 'file'},
    supportedFormats: {'mp4', 'webm', 'm3u8', 'mpd', 'ts', 'mov', 'mkv'},
  );
}
