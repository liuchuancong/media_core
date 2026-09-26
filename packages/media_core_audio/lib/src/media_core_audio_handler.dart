import 'package:audio_service/audio_service.dart';

/// Snapshot of playback state pushed into the media notification.
final class AudioHandlerState {
  /// Creates the snapshot.
  const AudioHandlerState({
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
  });

  /// Whether playback is active.
  final bool playing;

  /// Current playback position.
  final Duration position;

  /// Known media duration.
  final Duration duration;

  /// Current playback speed.
  final double speed;
}

/// Metadata describing the current media item.
final class AudioHandlerMediaItem {
  /// Creates the metadata.
  const AudioHandlerMediaItem({
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
}

/// [BaseAudioHandler] that bridges audio_service and media_core.
///
/// Outbound (kernel → notification): [publishState] and
/// [publishMediaItem] mirror PlayerHandle playback state.
///
/// Inbound (notification → kernel): transport commands are
/// forwarded through the callbacks supplied at construction.
final class MediaCoreAudioHandler extends BaseAudioHandler {
  /// Creates the handler.
  MediaCoreAudioHandler({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration position) onSeek,
    required Future<void> Function() onStop,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
    Future<void> Function(int index)? onSkipToQueueItem,
    Future<void> Function(double rate)? onSetSpeed,
    this.controlsBuilder,
  }) : _onPlay = onPlay,
       _onPause = onPause,
       _onSeek = onSeek,
       _onStop = onStop,
       _onNext = onNext,
       _onPrevious = onPrevious,
       _onSkipToQueueItem = onSkipToQueueItem,
       _onSetSpeed = onSetSpeed;

  final Future<void> Function() _onPlay;
  final Future<void> Function() _onPause;
  final Future<void> Function(Duration position) _onSeek;
  final Future<void> Function() _onStop;
  final Future<void> Function()? _onNext;
  final Future<void> Function()? _onPrevious;
  final Future<void> Function(int index)? _onSkipToQueueItem;
  final Future<void> Function(double rate)? _onSetSpeed;

  /// Whether the platform may offer skip-next.
  bool get canSkipToNext => _onNext != null;

  /// Whether the platform may offer skip-previous.
  bool get canSkipToPrevious => _onPrevious != null;

  /// Optional builder for notification controls.
  ///
  /// Receives the current playing state and returns the controls
  /// to display. When null a play/pause + stop pair is used.
  final List<MediaControl> Function(bool playing)? controlsBuilder;

  /// Builds compact action indices advertised to the platform.
  ///
  /// Derived from [controls] so callers don't have to keep two
  /// lists in sync.
  static List<int> compactIndicesFor(List<MediaControl> controls) {
    if (controls.length <= 2) {
      return List<int>.generate(controls.length, (index) => index);
    }
    return const <int>[0, 1];
  }

  /// Pushes [state] into the media notification.
  void publishState(AudioHandlerState state, {List<MediaControl>? controls}) {
    playbackState.add(
      PlaybackState(
        controls: controls ?? const <MediaControl>[],
        processingState: AudioProcessingState.ready,
        playing: state.playing,
        updatePosition: state.position,
        bufferedPosition: state.duration,
        speed: state.speed,
      ),
    );
  }

  /// Pushes idle state into the media notification.
  void publishIdle() {
    playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
  }

  /// Pushes [item] as the current media item.
  void publishMediaItem(AudioHandlerMediaItem item) {
    mediaItem.add(
      MediaItem(
        id: item.id,
        album: item.album,
        title: item.title,
        artist: item.artist,
        duration: item.duration,
        artUri: item.artUri,
      ),
    );
  }

  /// Clears the current media item.
  void clearMediaItem() {
    mediaItem.add(null);
  }

  /// Publishes the play list so the platform can show and jump through it.
  ///
  /// The playing entry is also published as the current [mediaItem]; the
  /// platform derives "current" from that, not from the list order.
  void publishQueue(List<AudioHandlerMediaItem> items, {int index = -1}) {
    queue.add(
      items
          .map(
            (item) => MediaItem(
              id: item.id,
              album: item.album,
              title: item.title,
              artist: item.artist,
              duration: item.duration,
              artUri: item.artUri,
            ),
          )
          .toList(growable: false),
    );

    if (index >= 0 && index < items.length) {
      publishMediaItem(items[index]);
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound transport commands (notification / lock screen)
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

  @override
  Future<void> skipToNext() async {
    final next = _onNext;

    // Without a queue the sane degrade is the default behavior.
    if (next == null) {
      return super.skipToNext();
    }

    await next();
  }

  @override
  Future<void> skipToPrevious() async {
    final previous = _onPrevious;

    if (previous == null) {
      return super.skipToPrevious();
    }

    await previous();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final skip = _onSkipToQueueItem;

    if (skip == null) {
      return super.skipToQueueItem(index);
    }

    await skip(index);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final setSpeed = _onSetSpeed;

    if (setSpeed == null) {
      return super.setSpeed(speed);
    }

    await setSpeed(speed);
  }
}
