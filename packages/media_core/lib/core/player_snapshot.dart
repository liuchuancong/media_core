import 'media_type.dart';
import 'player_state.dart';
import 'player_status.dart';
import 'player_metrics.dart';
import 'player_options.dart';
import 'media_capabilities.dart';
import 'player_capabilities.dart';
import '../identity/player_id.dart';
import '../identity/source_id.dart';
import '../identity/request_id.dart';
import '../identity/session_id.dart';
import '../identity/generation_id.dart';
import 'package:equatable/equatable.dart';

/// Represents an immutable point-in-time snapshot of a player.
///
/// [PlayerSnapshot] combines player identity, media information, runtime
/// state, status, configuration, capabilities, and metrics into one object.
///
/// Snapshots are intended for observation, diagnostics, synchronization,
/// reconciliation, and state publication. They do not own player resources
/// and must not directly control a backend.
final class PlayerSnapshot extends Equatable {
  /// Creates an immutable player snapshot.
  const PlayerSnapshot({
    required this.playerId,
    this.sessionId,
    this.requestId,
    this.generationId,
    this.sourceId,
    this.mediaType,
    this.mediaCapabilities,
    this.state,
    this.status,
    this.options = PlayerOptions.defaults,
    this.capabilities = PlayerCapabilities.basic,
    this.metrics,
    this.timestamp,
  });

  /// Unique identifier of the player represented by this snapshot.
  final PlayerId playerId;

  /// Identifier of the active player session.
  final SessionId? sessionId;

  /// Identifier of the request associated with the current operation.
  final RequestId? requestId;

  /// Identifier of the current player generation.
  final GenerationId? generationId;

  /// Identifier of the current media source.
  final SourceId? sourceId;

  /// Media type of the current source.
  final MediaType? mediaType;

  /// Media-level capabilities detected for the current source.
  final MediaCapabilities? mediaCapabilities;

  /// Detailed immutable player runtime state.
  final PlayerState? state;

  /// High-level player status.
  final PlayerStatusSnapshot? status;

  /// Current player options.
  final PlayerOptions options;

  /// Capabilities exposed by the player implementation.
  final PlayerCapabilities capabilities;

  /// Optional runtime metrics associated with the snapshot.
  final PlayerMetrics? metrics;

  /// Time at which this snapshot was created.
  final DateTime? timestamp;

  /// Returns whether a session is associated with this snapshot.
  bool get hasSession => sessionId != null;

  /// Returns whether a request is associated with this snapshot.
  bool get hasRequest => requestId != null;

  /// Returns whether a generation is associated with this snapshot.
  bool get hasGeneration => generationId != null;

  /// Returns whether a source is associated with this snapshot.
  bool get hasSource => sourceId != null;

  /// Returns whether media type information is available.
  bool get hasMediaType => mediaType != null;

  /// Returns whether media capability information is available.
  bool get hasMediaCapabilities => mediaCapabilities != null;

  /// Returns whether detailed runtime state is available.
  bool get hasState => state != null;

  /// Returns whether high-level status information is available.
  bool get hasStatus => status != null;

  /// Returns whether runtime metrics are available.
  bool get hasMetrics => metrics != null;

  /// Returns the current player status.
  PlayerStatus get playerStatus {
    return status?.status ?? PlayerStatus.idle;
  }

  /// Returns whether the player is initialized.
  bool get isInitialized {
    return state?.initialized ?? status?.isInitialized ?? false;
  }

  /// Returns whether the player is ready.
  bool get isReady {
    return state?.ready ?? status?.isReady ?? false;
  }

  /// Returns whether the player is currently opening a source.
  bool get isOpening {
    return state?.opening ?? status?.isOpening ?? false;
  }

  /// Returns whether the player is currently playing.
  bool get isPlaying {
    return state?.playing ?? status?.isPlaying ?? false;
  }

  /// Returns whether the player is currently paused.
  bool get isPaused {
    return state?.paused ?? status?.isPaused ?? false;
  }

  /// Returns whether the player is buffering.
  bool get isBuffering {
    return state?.buffering ?? status?.isBuffering ?? false;
  }

  /// Returns whether the player is seeking.
  bool get isSeeking {
    return state?.seeking ?? status?.isSeeking ?? false;
  }

