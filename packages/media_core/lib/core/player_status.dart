import 'package:equatable/equatable.dart';

/// Represents the high-level lifecycle and playback status of a player.
enum PlayerStatus {
  /// The player has not been initialized.
  idle,

  /// The player is being initialized.
  initializing,

  /// The player is ready for playback.
  ready,

  /// The player is opening a media source.
  opening,

  /// The player is buffering media data.
  buffering,

  /// The player is actively playing.
  playing,

  /// Playback is paused.
  paused,

  /// The player is seeking.
  seeking,

  /// The player is stopping.
  stopping,

  /// Playback has stopped.
  stopped,

  /// Playback has completed.
  completed,

  /// The player is in an error state.
  error,

  /// The player is being disposed.
  disposing,

  /// The player has been disposed.
  disposed,
}

/// Represents an immutable snapshot of a player's high-level status.
///
/// [PlayerStatusSnapshot] is intentionally separate from [PlayerState].
/// [PlayerState] represents detailed runtime flags, while this class
/// provides a compact status-oriented view for consumers that only need
/// lifecycle and playback information.
final class PlayerStatusSnapshot extends Equatable {
  /// Creates an immutable player status snapshot.
  const PlayerStatusSnapshot({
    this.status = PlayerStatus.idle,
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isSeeking = false,
    this.isMuted = false,
    this.hasSource = false,
    this.hasError = false,
    this.isDisposed = false,
  });

  /// Current high-level player status.
  final PlayerStatus status;

  /// Whether the player has been initialized.
  final bool isInitialized;

  /// Whether the player is currently playing.
  final bool isPlaying;

  /// Whether the player is currently buffering.
  final bool isBuffering;

  /// Whether the player is currently seeking.
  final bool isSeeking;

  /// Whether audio output is muted.
  final bool isMuted;

  /// Whether a media source is currently attached.
  final bool hasSource;

  /// Whether the player currently has an error.
  final bool hasError;

  /// Whether the player has been disposed.
  final bool isDisposed;

  /// Returns whether the player is idle.
  bool get isIdle => status == PlayerStatus.idle;

  /// Returns whether the player is initializing.
  bool get isInitializing => status == PlayerStatus.initializing;

  /// Returns whether the player is ready.
  bool get isReady => status == PlayerStatus.ready;

  /// Returns whether the player is opening a source.
  bool get isOpening => status == PlayerStatus.opening;

  /// Returns whether the player is buffering.
  bool get isBufferingStatus => status == PlayerStatus.buffering;

  /// Returns whether the player is paused.
  bool get isPaused => status == PlayerStatus.paused;

  /// Returns whether the player is seeking.
  bool get isSeekingStatus => status == PlayerStatus.seeking;

  /// Returns whether the player is stopping.
  bool get isStopping => status == PlayerStatus.stopping;

  /// Returns whether playback has stopped.
  bool get isStopped => status == PlayerStatus.stopped;

  /// Returns whether playback has completed.
  bool get isCompleted => status == PlayerStatus.completed;

  /// Returns whether the player is in an error state.
  bool get isError => status == PlayerStatus.error;

  /// Returns whether the player is being disposed.
  bool get isDisposing => status == PlayerStatus.disposing;

  /// Returns whether the player has been disposed.
  bool get isDisposedStatus => status == PlayerStatus.disposed;

  /// Returns whether the player is in a terminal status.
  bool get isTerminal {
    return status == PlayerStatus.disposed;
  }

  /// Returns whether the player can be used for normal control.
  bool get isUsable {
    return isInitialized && !isDisposed && !isDisposing && !isError;
  }

  /// Returns whether normal playback controls can be used.
  bool get canControl {
    return isUsable && !isOpening && !isStopping;
  }

  /// Returns whether playback is currently active.
  bool get isPlaybackActive {
    return isPlaying || isBuffering || isSeeking || status == PlayerStatus.opening;
  }

  /// Returns whether the player is transitioning between states.
  bool get isTransitioning {
    return isInitializing || isOpening || isSeeking || isStopping || isDisposing;
  }

  /// Creates a copy with updated values.
  ///
  /// Null values retain their existing values.
  PlayerStatusSnapshot copyWith({
    PlayerStatus? status,
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? isSeeking,
    bool? isMuted,
    bool? hasSource,
    bool? hasError,
    bool? isDisposed,
  }) {
    return PlayerStatusSnapshot(
      status: status ?? this.status,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isSeeking: isSeeking ?? this.isSeeking,
      isMuted: isMuted ?? this.isMuted,
      hasSource: hasSource ?? this.hasSource,
      hasError: hasError ?? this.hasError,
      isDisposed: isDisposed ?? this.isDisposed,
    );
  }

  /// Returns a snapshot with the specified status.
  PlayerStatusSnapshot withStatus(PlayerStatus value) {
    return copyWith(status: value);
  }

