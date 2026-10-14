import 'package:equatable/equatable.dart';
import 'package:media_core/playback/playback_command.dart';
import 'package:media_core/playback/player_transport_state.dart';

/// Immutable playback snapshot.
///
/// Represents a read-only playback state view.
///
/// Used by:
///
/// - PlayerIdentity API
/// - UI layer
/// - Diagnostics
///
/// Does not:
///
/// - execute commands
/// - modify playback
/// - control backend
final class PlaybackSnapshot extends Equatable {
  /// Creates a snapshot from transport fields that were already read.
  ///
  /// `PlaybackSnapshot.fromState()` is the normal entry point; this
  /// constructor exists so a snapshot can be built without holding a
  /// [PlayerTransportState].
  const PlaybackSnapshot({
    required this.command,
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.initialized,
    required this.updatedAt,
    this.buffering = false,
  });

  /// Creates snapshot from state.
  factory PlaybackSnapshot.fromState(PlayerTransportState state) {
    return PlaybackSnapshot(
      command: state.command,
      position: state.position,
      duration: state.duration,
      volume: state.volume,
      rate: state.rate,
      initialized: state.initialized,
      updatedAt: state.updatedAt,
      buffering: state.buffering,
    );
  }

  /// Current command.
  ///
  /// Typed, not `Object`: the predicates below used to read the command's *name*,
  /// and every command in this family is called `PlaybackCommand…` — so asking
  /// "does the name contain Play" answered yes for idle, pause and stop as well.
  final PlaybackCommand command;

  /// Current position.
  final Duration position;

  /// Media duration.
  final Duration duration;

  /// Current volume.
  final double volume;

  /// Current playback rate.
  final double rate;

  /// Whether initialized.
  final bool initialized;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Whether the engine was short of data when this was read.
  final bool buffering;

  /// Whether playing.
  bool get isPlaying => command.isPlaying;

  /// Whether paused.
  bool get isPaused => command.isPaused;

  /// Whether stopped.
  bool get isStopped => command.isStopped;

  /// Whether the transport is at rest, before any command.
  bool get isIdle => command.isIdle;

  /// Whether buffering.
  ///
  /// A condition, not a command: `PlaybackCommand.buffering(value: false)` updates
  /// the transport's flag and leaves the play/pause command alone, so a buffered
  /// stretch is only ever read back from the state it was taken with.
  bool get isBuffering => buffering;

  /// Progress 0-1.
  double get progress {
    if (duration <= Duration.zero) {
      return 0;
    }

    final value = position.inMilliseconds / duration.inMilliseconds;

    if (value < 0) {
      return 0;
    }

    if (value > 1) {
      return 1;
    }

    return value;
  }

  /// Remaining duration.
  Duration get remaining {
    final value = duration - position;

    if (value < Duration.zero) {
      return Duration.zero;
    }

    return value;
  }

  /// The snapshot as plain scalars, with [command] reduced to its type name.
  ///
  /// Times are whole milliseconds, and the command is not reconstructible from
  /// the result — this is a readout for identity, diagnostics and UI, not a
  /// serialization.
  Map<String, dynamic> toMap() {
    return {
      'position': position.inMilliseconds,

      'duration': duration.inMilliseconds,

      'volume': volume,

      'rate': rate,

      'initialized': initialized,

      'updatedAt': updatedAt?.toIso8601String(),

      'buffering': buffering,

      'command': command.runtimeType.toString(),
    };
  }

  @override
  List<Object?> get props => [command, position, duration, volume, rate, initialized, updatedAt, buffering];

  @override
  String toString() {
    return 'PlaybackSnapshot('
        'position=$position, '
        'duration=$duration, '
        'volume=$volume, '
        'rate=$rate)';
  }
}