  /// Returns whether the player is stopping.
  bool get isStopping {
    return state?.stopping ?? status?.isStopping ?? false;
  }

  /// Returns whether playback has completed.
  bool get isCompleted {
    return state?.completed ?? status?.isCompleted ?? false;
  }

  /// Returns whether the player has an error.
  bool get hasError {
    return state?.hasError ?? status?.hasError ?? false;
  }

  /// Returns whether the player is being disposed.
  bool get isDisposing {
    return state?.disposing ?? status?.isDisposing ?? false;
  }

  /// Returns whether the player has been disposed.
  bool get isDisposed {
    return state?.disposed ?? status?.isDisposed ?? false;
  }

  /// Returns whether audio output is enabled.
  bool get hasAudio {
    return mediaCapabilities?.hasAudio ?? mediaType?.hasAudio ?? state?.audioEnabled ?? options.enableAudio;
  }

  /// Returns whether video output is enabled.
  bool get hasVideo {
    return mediaCapabilities?.hasVideo ?? mediaType?.hasVideo ?? state?.videoEnabled ?? options.enableVideo;
  }

  /// Returns whether the player is muted.
  bool get isMuted {
    return state?.muted ?? status?.isMuted ?? options.muted;
  }

  /// Returns whether the current media is audio-only.
  bool get isAudioOnly {
    final capabilities = mediaCapabilities;
    if (capabilities != null) {
      return capabilities.isAudioOnly;
    }

    final type = mediaType;
    if (type != null) {
      return type.isAudioOnly;
    }

    return hasAudio && !hasVideo;
  }

  /// Returns whether the current media is video-only.
  bool get isVideoOnly {
    final capabilities = mediaCapabilities;
    if (capabilities != null) {
      return capabilities.isVideoOnly;
    }

    final type = mediaType;
    if (type != null) {
      return type.isVideoOnly;
    }

    return hasVideo && !hasAudio;
  }

  /// Returns whether the current media contains audio and video.
  bool get isAudioVideo {
    final capabilities = mediaCapabilities;
    if (capabilities != null) {
      return capabilities.isAudioVideo;
    }

    final type = mediaType;
    if (type != null) {
      return type.isAudioVideo;
    }

    return hasAudio && hasVideo;
  }

  /// Returns whether the current media requires a video renderer.
  bool get requiresVideoRenderer {
    return mediaCapabilities?.requiresVideoRenderer ?? mediaType?.requiresVideoRenderer ?? hasVideo;
  }

  /// Returns whether any media information is available.
  bool get hasAnyMedia {
    return hasAudio || hasVideo;
  }

  /// Returns whether the player currently has a presentation mode active.
  bool get hasPresentation {
    return state?.hasPresentation ?? false;
  }

  /// Returns whether the player is in fullscreen mode.
  bool get isFullscreen {
    return state?.fullscreen ?? false;
  }

  /// Returns whether the player is in picture-in-picture mode.
  bool get isPip {
    return state?.pip ?? false;
  }

  /// Returns whether the player is in floating mode.
  bool get isFloating {
    return state?.floating ?? false;
  }

  /// Returns whether recording is currently active.
  bool get isRecording {
    return state?.recording ?? false;
  }

  /// Returns whether recovery is currently active.
  bool get isRecovering {
    return state?.recovering ?? false;
  }

  /// Returns whether fallback is currently active.
  bool get isFallingBack {
    return state?.fallingBack ?? false;
  }

  /// Returns whether the player can currently be controlled.
  bool get canControl {
    return status?.canControl ?? state?.canControl ?? false;
  }

  /// Returns whether playback can currently be started.
  bool get canPlay {
    return status != null ? status!.canControl && hasSource && !isPlaying && !isBuffering : state?.canPlay ?? false;
  }

  /// Returns whether playback can currently be paused.
  bool get canPause {
    return state?.canPause ?? (status?.canControl == true && isPlaying);
  }

  /// Returns whether seeking is currently supported.
  bool get canSeek {
    return capabilities.canSeek && (mediaCapabilities?.supportsSeeking ?? true);
  }

  /// Returns whether the player supports recovery.
  bool get canRecover {
    return capabilities.canRecover && options.canRecover;
  }

  /// Returns whether the player supports fallback.
  bool get canFallback {
    return capabilities.canFallback && options.canFallback;
  }

