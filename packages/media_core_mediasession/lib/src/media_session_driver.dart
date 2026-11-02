import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter_media_session/flutter_media_session.dart' as fms;
import 'package:media_core/media_core.dart';
import 'package:media_core_mediasession/src/media_session_config.dart';
import 'package:media_core_mediasession/src/media_session_handler.dart';
import 'package:media_core_mediasession/src/media_session_models.dart';
import 'package:media_core_mediasession/src/media_session_surfaces.dart' show mediaSessionAlbumKey, mediaSessionArtUriKey, mediaSessionArtistKey;
import 'package:meta/meta.dart' show visibleForTesting;

final LogModule _log = MediaCoreLog.of(LogCategory.session);

/// A transport owned by another engine or isolate that this driver presents.
///
/// The platform owns exactly one media surface per app, so a host with several
/// windows still has one place to publish. The window that owns the surface
/// hands the driver these four verbs; the driver never reaches into another
/// engine itself.
abstract interface class MediaSessionRemoteTarget {
  /// Whether the platform should offer the seek pair for this session.
  ///
  /// A live stream has no timeline to scrub; a button that does nothing is
  /// worse than one the surface never shows.
  bool get canSeek;

  /// Resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback.
  Future<void> stop();

  /// Moves the playhead.
  Future<void> seek(Duration position);
}

