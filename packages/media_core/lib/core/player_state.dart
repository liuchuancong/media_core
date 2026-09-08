import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_state.freezed.dart';
part 'player_state.g.dart';

/// Represents the immutable runtime state of a player.
///
/// [PlayerState] describes playback, media, presentation, recording,
/// recovery, and lifecycle state without owning any mutable controller
/// or backend resources.
@freezed
abstract class PlayerState with _$PlayerState {
  /// Creates an immutable player state.
  const factory PlayerState({
    /// Whether the player has been initialized.
    @Default(false) bool initialized,

    /// Whether the player is currently opening a source.
    @Default(false) bool opening,

    /// Whether the player is ready for playback.
    @Default(false) bool ready,

    /// Whether the player is currently playing.
    @Default(false) bool playing,

    /// Whether playback is currently paused.
    @Default(false) bool paused,

    /// Whether the player is currently buffering.
    @Default(false) bool buffering,

    /// Whether the player is currently seeking.
    @Default(false) bool seeking,

    /// Whether the player is currently stopping.
    @Default(false) bool stopping,

    /// Whether the player has stopped playback.
    @Default(false) bool stopped,

    /// Whether playback reached the end of the current media.
    @Default(false) bool completed,

    /// Whether the player is being disposed.
    @Default(false) bool disposing,

    /// Whether the player has been disposed.
    @Default(false) bool disposed,

    /// Whether a media source is currently associated with the player.
    @Default(false) bool hasSource,

    /// Whether the player currently contains an error.
    @Default(false) bool hasError,

    /// Whether audio output is muted.
    @Default(false) bool muted,

    /// Whether audio output is enabled.
    @Default(false) bool audioEnabled,

    /// Whether video output is enabled.
    @Default(false) bool videoEnabled,

    /// Whether subtitle output is enabled.
    @Default(false) bool subtitlesEnabled,

    /// Whether the player is currently in fullscreen presentation.
    @Default(false) bool fullscreen,

    /// Whether the player is currently in picture-in-picture mode.
    @Default(false) bool pip,

    /// Whether the player is currently displayed in a floating mode.
    @Default(false) bool floating,

    /// Whether recording is currently active.
    @Default(false) bool recording,

    /// Whether the player is currently recovering from a failure.
    @Default(false) bool recovering,

    /// Whether the player is currently switching through a fallback.
    @Default(false) bool fallingBack,
  }) = _PlayerState;

  const PlayerState._();

  /// Creates a player state from JSON.
  factory PlayerState.fromJson(Map<String, Object?> json) => _$PlayerStateFromJson(json);

  /// Returns the default idle player state.
  static const PlayerState idle = PlayerState();

  /// Returns whether the player is completely idle.
  bool get isIdle {
    return !initialized &&
        !opening &&
        !ready &&
        !playing &&
        !paused &&
        !buffering &&
        !seeking &&
        !stopping &&
        !stopped &&
        !completed &&
        !disposing &&
        !disposed &&
        !recovering &&
        !fallingBack;
  }

  /// Returns whether the player is actively processing playback.
  bool get isActive {
    return playing || buffering || seeking || opening || recovering || fallingBack;
  }

  /// Returns whether the player is actively playing or buffering.
  bool get isPlaybackActive {
    return playing || buffering || seeking;
  }

  /// Returns whether the player is currently transitioning between states.
  bool get isTransitioning {
    return opening || seeking || stopping || disposing || recovering || fallingBack;
  }

  /// Returns whether the player has reached a terminal lifecycle state.
  bool get isTerminal {
    return disposed;
  }

  /// Returns whether the player can accept normal control commands.
  bool get canControl {
    return initialized && !disposing && !disposed && !opening && !stopping;
  }

  /// Returns whether playback can currently be started.
  bool get canPlay {
    return canControl && hasSource && !playing && !buffering && !seeking;
  }

  /// Returns whether playback can currently be paused.
  bool get canPause {
    return canControl && playing;
  }

  /// Returns whether seeking is currently possible.
  bool get canSeek {
    return canControl && hasSource && !stopping && !disposed;
  }

  /// Returns whether the player can currently be stopped.
  bool get canStop {
    return canControl && (playing || paused || buffering || seeking || opening);
  }

  /// Returns whether the player has an audio output.
  bool get hasAudioOutput {
    return audioEnabled;
  }

  /// Returns whether the player has a video output.
  bool get hasVideoOutput {
    return videoEnabled;
  }

  /// Returns whether the player currently has a presentation mode.
  bool get hasPresentation {
    return fullscreen || pip || floating;
  }

  /// Returns whether the current state represents audio-only playback.
  bool get isAudioOnly {
    return audioEnabled && !videoEnabled;
  }

  /// Returns whether the current state represents video-only playback.
  bool get isVideoOnly {
    return videoEnabled && !audioEnabled;
  }

  /// Returns whether both audio and video outputs are enabled.
  bool get isAudioVideo {
    return audioEnabled && videoEnabled;
  }

  /// Returns whether the state is clean and contains no active error.
  bool get isClean {
    return !hasError && !recovering && !fallingBack && !disposed;
  }

  /// Returns a state marked as initialized.
  PlayerState initializedState() {
    return copyWith(initialized: true, disposed: false, disposing: false);
  }