  /// Returns a snapshot marked as initialized.
  PlayerStatusSnapshot markInitialized() {
    return copyWith(status: PlayerStatus.ready, isInitialized: true, isDisposed: false);
  }

  /// Returns a snapshot marked as uninitialized.
  PlayerStatusSnapshot markUninitialized() {
    return copyWith(
      status: PlayerStatus.idle,
      isInitialized: false,
      isPlaying: false,
      isBuffering: false,
      isSeeking: false,
      isDisposed: false,
    );
  }

  /// Returns a snapshot marked as playing.
  PlayerStatusSnapshot markPlaying() {
    return copyWith(
      status: PlayerStatus.playing,
      isInitialized: true,
      isPlaying: true,
      isBuffering: false,
      isSeeking: false,
      isDisposed: false,
      hasError: false,
    );
  }

  /// Returns a snapshot marked as paused.
  PlayerStatusSnapshot markPaused() {
    return copyWith(
      status: PlayerStatus.paused,
      isInitialized: true,
      isPlaying: false,
      isBuffering: false,
      isSeeking: false,
      isDisposed: false,
    );
  }

  /// Returns a snapshot marked as buffering.
  PlayerStatusSnapshot markBuffering() {
    return copyWith(
      status: PlayerStatus.buffering,
      isInitialized: true,
      isPlaying: false,
      isBuffering: true,
      isSeeking: false,
      isDisposed: false,
    );
  }

  /// Returns a snapshot marked as seeking.
  PlayerStatusSnapshot markSeeking() {
    return copyWith(status: PlayerStatus.seeking, isInitialized: true, isSeeking: true, isDisposed: false);
  }

  /// Returns a snapshot marked as stopped.
  PlayerStatusSnapshot markStopped() {
    return copyWith(status: PlayerStatus.stopped, isPlaying: false, isBuffering: false, isSeeking: false);
  }

  /// Returns a snapshot marked as completed.
  PlayerStatusSnapshot markCompleted() {
    return copyWith(status: PlayerStatus.completed, isPlaying: false, isBuffering: false, isSeeking: false);
  }

  /// Returns a snapshot marked as having an error.
  PlayerStatusSnapshot markError() {
    return copyWith(status: PlayerStatus.error, isPlaying: false, isBuffering: false, isSeeking: false, hasError: true);
  }

  /// Returns a snapshot marked as disposing.
  PlayerStatusSnapshot markDisposing() {
    return copyWith(status: PlayerStatus.disposing, isPlaying: false, isBuffering: false, isSeeking: false);
  }

  /// Returns a snapshot marked as disposed.
  PlayerStatusSnapshot markDisposed() {
    return copyWith(
      status: PlayerStatus.disposed,
      isInitialized: false,
      isPlaying: false,
      isBuffering: false,
      isSeeking: false,
      hasSource: false,
      isDisposed: true,
    );
  }

  /// Returns a snapshot with the requested mute state.
  PlayerStatusSnapshot withMuted(bool value) {
    return copyWith(isMuted: value);
  }

  /// Returns a snapshot with a source attached or detached.
  PlayerStatusSnapshot withSource(bool value) {
    return copyWith(hasSource: value);
  }

  /// Returns a snapshot without an attached source.
  PlayerStatusSnapshot clearSource() {
    return copyWith(hasSource: false, isPlaying: false, isBuffering: false, isSeeking: false);
  }

  /// Returns a snapshot with the current error cleared.
  PlayerStatusSnapshot clearError() {
    return copyWith(hasError: false, status: isError ? PlayerStatus.ready : status);
  }

  /// Returns the default idle status snapshot.
  static const PlayerStatusSnapshot idle = PlayerStatusSnapshot();

  /// Returns whether two snapshots represent the same high-level status.
  bool isSameStatus(PlayerStatusSnapshot other) {
    return status == other.status;
  }

  /// Returns whether two snapshots represent the same playback activity.
  bool isSamePlaybackStatus(PlayerStatusSnapshot other) {
    return isPlaying == other.isPlaying && isBuffering == other.isBuffering && isSeeking == other.isSeeking;
  }

  /// Returns a fully reset status snapshot.
  PlayerStatusSnapshot reset() {
    return const PlayerStatusSnapshot();
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    isInitialized,
    isPlaying,
    isBuffering,
    isSeeking,
    isMuted,
    hasSource,
    hasError,
    isDisposed,
  ];

  @override
  String toString() {
    return 'PlayerStatusSnapshot('
        'status: $status, '
        'isInitialized: $isInitialized, '
        'isPlaying: $isPlaying, '
        'isBuffering: $isBuffering, '
        'isSeeking: $isSeeking, '
        'isMuted: $isMuted, '
        'hasSource: $hasSource, '
        'hasError: $hasError, '
        'isDisposed: $isDisposed'
        ')';
  }
}