  /// Returns a copy with selectively replaced values.
  ///
  /// Null values retain the existing values.
  PlayerSnapshot copyWith({
    PlayerId? playerId,
    SessionId? sessionId,
    RequestId? requestId,
    GenerationId? generationId,
    SourceId? sourceId,
    MediaType? mediaType,
    MediaCapabilities? mediaCapabilities,
    PlayerState? state,
    PlayerStatusSnapshot? status,
    PlayerOptions? options,
    PlayerCapabilities? capabilities,
    PlayerMetrics? metrics,
    DateTime? timestamp,
  }) {
    return PlayerSnapshot(
      playerId: playerId ?? this.playerId,
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      generationId: generationId ?? this.generationId,
      sourceId: sourceId ?? this.sourceId,
      mediaType: mediaType ?? this.mediaType,
      mediaCapabilities: mediaCapabilities ?? this.mediaCapabilities,
      state: state ?? this.state,
      status: status ?? this.status,
      options: options ?? this.options,
      capabilities: capabilities ?? this.capabilities,
      metrics: metrics ?? this.metrics,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Returns a snapshot associated with the supplied session.
  PlayerSnapshot withSession(SessionId value) {
    return copyWith(sessionId: value);
  }

  /// Returns a snapshot associated with the supplied request.
  PlayerSnapshot withRequest(RequestId value) {
    return copyWith(requestId: value);
  }

  /// Returns a snapshot associated with the supplied generation.
  PlayerSnapshot withGeneration(GenerationId value) {
    return copyWith(generationId: value);
  }

  /// Returns a snapshot associated with the supplied source.
  PlayerSnapshot withSource(SourceId value) {
    return copyWith(sourceId: value);
  }

  /// Returns a snapshot with the supplied media type.
  PlayerSnapshot withMediaType(MediaType value) {
    return copyWith(mediaType: value);
  }

  /// Returns a snapshot with the supplied media capabilities.
  PlayerSnapshot withMediaCapabilities(MediaCapabilities value) {
    return copyWith(mediaCapabilities: value);
  }

  /// Returns a snapshot with the supplied player state.
  PlayerSnapshot withState(PlayerState value) {
    return copyWith(state: value);
  }

  /// Returns a snapshot with the supplied player status.
  PlayerSnapshot withStatus(PlayerStatusSnapshot value) {
    return copyWith(status: value);
  }

  /// Returns a snapshot with the supplied player options.
  PlayerSnapshot withOptions(PlayerOptions value) {
    return copyWith(options: value);
  }

  /// Returns a snapshot with the supplied player capabilities.
  PlayerSnapshot withCapabilities(PlayerCapabilities value) {
    return copyWith(capabilities: value);
  }

  /// Returns a snapshot with the supplied metrics.
  PlayerSnapshot withMetrics(PlayerMetrics value) {
    return copyWith(metrics: value);
  }

  /// Returns a snapshot with the supplied timestamp.
  PlayerSnapshot withTimestamp(DateTime value) {
    return copyWith(timestamp: value);
  }

  /// Returns a snapshot without a session association.
  PlayerSnapshot withoutSession() {
    return PlayerSnapshot(
      playerId: playerId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      state: state,
      status: status,
      options: options,
      capabilities: capabilities,
      metrics: metrics,
      timestamp: timestamp,
    );
  }

  /// Returns a snapshot without a request association.
  PlayerSnapshot withoutRequest() {
    return PlayerSnapshot(
      playerId: playerId,
      sessionId: sessionId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      state: state,
      status: status,
      options: options,
      capabilities: capabilities,
      metrics: metrics,
      timestamp: timestamp,
    );
  }

  /// Returns a snapshot without a generation association.
  PlayerSnapshot withoutGeneration() {
    return PlayerSnapshot(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      state: state,
      status: status,
      options: options,
      capabilities: capabilities,
      metrics: metrics,
      timestamp: timestamp,
    );
  }

  /// Returns a snapshot without a source association.
  PlayerSnapshot withoutSource() {
    return PlayerSnapshot(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      state: state,
      status: status,
      options: options.withoutSource(),
      capabilities: capabilities,
      metrics: metrics,
      timestamp: timestamp,
    );
  }

  /// Returns a snapshot without media type information.
  PlayerSnapshot withoutMediaType() {
    return copyWith(mediaType: MediaType.unknown);
  }

  /// Returns a snapshot without media capability information.
  PlayerSnapshot withoutMediaCapabilities() {
    return copyWith(mediaCapabilities: MediaCapabilities.unknown);
  }

  /// Returns a snapshot without runtime metrics.
  PlayerSnapshot withoutMetrics() {
    return PlayerSnapshot(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      state: state,
      status: status,
      options: options,
      capabilities: capabilities,
      timestamp: timestamp,
    );
  }

  /// Returns this snapshot as an idle snapshot while preserving identity.
  PlayerSnapshot asIdle() {
    return copyWith(state: PlayerState.idle, status: PlayerStatusSnapshot.idle);
  }

  /// Returns this snapshot as a disposed snapshot.
  ///
  /// The player identity is intentionally preserved so consumers can
  /// associate the terminal snapshot with the original player instance.
  PlayerSnapshot asDisposed() {
    return copyWith(
      state: (state ?? PlayerState.idle).copyWith(
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
      ),
      status: (status ?? PlayerStatusSnapshot.idle).markDisposed(),
    );
  }

  /// Returns whether this snapshot belongs to the same player.
  bool isSamePlayer(PlayerSnapshot other) {
    return playerId == other.playerId;
  }

  /// Returns whether this snapshot belongs to the same session.
  bool isSameSession(PlayerSnapshot other) {
    return sessionId != null && other.sessionId != null && sessionId == other.sessionId;
  }

  /// Returns whether this snapshot belongs to the same source.
  bool isSameSource(PlayerSnapshot other) {
    return sourceId != null && other.sourceId != null && sourceId == other.sourceId;
  }

  /// Returns whether this snapshot belongs to the same generation.
  bool isSameGeneration(PlayerSnapshot other) {
    return generationId != null && other.generationId != null && generationId == other.generationId;
  }

  /// Returns whether the snapshots represent the same playback state.
  bool isSamePlaybackState(PlayerSnapshot other) {
    return isPlaying == other.isPlaying &&
        isPaused == other.isPaused &&
        isBuffering == other.isBuffering &&
        isSeeking == other.isSeeking &&
        isCompleted == other.isCompleted;
  }

  /// Returns whether the snapshots represent the same media.
  bool isSameMedia(PlayerSnapshot other) {
    return mediaType == other.mediaType && mediaCapabilities == other.mediaCapabilities;
  }

  /// Returns whether this snapshot is newer than [other].
  ///
  /// Snapshots without timestamps are considered incomparable and return
  /// `false`.
  bool isNewerThan(PlayerSnapshot other) {
    final currentTimestamp = timestamp;
    final otherTimestamp = other.timestamp;

    if (currentTimestamp == null || otherTimestamp == null) {
      return false;
    }

    return currentTimestamp.isAfter(otherTimestamp);
  }

  /// Returns whether this snapshot is older than [other].
  ///
  /// Snapshots without timestamps are considered incomparable and return
  /// `false`.
  bool isOlderThan(PlayerSnapshot other) {
    final currentTimestamp = timestamp;
    final otherTimestamp = other.timestamp;

    if (currentTimestamp == null || otherTimestamp == null) {
      return false;
    }

    return currentTimestamp.isBefore(otherTimestamp);
  }

  /// Creates an empty snapshot for [playerId].
  static PlayerSnapshot empty(PlayerId playerId) {
    return PlayerSnapshot(playerId: playerId);
  }

  @override
  List<Object?> get props => <Object?>[
    playerId,
    sessionId,
    requestId,
    generationId,
    sourceId,
    mediaType,
    mediaCapabilities,
    state,
    status,
    options,
    capabilities,
    metrics,
    timestamp,
  ];

  @override
  String toString() {
    return 'PlayerSnapshot('
        'playerId: $playerId, '
        'sessionId: $sessionId, '
        'requestId: $requestId, '
        'generationId: $generationId, '
        'sourceId: $sourceId, '
        'mediaType: $mediaType, '
        'mediaCapabilities: $mediaCapabilities, '
        'status: $playerStatus, '
        'isPlaying: $isPlaying, '
        'isBuffering: $isBuffering, '
        'hasError: $hasError, '
        'isDisposed: $isDisposed'
        ')';
  }
}
