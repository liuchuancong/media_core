import 'package:media_core_mediasession/src/media_session_models.dart';

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

/// The media session's state and transport, independent of any platform.
///
/// Outbound (player → surfaces): [publishState] and [publishMediaItem] update
/// [playbackState] and [mediaItem]; the driver forwards those values to
/// flutter_media_session, and a host or a test can observe them directly.
///
/// Inbound (surfaces → player): the driver turns each system button into one
/// of the transport methods below, which call the callbacks supplied at
/// construction. A control the host did not install does nothing rather than
/// throwing into the platform.
final class MediaSessionHandler {
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

  /// What the surfaces show as the transport state.
  final MediaSessionValue<PlaybackState> playbackState = MediaSessionValue<PlaybackState>(const PlaybackState());

  /// What the surfaces show as the current item, or null for none.
  final MediaSessionValue<MediaItem?> mediaItem = MediaSessionValue<MediaItem?>(null);

  /// The play list a queue player published.
  final MediaSessionValue<List<MediaItem>> queue = MediaSessionValue<List<MediaItem>>(const <MediaItem>[]);

  /// Whether the platform may offer skip-next.
  bool get canSkipToNext => _onNext != null;

  /// Whether the platform may offer skip-previous.
  bool get canSkipToPrevious => _onPrevious != null;

  /// Optional builder for the surface controls.
  ///
  /// Receives the current playing state and returns the controls to display.
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
    playbackState.add(const PlaybackState());
  }

  /// Gives the platform's media surface back, without touching the player.
  ///
  /// The item is cleared and the state goes idle, which is what makes the
  /// driver deactivate the platform session; the transport is left exactly
  /// where it was: a host detaching a surface is not a viewer pressing stop.
  Future<void> releaseSurface() async {
    clearMediaItem();
    publishIdle();
  }

  /// Pushes [item] as the current media item.
  void publishMediaItem(MediaSessionItem item) {
    mediaItem.add(item.toMediaItem());
  }

  /// Clears the current media item.
  void clearMediaItem() {
    mediaItem.add(null);
  }

  /// Publishes the play list.
  ///
  /// The playing entry is also published as the current [mediaItem]; the
  /// surfaces derive "current" from that, not from the list order.
  void publishQueue(List<MediaSessionItem> items, {int index = -1}) {
    queue.add(items.map((item) => item.toMediaItem()).toList(growable: false));

    if (index >= 0 && index < items.length) {
      publishMediaItem(items[index]);
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound transport commands (notification / lock screen / media keys)
  // ---------------------------------------------------------------------------

  /// Resumes playback.
  Future<void> play() => _onPlay();

  /// Pauses playback.
  Future<void> pause() => _onPause();

  /// Moves the playhead.
  Future<void> seek(Duration position) => _onSeek(position);

  /// The viewer's stop button: stops the player and ends the session.
  Future<void> stop() async {
    await _onStop();
    await releaseSurface();
  }

  /// Skips to the next queue entry, when a queue transport is installed.
  Future<void> skipToNext() async => await _onNext?.call();

  /// Skips to the previous queue entry, when a queue transport is installed.
  Future<void> skipToPrevious() async => await _onPrevious?.call();

  /// Jumps back by the configured step.
  Future<void> rewind() async => await _onRewind?.call();

  /// Jumps forward by the configured step.
  Future<void> fastForward() async => await _onFastForward?.call();

  /// Jumps to a queue index.
  Future<void> skipToQueueItem(int index) async => await _onSkipToQueueItem?.call(index);

  /// Changes the playback rate.
  Future<void> setSpeed(double speed) async => await _onSetSpeed?.call(speed);
}
