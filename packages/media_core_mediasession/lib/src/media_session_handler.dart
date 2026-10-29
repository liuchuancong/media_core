import 'package:audio_service/audio_service.dart';

/// Where the transport is, in the words the platform understands.
///
/// The handler used to publish [AudioProcessingState.ready] for everything, so a
/// notification described a stalled stream as available and a stopped one as
/// ready-and-not-playing. The platform draws a spinner, an error or nothing at
/// all from this, and a viewer deciding whether to wait or to leave decides on
/// the control bar — so the phase is said out loud rather than assumed.
enum MediaSurfacePhase {
  /// Nothing is loaded: the surface has no session to describe.
  idle,

  /// The resource is being fetched before it can play.
  loading,

  /// The engine is short of data in the middle of playback.
  buffering,

  /// Enough media is available to play from here.
  ready,

  /// The playhead reached the end of the media.
  completed,
}

/// Snapshot of playback state pushed into the system media surface.
final class MediaSessionState {
  /// Creates the snapshot.
  const MediaSessionState({
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
    required this.phase,
  });

  /// Whether playback is active.
  final bool playing;

  /// What the transport is doing, beyond playing or not.
  final MediaSurfacePhase phase;

  /// Current playback position.
  final Duration position;

  /// Known media duration.
  final Duration duration;

  /// Current playback speed.
  final double speed;
}

/// Metadata describing the current media item.
final class MediaSessionItem {
  /// Creates the metadata.
  const MediaSessionItem({
    required this.id,
    required this.title,
    this.album = '',
    this.artist = '',
    this.duration,
    this.artUri,
  });

  /// Stable media identifier.
  final String id;

  /// Display title.
  final String title;

  /// Display album.
  final String album;

  /// Display artist.
  final String artist;

  /// Media duration when known.
  final Duration? duration;

  /// Artwork uri when available.
  final Uri? artUri;

  /// This item with some fields replaced.
  MediaSessionItem copyWith({String? title, String? album, String? artist, Duration? duration, Uri? artUri}) {
    return MediaSessionItem(
      id: id,
      title: title ?? this.title,
      album: album ?? this.album,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      artUri: artUri ?? this.artUri,
    );
  }

  /// The artwork only when a surface can open it.
  ///
  /// Windows' SMTC reads a non-http value as a file path: `file://` with no
  /// path, a bare relative path, and a Windows drive taken for a scheme
  /// (`C:\…` parses as scheme `c`) all answer "the specified path is not an
  /// absolute path" on every publish — and leave the session without a
  /// thumbnail anyway, so nothing is lost by not sending them.
  Uri? get _openableArtUri {
    final uri = artUri;
    if (uri == null) return null;
    if (uri.isScheme('file')) return uri.path.isEmpty || uri.path == '/' ? null : uri;
    return uri.scheme.isEmpty || uri.scheme.length == 1 ? null : uri;
  }

  /// Converts to the platform model.
  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      duration: duration,
      artUri: _openableArtUri,
    );
  }
}

