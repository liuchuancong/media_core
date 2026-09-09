import 'playback_command.dart';
import 'package:equatable/equatable.dart';

/// Current playback runtime state.
///
/// Owned by:
///
/// - PlaybackController
///
/// Used by:
///
/// - Player
/// - Renderer
/// - UI
///
/// Does not:
///
/// - control backend
/// - call platform APIs
/// - manage decoder
final class PlaybackState extends Equatable {
  const PlaybackState({
    required this.command,
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.initialized,
    required this.updatedAt,
  });

  /// Initial state.
  const PlaybackState.initial()
    : command = const PlaybackCommand.idle(),
      position = Duration.zero,
      duration = Duration.zero,
      volume = 1.0,
      rate = 1.0,
      initialized = false,
      updatedAt = null;

  /// Current playback command/state.
  final PlaybackCommand command;

  /// Current position.
  final Duration position;

  /// Media duration.
  final Duration duration;

  /// Volume 0.0 - 1.0.
  final double volume;

  /// Playback speed.
  final double rate;

  /// Whether playback initialized.
  final bool initialized;

  /// Last state update.
  final DateTime? updatedAt;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  bool get isIdle => command.isIdle;

  bool get isLoading => command.isLoading;

  bool get isPlaying => command.isPlaying;

  bool get isPaused => command.isPaused;

  bool get isStopped => command.isStopped;

  bool get isCompleted => command.isCompleted;

  bool get isBuffering => command.isBuffering;

  bool get hasDuration => duration > Duration.zero;

  bool get hasPosition => position > Duration.zero;

  double get progress {
    if (!hasDuration) {
      return 0;
    }

    return position.inMilliseconds / duration.inMilliseconds;
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  PlaybackState copyWith({
    PlaybackCommand? command,
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    bool? initialized,
    DateTime? updatedAt,
  }) {
    return PlaybackState(
      command: command ?? this.command,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      initialized: initialized ?? this.initialized,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Reduce command.
  PlaybackState reduce(PlaybackCommand command) {
    switch (command) {
      case PlaybackCommandPlay():
        return copyWith(command: command, initialized: true, updatedAt: DateTime.now());

      case PlaybackCommandPause():
        return copyWith(command: command, updatedAt: DateTime.now());

      case PlaybackCommandStop():
        return copyWith(command: command, position: Duration.zero, updatedAt: DateTime.now());

      case PlaybackCommandBuffering():
        return copyWith(command: command, updatedAt: DateTime.now());

      case PlaybackCommandLoading():
        return copyWith(command: command, updatedAt: DateTime.now());

      case PlaybackCommandSeek():
        return copyWith(position: command.position, updatedAt: DateTime.now());

      case PlaybackCommandPosition():
        return copyWith(position: command.position, updatedAt: DateTime.now());

      case PlaybackCommandDuration():
        return copyWith(duration: command.duration, updatedAt: DateTime.now());

      case PlaybackCommandVolume():
        return copyWith(volume: command.volume, updatedAt: DateTime.now());

      case PlaybackCommandRate():
        return copyWith(rate: command.rate, updatedAt: DateTime.now());

      case PlaybackCommandIdle():
        return copyWith(command: command, updatedAt: DateTime.now());
    }
  }

  @override
  List<Object?> get props => [command, position, duration, volume, rate, initialized, updatedAt];

  @override
  String toString() {
    return 'PlaybackState('
        'command=$command, '
        'position=$position, '
        'duration=$duration, '
        'volume=$volume, '
        'rate=$rate)';
  }
}
