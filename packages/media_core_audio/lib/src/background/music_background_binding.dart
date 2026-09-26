import 'dart:async';

import '../player/audio_playback_controller.dart';
import '../player/audio_player_state.dart';
import '../track/music_track.dart';
import '../media_core_audio.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

/// Connects an [AudioPlaybackController] to the platform's background playback
/// surfaces.
///
/// Background playback is three separate things, and this binding does all of
/// them:
///
/// 1. **The player keeps running off-screen.** Nothing to do here — the engine
///    is the same one used in the foreground.
/// 2. **The system surface shows the right thing.** The notification/lock
///    screen/SMTC/MPRIS gets the music metadata (title, artist, album, cover)
///    instead of a file name, plus the queue, so the platform's own "next"
///    works.
/// 3. **Transport commands come back.** Play/pause/seek/next/previous from the
///    notification, the lock screen, a headset button or a media key all reach
///    the controller through this binding.
///
/// Audio focus and interruptions stay the capability driver's job
/// ([MediaCoreAudio] itself) — this binding only installs the queue transports
/// and mirrors state.
///
/// ```dart
/// final audio = await MediaSessionBootstrap.enable();
/// await audio.initialize();
/// final player = AudioPlaybackController(kernel);
/// final background = MusicBackgroundBinding(player, audio)..attach();
/// ```
final class MusicBackgroundBinding {
  /// Creates a binding.
  MusicBackgroundBinding(this.player, this.audio);

  /// The music player to mirror.
  final AudioPlaybackController player;

  /// The platform capability driver to publish through.
  ///
  /// The shared [MediaSessionDriver], which the app may have enabled once for
  /// the whole process ([MediaSessionBootstrap.enable]) — the binding does not
  /// need the music module's subclass for anything.
  final MediaSessionDriver audio;

  StreamSubscription<AudioPlaybackState>? _stateSub;

  bool _attached = false;
  bool _disposed = false;

  /// Whether the binding is installed.
  bool get attached => _attached;

  /// Installs the transports and starts mirroring.
  ///
  /// Safe to call before the first track plays: the handle is created lazily by
  /// the controller, and the binding picks it up as soon as it exists.
  void attach() {
    if (_attached || _disposed) {
      return;
    }

    _attached = true;

    // Assigned one by one, not as a cascade: `..x = () => y() ..z = w` parses
    // the following section as part of the lambda body, silently turning the
    // cascade into a cascade on the lambda's return value.
    audio.skipToNextHandler = () => player.next();
    audio.skipToPreviousHandler = player.previous;
    audio.skipToQueueItemHandler = player.playAt;
    audio.setSpeedHandler = player.setRate;

    _stateSub = player.stateStream.listen(_onState);

    // The current snapshot may already describe a playing track.
    _onState(player.state);
  }

  /// Removes the transports and stops mirroring.
  void detach() {
    if (!_attached) {
      return;
    }

    _attached = false;

    audio.skipToNextHandler = null;
    audio.skipToPreviousHandler = null;
    audio.skipToQueueItemHandler = null;
    audio.setSpeedHandler = null;

    _stateSub?.cancel();
    _stateSub = null;
  }

  /// Releases the binding.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    detach();
  }

  void _onState(AudioPlaybackState state) {
    if (_disposed) {
      return;
    }

    final handle = player.handle;

    // The capability driver follows "the active player"; the controller's
    // handle appears on first playback, so it is attached here rather than at
    // construction.
    if (handle != null && !handle.disposed && !identical(audio.active, handle)) {
      audio.setActive(handle);
    }

    final handler = audio.handler;

    if (handler == null) {
      return;
    }

    final track = state.track;

    if (track == null) {
      handler.publishIdle();
      handler.clearMediaItem();

      return;
    }

    handler.publishMediaItem(_itemFor(track, state));

    if (state.queueLength > 0) {
      handler.publishQueue(
        player.queue.tracks.map((item) => _itemFor(item, state)).toList(growable: false),
        index: state.index,
      );
    }

    // No explicit controls: the handler builds them from the transports that
    // are installed, so installing/removing skip support never needs a second
    // list kept in sync here.
    handler.publishState(
      MediaSessionState(
        playing: state.playing,
        position: state.position,
        duration: state.duration,
        speed: state.rate,
      ),
    );
  }

  MediaSessionItem _itemFor(MusicTrack track, AudioPlaybackState state) {
    final isCurrent = identical(track, state.track) || track == state.track;

    return MediaSessionItem(
      id: '${track.sourceId}:${track.id}',
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: track.coverUri,
      duration: isCurrent && state.duration > Duration.zero ? state.duration : track.duration,
    );
  }
}
