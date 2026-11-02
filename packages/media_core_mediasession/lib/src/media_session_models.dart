import 'dart:async';

import 'package:meta/meta.dart' show immutable;

/// Where the platform session is, as the surfaces draw it.
enum AudioProcessingState {
  /// No session: the surfaces show nothing.
  idle,

  /// The resource is being fetched before it can play.
  loading,

  /// Short of data in the middle of playback.
  buffering,

  /// Enough media is available to play from here.
  ready,

  /// The playhead reached the end of the media.
  completed,

  /// Playback failed.
  error,
}

/// A transport verb the surfaces can offer or send back.
enum MediaAction {
  /// Resume playback.
  play,

  /// Pause playback.
  pause,

  /// Stop playback and end the session.
  stop,

  /// Move the playhead to an absolute position.
  seek,

  /// Jump back by the configured step.
  rewind,

  /// Jump forward by the configured step.
  fastForward,

  /// Skip to the previous queue entry.
  skipToPrevious,

  /// Skip to the next queue entry.
  skipToNext,
}

/// One button the surfaces show.
@immutable
final class MediaControl {
  /// Creates the control.
  const MediaControl({required this.action, required this.label});

  /// What pressing the button sends back.
  final MediaAction action;

  /// Accessible label of the button.
  final String label;

  /// Play.
  static const MediaControl play = MediaControl(action: MediaAction.play, label: 'Play');

  /// Pause.
  static const MediaControl pause = MediaControl(action: MediaAction.pause, label: 'Pause');

  /// Stop.
  static const MediaControl stop = MediaControl(action: MediaAction.stop, label: 'Stop');

  /// Skip to previous.
  static const MediaControl skipToPrevious = MediaControl(action: MediaAction.skipToPrevious, label: 'Previous');

  /// Skip to next.
  static const MediaControl skipToNext = MediaControl(action: MediaAction.skipToNext, label: 'Next');

  /// Rewind.
  static const MediaControl rewind = MediaControl(action: MediaAction.rewind, label: 'Rewind');

  /// Fast forward.
  static const MediaControl fastForward = MediaControl(action: MediaAction.fastForward, label: 'Fast forward');

  @override
  bool operator ==(Object other) => other is MediaControl && other.action == action && other.label == label;

  @override
  int get hashCode => Object.hash(action, label);

  @override
  String toString() => 'MediaControl(${action.name})';
}

/// The media item the surfaces describe.
final class MediaItem {
  /// Creates the item.
  const MediaItem({required this.id, required this.title, this.album, this.artist, this.duration, this.artUri});

  /// Stable media identifier.
  final String id;

  /// Display title.
  final String title;

  /// Display album.
  final String? album;

  /// Display artist.
  final String? artist;

  /// Media duration when known.
  final Duration? duration;

  /// Artwork the surfaces can open.
  final Uri? artUri;
}

/// The playback state the surfaces describe.
final class PlaybackState {
  /// Creates the state; the defaults are an idle, empty session.
  const PlaybackState({
    this.controls = const <MediaControl>[],
    this.processingState = AudioProcessingState.idle,
    this.playing = false,
    this.updatePosition = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1,
  });

  /// Buttons offered right now.
  final List<MediaControl> controls;

  /// What the transport is doing.
  final AudioProcessingState processingState;

  /// Whether playback is active.
  final bool playing;

  /// Position at the moment of publishing.
  final Duration updatePosition;

  /// How far media is available.
  final Duration bufferedPosition;

  /// Playback rate.
  final double speed;
}

/// A value that is always readable and replayed to every new listener.
///
/// The surfaces are state, not events: a page that starts observing late must
/// see what is on the lock screen now, not wait for the next change.
final class MediaSessionValue<T> {
  /// Creates the value with [initial] as the current one.
  MediaSessionValue(T initial) : _value = initial;

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast(sync: true);

  /// The current value.
  T get value => _value;

  /// Replaces the value and tells every listener.
  void add(T next) {
    _value = next;
    _changes.add(next);
  }

  /// The current value followed by every change.
  Stream<T> get stream => Stream<T>.multi((controller) {
    controller.add(_value);
    final subscription = _changes.stream.listen(controller.add, onError: controller.addError);
    controller.onCancel = subscription.cancel;
  });

  /// Shorthand for `stream.listen`.
  StreamSubscription<T> listen(void Function(T value) onData, {Function? onError, void Function()? onDone}) {
    return stream.listen(onData, onError: onError, onDone: onDone);
  }
}