/// System media surfaces for the media_core kernel.
///
/// Implements [KernelAudioDriver], so the kernel hands it the active player —
/// video or audio, it does not care which — and wires that player to the
/// platform's media surfaces:
///
/// ```text
/// PlayerHandle.playbackStream ──▶ MediaSessionHandler ──▶ flutter_media_session
/// notification buttons        ──▶ MediaSessionHandler ──▶ PlayerHandle
/// audio focus interruptions   ──▶ pause / resume (flutter_media_session)
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
/// flutter_media_session merges its own Android service and permissions and
/// asks for the notification permission on activation; the host still owns
/// the iOS `audio` background mode. Linux has no surface yet.
base class MediaSessionDriver implements KernelAudioDriver, MediaBackgroundSession {
  /// Creates the driver.
  MediaSessionDriver({
    this.config = const MediaSessionConfig(),
    this.artUriResolver,
    @visibleForTesting MediaSessionHandler? handler,
  }) : _handler = handler;

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

  MediaSessionHandler? _handler;
  PlayerHandle? _active;

  /// A session owned by another engine, presented through this driver's one
  /// platform surface. While set, the transport buttons go to that engine's
  /// target and the local player's stream stops publishing.
  MediaSessionRemoteTarget? _remoteTarget;
  MediaSessionItem? _remoteItem;
  MediaSessionState? _remoteState;

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

  // The bridge to flutter_media_session: the handler's values go out, the
  // system's button presses come back.
  StreamSubscription<fms.MediaAction>? _actionSub;
  StreamSubscription<MediaItem?>? _itemSub;
  StreamSubscription<PlaybackState>? _stateSub;

  /// Platform calls run one after another, so a clear can never overtake the
  /// publish that preceded it.
  Future<void> _platformQueue = Future<void>.value();
  bool _platformActive = false;
  List<fms.MediaAction>? _publishedLayout;

  bool _initialized = false;
  bool _disposed = false;

  /// Whether the platform handshake ran and got nothing back.
  ///
  /// The difference between "not yet" and "not here" for every later activation: a
  /// driver whose platform activation threw has no surface at all, and saying so is
  /// the only way a host learns the platform is missing the feature instead of
  /// chasing a startup order.
  bool _noSurface = false;

  /// The session state and transport the surfaces mirror.
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

  /// Activates the platform media session.
  ///
  /// Call once, early (before `runApp` is fine).
  ///
  /// Platform integration, all through flutter_media_session:
  ///
  /// - Android: Media3 notification and lock screen controls
  /// - iOS/macOS: lock screen, Control Center, Now Playing
  /// - Windows: SMTC (System Media Transport Controls)
  /// - Web: the Media Session API
  ///
  /// Linux has no implementation and throws [UnsupportedError]; a host that
  /// wants the app to boot regardless catches it.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    _initialized = true;

    if (_handler != null) {
      // Supplied from outside (a test): there is no platform to bridge.
      return;
    }

    final started = MediaSessionHandler(
      onPlay: _transportPlay,
      onPause: _transportPause,
      onSeek: _transportSeek,
      onStop: _transportStop,
      onRewind: () => _seekTransportBy(-config.seekStep),
      onFastForward: () => _seekTransportBy(config.seekStep),
      // These wrappers read the mutable handler fields at invocation time:
      // the driver is created once at startup while the player that owns a
      // queue appears later, so a null check baked in here would leave the
      // skip buttons permanently dead for a host that installs handlers after
      // initialize().
      onNext: () async {
        await skipToNextHandler?.call();
      },
      onPrevious: () async {
        await skipToPreviousHandler?.call();
      },
      onSkipToQueueItem: (index) async {
        await skipToQueueItemHandler?.call(index);
      },
      onSetSpeed: (rate) async {
        await setSpeedHandler?.call(rate);
      },
      controlsBuilder: _buildControls,
    );

    try {
      if (!_supportsPlatform) {
        throw UnsupportedError('flutter_media_session has no implementation for $defaultTargetPlatform');
      }

      final platform = fms.FlutterMediaSessionPlatform.instance;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await platform.requestNotificationPermission();
      }

      await platform.activate();
      _platformActive = true;

      if (config.processInterruptions) {
        await _bestEffort(() => platform.setAutoHandleInterruptions(true));
      }

      final step = config.seekStep.inSeconds;
      await _bestEffort(() => platform.setSkipIntervals(forwardSeconds: step, backwardSeconds: step));

      _actionSub = platform.onMediaAction.listen(_onPlatformAction, onError: (_) {});
    } on Object catch (error, stackTrace) {
      // Remembered, then rethrown: `enable` still fails the way its own doc says it
      // does, but a host that caught that and kept using the driver gets an honest
      // answer from `activate` — there is no surface here, rather than "not yet,
      // keep waiting".
      _log.error('media session activation failed; no media surface', error: error, stackTrace: stackTrace);
      _noSurface = true;
      // A failed init stays retryable: `_initialized` was set optimistically
      // at the top, and leaving it set turns a later attempt into a silent
      // no-op on a permanently dead driver.
      _initialized = false;
      rethrow;
    }

    _handler = started;
    _itemSub = started.mediaItem.listen((item) => _enqueue(() => _pushItem(item)));
    _stateSub = started.playbackState.listen((state) => _enqueue(() => _pushState(state)));

    // A player or a remote window may have claimed the surface while the
    // platform was activating. Publish what was remembered now that there is
    // a handler to receive it.
    final remoteItem = _remoteItem;
    final remoteState = _remoteState;
    final active = _active;
    if (remoteItem != null && remoteState != null) {
      _published = null;
      started.publishMediaItem(remoteItem);
      _publishState(remoteState);
    } else if (active != null) {
      _surfaceOwner = _sessionIdFor(active);
      started.publishMediaItem(_itemFor(active));
      _publishCurrent(active);
      _playbackSub ??= active.playbackStream.listen(
        (_) => _publishCurrent(active),
        onError: (_) {},
        onDone: () {
          if (identical(_active, active)) {
            setActive(null);
          }
        },
      );
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

    // The surface goes away rather than being parked: a driver that is gone has
    // nothing left to publish, and an idle-but-still-listed media item is a
    // control bar for a session that no longer exists.
    await _handler?.releaseSurface();
    await _platformQueue;

    await _actionSub?.cancel();
    _actionSub = null;
    await _itemSub?.cancel();
    _itemSub = null;
    await _stateSub?.cancel();
    _stateSub = null;

    if (_platformActive) {
      _platformActive = false;
      await _bestEffort(fms.FlutterMediaSessionPlatform.instance.deactivate);
    }

    _surfaceOwner = null;
    _remoteTarget = null;
    _remoteItem = null;
    _remoteState = null;

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
  /// exists, so a host that opens a player while the platform is still activating and still
  /// running does not end up with a silent notification.
  void setActive(PlayerHandle? handle) {
    if (_disposed || (identical(handle, _active) && _remoteTarget == null)) {
      return;
    }

    if (handle == null && _remoteTarget != null) {
      // The local player stopped while another window held the surface: the
      // remote presentation stays, and its target still owns the buttons.
      // Its playback subscription goes too - left alive, every tick of the
      // detached player would keep overwriting the remote window's state on
      // the platform surface.
      unawaited(_playbackSub?.cancel());
      _playbackSub = null;
      _active = null;
      return;
    }

    unawaited(_playbackSub?.cancel());
    _playbackSub = null;

    // A local player that becomes active is the newest transport in the
    // process; it takes the surface back from a remote presentation.
    _remoteTarget = null;
    _remoteItem = null;
    _remoteState = null;

    _active = handle;

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
  // Remote sessions
  // ---------------------------------------------------------------------------

  /// Presents a session that plays in another engine.
  ///
  /// The platform has one media surface, so a host with several windows
  /// publishes the window that currently owns it through this door. The
  /// driver keeps its local [setActive] player for the moment the remote
  /// session ends, but stops publishing that player while the remote one is
  /// up. [target] receives the transport buttons; a target whose window is
  /// gone should make these calls no-ops, not throw into the platform.
  void presentRemote({
    required String sessionId,
    required MediaSessionItem item,
    required MediaSessionState state,
    required MediaSessionRemoteTarget target,
  }) {
    if (_disposed) {
      return;
    }

    // The local player's stream must not overwrite a remote session while it
    // is shown. Its handle stays bound for the fallback in [clearRemote].
    unawaited(_playbackSub?.cancel());
    _playbackSub = null;

    _surfaceOwner = sessionId;
    _remoteTarget = target;
    _remoteItem = item;
    _remoteState = state;

    final handler = _handler;
    if (handler == null) {
      return;
    }

    _published = null;
    handler.publishMediaItem(item);
    _publishState(state);
  }

  /// Replaces the remote session's metadata, when it still owns the surface.
  void updateRemoteItem(MediaSessionItem item) {
    if (_disposed || _remoteTarget == null || _surfaceOwner == null) {
      return;
    }
    _remoteItem = item;
    _handler?.publishMediaItem(item);
  }

  /// Replaces the remote session's playback state, when it still owns the
  /// surface.
  void updateRemoteState(MediaSessionState state) {
    if (_disposed || _remoteTarget == null || _surfaceOwner == null) {
      return;
    }
    _remoteState = state;
    _publishState(state);
  }

  /// Ends the remote presentation.
  ///
  /// A local player that was bound before the remote session takes the
  /// surface back; otherwise the surface goes idle instead of describing a
  /// window that is gone.
  void clearRemote() {
    if (_remoteTarget == null && _remoteItem == null) {
      return;
    }

    _remoteTarget = null;
    _remoteItem = null;
    _remoteState = null;

    final handler = _handler;
    if (handler == null) {
      return;
    }

    final active = _active;
    if (active != null) {
      _surfaceOwner = _sessionIdFor(active);
      _published = null;
      handler.publishMediaItem(_itemFor(active));
      _publishCurrent(active);
      _playbackSub ??= active.playbackStream.listen(
        (_) => _publishCurrent(active),
        onError: (_) {},
        onDone: () {
          if (identical(_active, active)) {
            setActive(null);
          }
        },
      );
      return;
    }

    _surfaceOwner = null;
    _published = null;
    handler
      ..publishIdle()
      ..clearMediaItem();
  }

  /// Whether a remote session currently owns the surface.
  bool get hasRemoteSession => _remoteTarget != null;

  Future<void> _transportPlay() async {
    final remote = _remoteTarget;
    if (remote != null) {
      await remote.play();
      return;
    }
    await _active?.play();
  }

  Future<void> _transportPause() async {
    final remote = _remoteTarget;
    if (remote != null) {
      await remote.pause();
      return;
    }
    await _active?.pause();
  }

  Future<void> _transportStop() async {
    final remote = _remoteTarget;
    if (remote != null) {
      await remote.stop();
      return;
    }
    await _active?.stop();
  }

  Future<void> _transportSeek(Duration position) async {
    final remote = _remoteTarget;
    if (remote != null) {
      await remote.seek(position);
      return;
    }
    await _active?.seek(position);
  }

  /// Relative seek for the notification's rewind/fast-forward buttons.
  Future<void> _seekTransportBy(Duration offset) async {
    final remote = _remoteTarget;

    if (remote != null) {
      final remotePosition = _remoteState?.position ?? Duration.zero;
      final remoteTarget = remotePosition + offset;
      await remote.seek(remoteTarget < Duration.zero ? Duration.zero : remoteTarget);
      return;
    }

    final active = _active;

    if (active == null) {
      return;
    }

    final target = active.playback.position + offset;
    await _transportSeek(target < Duration.zero ? Duration.zero : target);
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

    // An explicit named activation is a new owner: it takes the buttons back
    // from a remote window. Its own state is published below.
    _remoteTarget = null;
    _remoteItem = null;
    _remoteState = null;

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
          controls: _currentControls(false),
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

    final remote = _remoteItem;
    if (remote != null) {
      _remoteItem = remote.copyWith(title: title);
      handler.publishMediaItem(_remoteItem!);
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
    _remoteTarget = null;
    _remoteItem = null;
    _remoteState = null;

    // The released surface must stop being written to: a bound player's
    // playback tick would otherwise republish state (and re-advertise
    // controls) onto a surface nobody owns any more.
    unawaited(_playbackSub?.cancel());
    _playbackSub = null;

    await handler.releaseSurface();
  }

  /// Publishes again, for a host that changed something the surfaces show.
  ///
  /// Used after [initialize] finished to pick up a binding that arrived while
  /// the platform was starting, and by a host whose player began playing a
  /// different source on the same handle.
  void refresh() {
    final handler = _handler;
    if (handler == null) {
      return;
    }

    final remoteItem = _remoteItem;
    final remoteState = _remoteState;
    if (remoteItem != null && remoteState != null) {
      _published = null;
      handler.publishMediaItem(remoteItem);
      _publishState(remoteState);
      return;
    }

    final handle = _active;
    if (handle == null) {
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
  // Platform bridge
  // ---------------------------------------------------------------------------

  /// Whether flutter_media_session has an implementation here.
  static bool get _supportsPlatform {
    if (kIsWeb) {
      return true;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
      _ => false,
    };
  }

  /// Runs an optional platform call; a platform that lacks it is not an error.
  static Future<void> _bestEffort(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error) {
      _log.debug('optional media session call skipped', fields: <String, Object?>{'error': error.toString()});
    }
  }

  void _enqueue(Future<void> Function() step) {
    _platformQueue = _platformQueue.then((_) => step()).catchError((Object error) {
      _log.warning('media session publish failed', error: error);
    });
  }

  /// Turns a system button press (or an interruption the plugin handled) into
  /// the handler's transport call.
  void _onPlatformAction(fms.MediaAction action) {
    final handler = _handler;
    if (handler == null) {
      return;
    }

    final command = switch (action.name) {
      'play' => handler.play(),
      'pause' => handler.pause(),
      'stop' => handler.stop(),
      'skipToNext' => handler.skipToNext(),
      'skipToPrevious' => handler.skipToPrevious(),
      'rewind' => handler.rewind(),
      'fastForward' => handler.fastForward(),
      'seekTo' => handler.seek(action.seekPosition ?? Duration.zero),
      _ => Future<void>.value(),
    };

    unawaited(
      command.catchError((Object error) {
        _log.warning('media action failed', error: error);
      }),
    );
  }

  Future<void> _ensurePlatformActive() async {
    if (_platformActive) {
      return;
    }

    await fms.FlutterMediaSessionPlatform.instance.activate();
    _platformActive = true;
    _publishedLayout = null;
  }

  Future<void> _pushItem(MediaItem? item) async {
    final platform = fms.FlutterMediaSessionPlatform.instance;

    if (item == null) {
      // A cleared item is a released surface: the notification and the
      // platform's "now playing" entry go away instead of going blank.
      if (_platformActive) {
        _platformActive = false;
        await platform.deactivate();
      }
      return;
    }

    await _ensurePlatformActive();
    await platform.updateMetadata(
      fms.MediaMetadata(
        title: item.title,
        artist: item.artist,
        album: item.album,
        artworkUri: item.artUri?.toString(),
        duration: item.duration,
      ),
    );
  }

  Future<void> _pushState(PlaybackState state) async {
    // A released surface stays released: activating the platform again only
    // to say "idle" would bring the notification back.
    if (!_platformActive && (state.processingState == AudioProcessingState.idle || _handler?.mediaItem.value == null)) {
      return;
    }

    await _ensurePlatformActive();

    final platform = fms.FlutterMediaSessionPlatform.instance;
    final layout = <fms.MediaAction>[for (final control in state.controls) _platformActionOf(control.action)];

    if (!listEquals(layout, _publishedLayout)) {
      _publishedLayout = layout;

      final seekable = state.controls.any(
        (control) => control.action == MediaAction.rewind || control.action == MediaAction.fastForward,
      );
      final compact = <int>[
        for (final index in config.androidCompactActionIndices)
          if (index < layout.length) index,
      ];

      await _bestEffort(() => platform.setActionLayout(fms.ActionSlotLayout(layout, compactActionIndices: compact)));
      await _bestEffort(
        () => platform.updateAvailableActions(<fms.MediaAction>{
          ...layout,
          // The play/pause slot swaps with the state; both verbs stay allowed.
          if (layout.contains(fms.MediaAction.play) || layout.contains(fms.MediaAction.pause)) ...<fms.MediaAction>{
            fms.MediaAction.play,
            fms.MediaAction.pause,
          },
          if (seekable) fms.MediaAction.seekTo,
        }),
      );
    }

    await platform.updatePlaybackState(
      fms.PlaybackState(
        status: switch (state.processingState) {
          AudioProcessingState.loading || AudioProcessingState.buffering => fms.PlaybackStatus.buffering,
          AudioProcessingState.completed => fms.PlaybackStatus.ended,
          AudioProcessingState.error => fms.PlaybackStatus.error,
          AudioProcessingState.idle => fms.PlaybackStatus.idle,
          AudioProcessingState.ready => state.playing ? fms.PlaybackStatus.playing : fms.PlaybackStatus.paused,
        },
        position: state.updatePosition,
        speed: state.speed,
        bufferedPosition: state.bufferedPosition,
      ),
    );
  }

  static fms.MediaAction _platformActionOf(MediaAction action) {
    return switch (action) {
      MediaAction.play => fms.MediaAction.play,
      MediaAction.pause => fms.MediaAction.pause,
      MediaAction.stop => fms.MediaAction.stop,
      MediaAction.seek => fms.MediaAction.seekTo,
      MediaAction.rewind => fms.MediaAction.rewind,
      MediaAction.fastForward => fms.MediaAction.fastForward,
      MediaAction.skipToPrevious => fms.MediaAction.skipToPrevious,
      MediaAction.skipToNext => fms.MediaAction.skipToNext,
    };
  }

  /// The controls the platform shows for the current state.
  ///
  /// Skip buttons appear only when the host installed queue transports; the
  /// seek pair appears when the configuration asks for it. A single-media
  /// player therefore gets play/pause, ±[MediaSessionConfig.seekStep] and stop,
  /// while a queue player gets skip-previous/next in the same slots — which is
  /// what each platform's users expect from that kind of app.
  List<MediaControl> _buildControls(bool playing, {bool seekable = true}) {
    if (!config.showControls) {
      return const <MediaControl>[];
    }

    return <MediaControl>[
      if (skipToPreviousHandler != null)
        MediaControl.skipToPrevious
      else if (config.showSeekButtons && seekable)
        MediaControl(action: MediaAction.rewind, label: 'Back ${config.seekStep.inSeconds}s'),
      if (playing) MediaControl.pause else MediaControl.play,
      if (skipToNextHandler != null)
        MediaControl.skipToNext
      else if (config.showSeekButtons && seekable)
        MediaControl(action: MediaAction.fastForward, label: 'Forward ${config.seekStep.inSeconds}s'),
      MediaControl.stop,
    ];
  }

  /// Controls for the current owner: a live remote session gets no seek
  /// buttons, a local handle keeps the configured pair.
  List<MediaControl> _currentControls(bool playing) {
    return _buildControls(playing, seekable: _remoteTarget?.canSeek ?? true);
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
    _publishState(
      MediaSessionState(
        playing: playback.isPlaying,
        position: playback.position,
        duration: playback.duration,
        speed: playback.rate,
        phase: _phaseOf(playback),
      ),
    );
  }

  /// Publishes [next] unless the surface already shows the same state.
  void _publishState(MediaSessionState next) {
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
    _handler?.publishState(next, controls: _currentControls(next.playing));
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
  /// worse than one that says "movie.mp4". Artist and album come from the
  /// source metadata ([mediaSessionArtistKey], [mediaSessionAlbumKey]). Artwork comes from the source metadata,
  /// then from [artUriResolver]; a video source usually only has the second.
  MediaSessionItem _itemFor(PlayerHandle handle, {String? title}) {
    final source = handle.source;
    final uri = source?.uri;

    final name = title ?? _titleOf(source, uri);

    final metadata = source?.metadataValue(mediaSessionArtUriKey);

    final artUri = metadata is String ? Uri.tryParse(metadata) : (source != null ? artUriResolver?.call(source) : null);

    final duration = handle.playback.duration;
    final artist = source?.metadataValue(mediaSessionArtistKey);
    final album = source?.metadataValue(mediaSessionAlbumKey);

    return MediaSessionItem(
      id: source?.id.value ?? handle.id.value,
      title: name,
      artist: artist is String ? artist : '',
      album: album is String ? album : '',
      duration: duration == Duration.zero ? null : duration,
      artUri: artUri,
    );
  }

  @override
  String toString() {
    return 'MediaSessionDriver('
        'initialized: $_initialized, '
        'active: ${_active?.id.value ?? 'none'}'
        ')';
  }
}