/// [BaseAudioHandler] that bridges the platform media surfaces and media_core.
///
/// Outbound (player → notification): [publishState] and [publishMediaItem]
/// mirror a `PlayerHandle`'s playback state.
///
/// Inbound (notification → player): transport commands are forwarded through
/// the callbacks supplied at construction. A callback that was not supplied
/// degrades to [BaseAudioHandler]'s default, so a control the host did not
/// install cannot silently do nothing.
final class MediaSessionHandler extends BaseAudioHandler {
  /// Creates the handler.
  MediaSessionHandler({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration position) onSeek,
    required Future<void> Function() onStop,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
    Future<void> Function(int index)? onSkipToQueueItem,
    Future<void> Function(double rate)? onSetSpeed,
    Future<void> Function()? onRewind,
    Future<void> Function()? onFastForward,
    this.controlsBuilder,
    this.stopOnTaskRemoved = false,
  }) : _onPlay = onPlay,
       _onPause = onPause,
       _onSeek = onSeek,
       _onStop = onStop,
       _onNext = onNext,
       _onPrevious = onPrevious,
       _onSkipToQueueItem = onSkipToQueueItem,
       _onSetSpeed = onSetSpeed,
       _onRewind = onRewind,
       _onFastForward = onFastForward;

  final Future<void> Function() _onPlay;
  final Future<void> Function() _onPause;
  final Future<void> Function(Duration position) _onSeek;
  final Future<void> Function() _onStop;
  final Future<void> Function()? _onNext;
  final Future<void> Function()? _onPrevious;
  final Future<void> Function(int index)? _onSkipToQueueItem;
  final Future<void> Function(double rate)? _onSetSpeed;
  final Future<void> Function()? _onRewind;
  final Future<void> Function()? _onFastForward;

  /// Whether the platform may offer skip-next.
  bool get canSkipToNext => _onNext != null;

  /// Whether the platform may offer skip-previous.
  bool get canSkipToPrevious => _onPrevious != null;

  /// Whether the task-removal callback stops playback.
  ///
  /// `MediaSessionConfig.androidStopOnRemoveTask`, which is what the platform's
  /// "the viewer swiped the app away" signal is for. Off means the audio keeps
  /// running from the notification, which is what a music app wants and what a
  /// live room does not.
  final bool stopOnTaskRemoved;

  /// Optional builder for notification controls.
  ///
  /// Receives the current playing state and returns the controls to display.
  /// When null a play/pause + stop pair is used.
  // Positional `playing` mirrors audio_service's `MediaControlsBuilder`, so a
  // platform-provided builder can be dropped in without rewrapping.
  // ignore: avoid_positional_boolean_parameters
  final List<MediaControl> Function(bool playing)? controlsBuilder;

  /// Builds compact action indices advertised to the platform.
  ///
  /// Derived from [controls] so callers don't have to keep two lists in sync.
  static List<int> compactIndicesFor(List<MediaControl> controls) {
    if (controls.length <= 2) {
      return List<int>.generate(controls.length, (index) => index);
    }

    return const <int>[0, 1];
  }

  /// Pushes [state] into the media surface.
  void publishState(MediaSessionState state, {List<MediaControl>? controls}) {
    playbackState.add(
      PlaybackState(
        // Explicit controls win; otherwise the builder is the default a
        // second publisher (a music binding ticking per state change) would
        // otherwise erase by passing none.
        controls: controls ?? controlsBuilder?.call(state.playing) ?? const <MediaControl>[],
        processingState: switch (state.phase) {
          MediaSurfacePhase.idle => AudioProcessingState.idle,
          MediaSurfacePhase.loading => AudioProcessingState.loading,
          MediaSurfacePhase.buffering => AudioProcessingState.buffering,
          MediaSurfacePhase.ready => AudioProcessingState.ready,
          MediaSurfacePhase.completed => AudioProcessingState.completed,
        },
        playing: state.playing,
        updatePosition: state.position,
        bufferedPosition: state.duration,
        speed: state.speed,
      ),
    );
  }

  /// Pushes idle state into the media surface.
  void publishIdle() {
    playbackState.add(PlaybackState());
  }

  /// Gives the platform's media surface back, without touching the player.
  ///
  /// The notification and the system session go away (`idle` is what removes
  /// them), and the transport is left exactly where it was: a host detaching a
  /// surface is not a viewer pressing stop.
  Future<void> releaseSurface() async {
    clearMediaItem();
    await stopFromHost();
  }

  /// [BaseAudioHandler.stop] — the platform's "this session is over" — without
  /// the transport command that the notification's stop button means.
  ///
  /// Named because our own `stop()` override *is* the viewer's button: calling
  /// `super.stop()` from a release path would otherwise read as pausing the
  /// player to whoever was watching the code.
  Future<void> stopFromHost() async {
    publishIdle();
    await super.stop();
  }

  /// Pushes [item] as the current media item.
  void publishMediaItem(MediaSessionItem item) {
    mediaItem.add(item.toMediaItem());
  }

  /// Clears the current media item.
  void clearMediaItem() {
    mediaItem.add(null);
  }

  /// Publishes the play list so the platform can show and jump through it.
  ///
  /// The playing entry is also published as the current [mediaItem]; the
  /// platform derives "current" from that, not from the list order.
  void publishQueue(List<MediaSessionItem> items, {int index = -1}) {
    queue.add(items.map((item) => item.toMediaItem()).toList(growable: false));

    if (index >= 0 && index < items.length) {
      publishMediaItem(items[index]);
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound transport commands (notification / lock screen / media keys)
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() => _onPlay();

  @override
  Future<void> pause() => _onPause();

  @override
  Future<void> seek(Duration position) => _onSeek(position);

  @override
  Future<void> stop() async {
    await _onStop();
    await super.stop();
  }

  /// The viewer swiped the app away in Android's recents.
  ///
  /// Without [stopOnTaskRemoved] this answers nothing and playback continues —
  /// the music keeps playing from the notification, which is what a music app
  /// asks for. With it, the stop the viewer meant is the stop that happens: a
  /// live room that keeps streaming after its page is gone is the case the flag
  /// exists for.
  @override
  Future<void> onTaskRemoved() async {
    if (!stopOnTaskRemoved) {
      return;
    }

    await stop();
  }

  @override
  Future<void> skipToNext() async {
    final next = _onNext;

    // Without a queue the sane degrade is the default behavior.
    if (next == null) {
      return await super.skipToNext();
    }

    await next();
  }

  /// Relative seeks. The notification advertises rewind/fast-forward buttons
  /// whenever a driver config asks for them; without these overrides the
  /// presses fall through to [BaseAudioHandler]'s empty no-ops, which is a
  /// button that looks alive and does nothing.
  @override
  Future<void> rewind() async {
    final rewind = _onRewind;

    if (rewind == null) {
      return await super.rewind();
    }

    await rewind();
  }

  @override
  Future<void> fastForward() async {
    final fastForward = _onFastForward;

    if (fastForward == null) {
      return await super.fastForward();
    }

    await fastForward();
  }

  @override
  Future<void> skipToPrevious() async {
    final previous = _onPrevious;

    if (previous == null) {
      return await super.skipToPrevious();
    }

    await previous();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final skip = _onSkipToQueueItem;

    if (skip == null) {
      return await super.skipToQueueItem(index);
    }

    await skip(index);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final setSpeed = _onSetSpeed;

    if (setSpeed == null) {
      return await super.setSpeed(speed);
    }

    await setSpeed(speed);
  }
}