  /// Returns a state marked as opening.
  PlayerState openingState() {
    return copyWith(opening: true, ready: false, completed: false, stopped: false, hasError: false);
  }

  /// Returns a state marked as ready.
  PlayerState readyState() {
    return copyWith(initialized: true, opening: false, ready: true, stopped: false, completed: false, hasError: false);
  }

  /// Returns a state marked as playing.
  PlayerState playingState() {
    return copyWith(
      initialized: true,
      opening: false,
      ready: true,
      playing: true,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: false,
      completed: false,
      hasError: false,
    );
  }

  /// Returns a state marked as paused.
  PlayerState pausedState() {
    return copyWith(
      initialized: true,
      opening: false,
      ready: true,
      playing: false,
      paused: true,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: false,
      hasError: false,
    );
  }

  /// Returns a state marked as buffering.
  PlayerState bufferingState() {
    return copyWith(
      initialized: true,
      opening: false,
      ready: true,
      playing: false,
      paused: false,
      buffering: true,
      seeking: false,
      stopping: false,
      stopped: false,
      completed: false,
    );
  }

  /// Returns a state marked as seeking.
  PlayerState seekingState() {
    return copyWith(initialized: true, opening: false, ready: true, seeking: true, stopped: false, completed: false);
  }

  /// Returns a state marked as stopping.
  PlayerState stoppingState() {
    return copyWith(stopping: true, playing: false, paused: false, buffering: false, seeking: false);
  }

  /// Returns a state marked as stopped.
  PlayerState stoppedState() {
    return copyWith(
      opening: false,
      playing: false,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: true,
      completed: false,
      recovering: false,
      fallingBack: false,
    );
  }

  /// Returns a state marked as completed.
  PlayerState completedState() {
    return copyWith(
      opening: false,
      playing: false,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: false,
      completed: true,
    );
  }

  /// Returns a state marked as having an error.
  PlayerState errorState() {
    return copyWith(
      playing: false,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      hasError: true,
      recovering: false,
      fallingBack: false,
    );
  }

  /// Returns a state marked as recovering.
  PlayerState recoveringState() {
    return copyWith(
      hasError: true,
      recovering: true,
      fallingBack: false,
      playing: false,
      buffering: false,
      seeking: false,
    );
  }

  /// Returns a state marked as falling back.
  PlayerState fallbackState() {
    return copyWith(
      hasError: true,
      recovering: false,
      fallingBack: true,
      playing: false,
      buffering: false,
      seeking: false,
    );
  }

  /// Returns a state marked as disposing.
  PlayerState disposingState() {
    return copyWith(disposing: true, playing: false, paused: false, buffering: false, seeking: false, stopping: false);
  }

  /// Returns a state marked as disposed.
  PlayerState disposedState() {
    return copyWith(
      initialized: false,
      opening: false,
      ready: false,
      playing: false,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: true,
      completed: false,
      disposing: false,
      disposed: true,
      hasSource: false,
      hasError: false,
      fullscreen: false,
      pip: false,
      floating: false,
      recording: false,
      recovering: false,
      fallingBack: false,
    );
  }

  /// Returns a state associated with a media source.
  PlayerState withSource(bool value) {
    return copyWith(hasSource: value, completed: value ? completed : false, stopped: value ? stopped : false);
  }

  /// Returns a state with the requested mute state.
  PlayerState withMuted(bool value) {
    return copyWith(muted: value);
  }

  /// Returns a state with audio output enabled or disabled.
  PlayerState withAudioEnabled(bool value) {
    return copyWith(audioEnabled: value);
  }

  /// Returns a state with video output enabled or disabled.
  PlayerState withVideoEnabled(bool value) {
    return copyWith(videoEnabled: value);
  }

  /// Returns a state with subtitles enabled or disabled.
  PlayerState withSubtitlesEnabled(bool value) {
    return copyWith(subtitlesEnabled: value);
  }

  /// Returns a state with fullscreen enabled or disabled.
  PlayerState withFullscreen(bool value) {
    return copyWith(fullscreen: value);
  }

  /// Returns a state with picture-in-picture enabled or disabled.
  PlayerState withPip(bool value) {
    return copyWith(pip: value);
  }

  /// Returns a state with floating presentation enabled or disabled.
  PlayerState withFloating(bool value) {
    return copyWith(floating: value);
  }

  /// Returns a state with recording enabled or disabled.
  PlayerState withRecording(bool value) {
    return copyWith(recording: value);
  }

  /// Returns a state with the current error cleared.
  PlayerState clearError() {
    return copyWith(hasError: false, recovering: false, fallingBack: false);
  }

  /// Resets playback-related flags while preserving initialization.
  PlayerState resetPlayback() {
    return copyWith(
      opening: false,
      playing: false,
      paused: false,
      buffering: false,
      seeking: false,
      stopping: false,
      stopped: false,
      completed: false,
      hasError: false,
      recovering: false,
      fallingBack: false,
    );
  }

  /// Resets presentation-related flags.
  PlayerState resetPresentation() {
    return copyWith(fullscreen: false, pip: false, floating: false);
  }

  /// Returns the completely idle state.
  PlayerState reset() {
    return PlayerState(audioEnabled: audioEnabled, videoEnabled: videoEnabled, subtitlesEnabled: subtitlesEnabled);
  }
}
