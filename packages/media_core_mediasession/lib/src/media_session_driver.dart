import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart' as asvc;
import 'package:audio_service_mpris/audio_service_mpris.dart' as ampris;
import 'package:audio_service_win/audio_service_win.dart' as aswin;
import 'package:audio_session/audio_session.dart' as asession;
import 'package:media_core/media_core.dart';
import 'package:media_core_mediasession/src/media_session_config.dart';
import 'package:media_core_mediasession/src/media_session_handler.dart';
import 'package:meta/meta.dart' show visibleForTesting;

/// System media surfaces for the media_core kernel.
///
/// Implements [KernelAudioDriver], so the kernel hands it the active player —
/// video or audio, it does not care which — and wires that player to the
/// platform's media surfaces:
///
/// ```text
/// PlayerHandle.playbackStream ──▶ MediaSessionHandler ──▶ notification / SMTC / MPRIS
/// notification buttons        ──▶ MediaSessionHandler ──▶ PlayerHandle
/// audio focus interruptions   ──▶ pause / duck / resume
/// headphones unplugged        ──▶ pause
/// ```
///
/// ### Why this is its own package
///
/// The surfaces are not an audio feature: a video player wants the same
/// notification, the same lock-screen entry and the same media keys, and the
/// only differences are cosmetic (a seek pair instead of a skip pair, a video
/// channel name). Keeping the capability here means a video host gets it without
/// depending on the music module, and the music module uses the same
/// implementation instead of a second one.
///
/// Usage:
///
/// ```dart
/// final session = MediaSessionDriver(config: const MediaSessionConfig.video());
/// await session.initialize();          // once, early (before runApp is fine)
/// kernel.attachAudio(session);         // the kernel notifies active players
///
/// // or drive it manually without a kernel:
/// session.setActive(handle);
/// ```
///
/// The host app still owns the platform plumbing a library cannot declare for
/// it — the `audio_service` activity/service entries and, on Android 13+, the
/// notification permission. See the package README.
base class MediaSessionDriver implements KernelAudioDriver, MediaBackgroundSession {
  /// Creates the driver.
  MediaSessionDriver({
    this.config = const MediaSessionConfig(),
    asession.AudioSessionConfiguration? sessionConfiguration,
    this.artUriResolver,
    @visibleForTesting MediaSessionHandler? handler,
  }) : _sessionConfiguration = sessionConfiguration,
       _handler = handler;

  /// Capability configuration.
  final MediaSessionConfig config;

  /// Resolves artwork for a source that does not carry any.
  ///
  /// A music source usually publishes `artUri` metadata; a video source
  /// usually has nothing but a URL and a title, and a notification without
  /// artwork looks unfinished next to every other app on the device. The host
  /// knows where its thumbnails come from, so it supplies the answer here.
  ///
  /// Called once per media item, on the main isolate.
  final Uri? Function(PlayerSource source)? artUriResolver;

  final asession.AudioSessionConfiguration? _sessionConfiguration;

  MediaSessionHandler? _handler;
  PlayerHandle? _active;

  /// The session that holds the platform's media surface, or null.
  ///
  /// One owner, checked on every write: the multiview switch and the music module
  /// both hand this driver a player, and a session that ended late used to be able
  /// to rewrite or clear whatever the new one had just published. Ownership is now
  /// named, so a stale writer is ignored instead of winning.
  String? _surfaceOwner;

  /// Queue transports a host may install (a music player with a queue).
  ///
  /// Mutable rather than constructor arguments: the driver is created once at
  /// startup, while the player that owns a queue appears later — and a
  /// single-media app never sets them, so the notification simply shows the
  /// seek pair instead of skip buttons.
  Future<void> Function()? skipToNextHandler;

  /// Installed counterpart of [skipToNextHandler].
  Future<void> Function()? skipToPreviousHandler;

  /// Jump to a queue index.
  Future<void> Function(int index)? skipToQueueItemHandler;

  /// Playback-rate changes coming from the platform.
  Future<void> Function(double rate)? setSpeedHandler;

  StreamSubscription<void>? _playbackSub;
  StreamSubscription<asession.AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  bool _initialized = false;
  bool _disposed = false;

  /// Whether the platform handshake ran and got nothing back.
  ///
  /// The difference between "not yet" and "not here" for every later activation: a
  /// driver whose `AudioService.init` threw has no surface at all, and saying so is
  /// the only way a host learns the platform is missing the feature instead of
  /// chasing a startup order.
  bool _noSurface = false;
  bool _ducked = false;
  bool _resumeOnInterruptionEnd = false;
  double _volumeBeforeDuck = 1;

  /// The underlying audio_service handler.
  ///
  /// Null before [initialize].
  MediaSessionHandler? get handler => _handler;

  /// The active player, if any.
  PlayerHandle? get active => _active;

  /// Whether the driver is publishing, i.e. whether [initialize] ran.
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes audio_service and the audio session.
  ///
  /// Call once, early (before `runApp` is fine).
  ///
  /// Platform integration:
  ///
  /// - Android/iOS: media notification + lock screen controls
  /// - Windows: SMTC (System Media Transport Controls) via audio_service_win
  /// - Linux: MPRIS (D-Bus) via audio_service_mpris — shows up in GNOME/KDE
  ///   media applets and media keys work
  ///
  /// On platforms without audio_session support the focus part is skipped;
  /// the surfaces still work.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    _initialized = true;

    _registerPlatformImplementation();

    if (_handler != null) {
      // Supplied from outside (a test): the platform session is still wired,
      // but there is no handler to build.
      return;
    }

    MediaSessionHandler started;

    try {
      started = await asvc.AudioService.init(
        builder: () => MediaSessionHandler(
          onPlay: () async {
            await _active?.play();
          },
          onPause: () async {
            await _active?.pause();
          },
          onSeek: (position) async {
            await _active?.seek(position);
          },
          onStop: () async {
            await _active?.stop();
          },
          onNext: skipToNextHandler == null
              ? null
              : () async {
                  await skipToNextHandler!.call();
                },
          onPrevious: skipToPreviousHandler == null
              ? null
              : () async {
                  await skipToPreviousHandler!.call();
                },
          onSkipToQueueItem: skipToQueueItemHandler == null
              ? null
              : (index) async {
                  await skipToQueueItemHandler!.call(index);
                },
          onSetSpeed: setSpeedHandler == null
              ? null
              : (rate) async {
                  await setSpeedHandler!.call(rate);
                },
          controlsBuilder: _buildControls,
          stopOnTaskRemoved: config.androidStopOnRemoveTask,
        ),
        config: asvc.AudioServiceConfig(
          androidNotificationChannelId: config.androidNotificationChannelId,
          androidNotificationChannelName: config.androidNotificationChannelName,
          androidNotificationOngoing: config.androidNotificationOngoing,
          androidStopForegroundOnPause: !config.androidNotificationOngoing,
        ),
      );
    } on Object {
      // Remembered, then rethrown: `enable` still fails the way its own doc says it
      // does, but a host that caught that and kept using the driver gets an honest
      // answer from `activate` — there is no surface here, rather than "not yet,
      // keep waiting".
      _noSurface = true;
      rethrow;
    }

    _handler = started;

    if (!_supportsAudioSession) {
      return;
    }

    try {
      final session = await asession.AudioSession.instance;

      await session.configure(_sessionConfiguration ?? const asession.AudioSessionConfiguration.music());

      if (config.processInterruptions) {
        _interruptionSub = session.interruptionEventStream.listen(_onInterruption, onError: (_) {});
      }

      if (config.pauseOnBecomingNoisy) {
        _noisySub = session.becomingNoisyEventStream.listen((_) => _active?.pause(), onError: (_) {});
      }
    } on Object catch (_) {
      // A platform without a functional audio_session implementation. Playback
      // still works; focus handling is simply unavailable.
    }
  }

  /// Releases this driver.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _playbackSub?.cancel();
    _playbackSub = null;

    await _interruptionSub?.cancel();
    _interruptionSub = null;

    await _noisySub?.cancel();
    _noisySub = null;

    // The surface goes away rather than being parked: a driver that is gone has
    // nothing left to publish, and an idle-but-still-listed media item is a
    // control bar for a session that no longer exists.
    await _handler?.releaseSurface();
    _surfaceOwner = null;

    _active = null;
    _handler = null;
  }

  // ---------------------------------------------------------------------------
  // KernelAudioDriver
  // ---------------------------------------------------------------------------

  @override
  void onPlayerActivated(PlayerHandle handle) {
    setActive(handle);
  }

  @override
  void onPlayerDeactivated() {
    setActive(null);
  }

  // ---------------------------------------------------------------------------
  // Active player binding
  // ---------------------------------------------------------------------------

  /// Binds [handle] as the player the surfaces describe.
  ///
  /// Pass null to detach. The kernel calls this automatically via
  /// `attachAudio`; apps without a kernel can drive it directly. Safe before
  /// [initialize]: the binding is remembered and published once a handler
  /// exists, so a host that opens a player while `AudioService.init` is still
  /// running does not end up with a silent notification.
  void setActive(PlayerHandle? handle) {
    if (_disposed || identical(handle, _active)) {
      return;
    }

    unawaited(_playbackSub?.cancel());
    _playbackSub = null;

    _active = handle;
    _ducked = false;
    _resumeOnInterruptionEnd = false;

    final handler = _handler;

    if (handler == null) {
      // No handler yet: keep the binding and publish when initialize finishes.
      return;
    }

    if (handle == null) {
      _surfaceOwner = null;
      handler
        ..publishIdle()
        ..clearMediaItem();

      return;
    }

    // The kernel's active player owns the surface under its own id, so an
    // explicit `activate` for another session and this path cannot both claim
    // they are showing the platform's control bar.
    _surfaceOwner = _sessionIdFor(handle);
    handler.publishMediaItem(_itemFor(handle));
    _publishCurrent(handle);

    _playbackSub = handle.playbackStream.listen(
      (_) => _publishCurrent(handle),
      onError: (_) {},
      onDone: () {
        if (identical(_active, handle)) {
          setActive(null);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MediaBackgroundSession
  // ---------------------------------------------------------------------------

  @override
  String? get activeSessionId => _surfaceOwner;

  @override
  Future<MediaSessionActivation> activate({required String sessionId, required String title}) async {
    final handler = _handler;

    if (_disposed) {
      // The surface was released and this driver will never take it again: a call
      // that outlived its driver, which is the opposite mistake from one that came
      // too early. Saying so is the point — a host that assumed the activation had
      // worked would report background playback the device is not providing.
      return const MediaSessionActivation.refused(MediaSessionRefusal.disposed);
    }

    if (handler == null) {
      return MediaSessionActivation.refused(
        _noSurface ? MediaSessionRefusal.surfaceUnavailable : MediaSessionRefusal.notInitialized,
      );
    }

    final previous = _surfaceOwner;

    _surfaceOwner = sessionId;

    final active = _active;

    if (active == null) {
      // Nothing is bound to play: the surface shows what this session is, and says
      // plainly that it is at rest. An activation is not a play.
      handler
        ..publishMediaItem(MediaSessionItem(id: sessionId, title: title))
        ..publishState(
          const MediaSessionState(
            playing: false,
            position: Duration.zero,
            duration: Duration.zero,
            speed: 1,
            phase: MediaSurfacePhase.idle,
          ),
          controls: _buildControls(false),
        );

      return MediaSessionActivation.held(previousOwnerSessionId: previous);
    }

    handler.publishMediaItem(_itemFor(active, title: title));
    _publishCurrent(active);

    return MediaSessionActivation.held(previousOwnerSessionId: previous);
  }

  @override
  Future<void> updateMetadata({required String sessionId, required String title}) async {
    final handler = _handler;

    if (handler == null || !_owns(sessionId)) {
      // A stale session's late callback: the control bar belongs to whoever holds
      // it now, and rewriting it would be the multiview bug this guard exists for.
      return;
    }

    final active = _active;

    handler.publishMediaItem(
      active == null ? MediaSessionItem(id: sessionId, title: title) : _itemFor(active, title: title),
    );
  }

  @override
  Future<void> deactivate(String sessionId) async {
    final handler = _handler;

    if (handler == null || !_owns(sessionId)) {
      return;
    }

    _surfaceOwner = null;
    await handler.releaseSurface();
  }

  /// Publishes again, for a host that changed something the surfaces show.
  ///
  /// Used after [initialize] finished to pick up a binding that arrived while
  /// the platform was starting, and by a host whose player began playing a
  /// different source on the same handle.
  void refresh() {
    final handle = _active;
    final handler = _handler;

    if (handle == null || handler == null) {
      return;
    }

    handler.publishMediaItem(_itemFor(handle));
    _publishCurrent(handle);

    _playbackSub ??= handle.playbackStream.listen(
      (_) => _publishCurrent(handle),
      onError: (_) {},
      onDone: () {
        if (identical(_active, handle)) {
          setActive(null);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Interruptions
  // ---------------------------------------------------------------------------

  void _onInterruption(asession.AudioInterruptionEvent event) {
    final active = _active;

    if (active == null) {
      return;
    }

    if (event.begin) {
      switch (event.type) {
        case asession.AudioInterruptionType.duck:
          if (!_ducked) {
            _ducked = true;
            _volumeBeforeDuck = active.playback.volume;
            unawaited(active.setVolume(_volumeBeforeDuck * config.duckFactor));
          }

        case asession.AudioInterruptionType.pause:
        case asession.AudioInterruptionType.unknown:
          _resumeOnInterruptionEnd = config.resumeAfterInterruption && active.playback.isPlaying;
          unawaited(active.pause());
      }

      return;
    }

    if (_ducked) {
      _ducked = false;
      unawaited(active.setVolume(_volumeBeforeDuck));
    }

    if (_resumeOnInterruptionEnd) {
      _resumeOnInterruptionEnd = false;
      unawaited(active.play());
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _supportsAudioSession {
    // audio_session has no implementation on Windows/Linux.
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  void _registerPlatformImplementation() {
    // Federated plugins normally self-register through the generated plugin
    // registrant. Explicit registration covers custom embedders and makes the
    // backend selection visible.
    try {
      if (Platform.isWindows) {
        aswin.AudioServiceWin.registerWith();
      } else if (Platform.isLinux) {
        ampris.AudioServiceMpris.registerWith();
      }
    } on Object catch (_) {
      // Registration is best-effort: audio_service falls back to its default
      // platform implementation when this fails.
    }
  }

  /// The controls the platform shows for the current state.
  ///
  /// Skip buttons appear only when the host installed queue transports; the
  /// seek pair appears when the configuration asks for it. A single-media
  /// player therefore gets play/pause, ±[MediaSessionConfig.seekStep] and stop,
  /// while a queue player gets skip-previous/next in the same slots — which is
  /// what each platform's users expect from that kind of app.
  List<asvc.MediaControl> _buildControls(bool playing) {
    if (!config.showControls) {
      return const <asvc.MediaControl>[];
    }

    return <asvc.MediaControl>[
      if (skipToPreviousHandler != null)
        asvc.MediaControl(androidIcon: config.previousIcon, label: 'Previous', action: asvc.MediaAction.skipToPrevious)
      else if (config.showSeekButtons)
        asvc.MediaControl(
          androidIcon: config.rewindIcon,
          label: 'Back ${config.seekStep.inSeconds}s',
          action: asvc.MediaAction.rewind,
        ),
      asvc.MediaControl(
        androidIcon: playing ? config.pauseIcon : config.playIcon,
        label: playing ? 'Pause' : 'Play',
        action: playing ? asvc.MediaAction.pause : asvc.MediaAction.play,
      ),
      if (skipToNextHandler != null)
        asvc.MediaControl(androidIcon: config.nextIcon, label: 'Next', action: asvc.MediaAction.skipToNext)
      else if (config.showSeekButtons)
        asvc.MediaControl(
          androidIcon: config.fastForwardIcon,
          label: 'Forward ${config.seekStep.inSeconds}s',
          action: asvc.MediaAction.fastForward,
        ),
      asvc.MediaControl(androidIcon: config.stopIcon, label: 'Stop', action: asvc.MediaAction.stop),
    ];
  }

  /// What the surfaces were last told, so a position-only tick can be skipped.
  MediaSessionState? _published;

  /// What the transport is doing, in the platform's words.
  ///
  /// Ordered so that the condition the viewer is waiting under wins: a stream that
  /// stalled mid-play is `buffering` and not `ready`, and a playhead at the end is
  /// `completed` rather than a paused file. The control bar is how a viewer decides
  /// whether to wait or to leave, and one phase for all of them spent that decision
  /// on a guess.
  static MediaSurfacePhase _phaseOf(PlayerTransportState playback) {
    if (playback.isIdle || playback.isStopped) {
      return MediaSurfacePhase.idle;
    }

    if (playback.isLoading) {
      return MediaSurfacePhase.loading;
    }

    if (playback.isBuffering) {
      return MediaSurfacePhase.buffering;
    }

    if (!playback.isPlaying && playback.hasDuration && playback.position >= playback.duration) {
      return MediaSurfacePhase.completed;
    }

    return MediaSurfacePhase.ready;
  }

  /// How far the notification's position may lag the player.
  ///
  /// A lock screen redraws this bar about once a second no matter what the app
  /// pushes, and every publish is a platform notification rebuild. The player
  /// can report many times a second (and, before the engine adapters reduced
  /// their position streams, once per frame) - publishing each one spent battery
  /// and heat on frames nobody would see.
  static const Duration _positionPublishInterval = Duration(seconds: 1);

  void _publishCurrent(PlayerHandle handle) {
    final playback = handle.playback;
    final next = MediaSessionState(
      playing: playback.isPlaying,
      position: playback.position,
      duration: playback.duration,
      speed: playback.rate,
      phase: _phaseOf(playback),
    );

    final previous = _published;
    if (previous != null &&
        next.playing == previous.playing &&
        next.duration == previous.duration &&
        next.speed == previous.speed &&
        next.phase == previous.phase) {
      final drift = next.position - previous.position;
      // Only small forward drift is skippable. A jump - a seek back, a new song
      // whose zero position follows the old one - must reach the surfaces now:
      // it is a different timeline, not a step along the same one.
      if (drift >= Duration.zero && drift < _positionPublishInterval) {
        return;
      }
    }

    _published = next;
    _handler?.publishState(next, controls: _buildControls(next.playing));
  }

  /// Whether [sessionId] is what the surfaces are showing.
  bool _owns(String sessionId) => _surfaceOwner == sessionId;

  /// The id a player handle holds the surface under.
  ///
  /// Derived from the handle rather than passed in, so the kernel's own activation
  /// path and a host's explicit `activate` cannot end up with two different names
  /// for one session.
  static String _sessionIdFor(PlayerHandle handle) => 'player/${handle.id.value}';

  /// The name a viewer would recognise for [source].
  static String _titleOf(PlayerSource? source, Uri? uri) {
    if (source != null && source.hasTitle) {
      return source.title!;
    }

    if (uri == null) {
      return 'Media';
    }

    return uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last;
  }

  /// Describes a handle as a media item.
  ///
  /// Title order: [title] when the session named itself, then the source's own
  /// title, then its file name, then the URI — a notification that says "Media" is
  /// worse than one that says "movie.mp4". Artwork comes from the source metadata,
  /// then from [artUriResolver]; a video source usually only has the second.
  MediaSessionItem _itemFor(PlayerHandle handle, {String? title}) {
    final source = handle.source;
    final uri = source?.uri;

    final name = title ?? _titleOf(source, uri);

    final metadata = source?.metadataValue('artUri');

    final artUri = metadata is String ? Uri.tryParse(metadata) : (source != null ? artUriResolver?.call(source) : null);

    final duration = handle.playback.duration;

    return MediaSessionItem(
      id: source?.id.value ?? handle.id.value,
      title: name,
      duration: duration == Duration.zero ? null : duration,
      artUri: artUri,
    );
  }

  @override
  String toString() {
    return 'MediaSessionDriver('
        'initialized: $_initialized, '
        'active: ${_active?.id.value ?? 'none'}, '
        'channel: ${config.androidNotificationChannelId}'
        ')';
  }
}
