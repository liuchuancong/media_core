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
    this.controlsBuilder,
  }) : _onPlay = onPlay,
       _onPause = onPause,
       _onSeek = onSeek,
       _onStop = onStop;

  final Future<void> Function() _onPlay;
  final Future<void> Function() _onPause;
  final Future<void> Function(Duration position) _onSeek;
  final Future<void> Function() _onStop;

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
}
