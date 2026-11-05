import 'package:media_core_media_activity/src/models/media_activity_capabilities.dart';
import 'package:media_core_media_activity/src/models/media_activity_metadata.dart';
import 'package:media_core_media_activity/src/models/media_activity_state.dart';

/// Outcome of one native lifecycle call.
///
/// The native layer returns stable codes (`activity_disabled`,
/// `activity_limit_reached`, …) so the host can degrade without parsing
/// error strings (spec §13.3). [ok] false never throws — every caller
/// degrades and playback continues.
final class MediaActivityCallResult {
  /// The native side accepted the call.
  const MediaActivityCallResult.ok() : ok = true, errorCode = null;

  /// The native side refused it; [errorCode] says why (spec §13.3).
  const MediaActivityCallResult.failed(String this.errorCode) : ok = false;

  /// Whether the native side accepted the call.
  final bool ok;

  /// Stable error code when [ok] is false.
  final String? errorCode;

  @override
  String toString() => ok ? 'ok' : 'failed($errorCode)';
}

/// Lifecycle status of one activity as the native manager sees it.
final class MediaActivityStatus {
  /// Creates the status report.
  const MediaActivityStatus({required this.isActive, required this.isDismissed});

  /// The activity exists and is active.
  final bool isActive;

  /// The system dismissed it (user swipe, staleness or budget).
  final bool isDismissed;
}

/// Remote-command callbacks from iOS into the host's playback layer.
///
/// Swift owns no playback state (spec §20.1.7): every lock-screen or
/// headset command routes here and the host decides. `playerId` lets a
/// multi-player host route the command.
abstract interface class MediaActivityCommandSink {
  /// Called when the activity is discarded — [sessionId] is dead and the
  /// host should stop pushing updates for it (spec §9.5, §16).
  void onActivityDismissed(String sessionId);

  /// The viewer pressed play on the lock screen (or a headset button).
  void onPlay(String playerId);

  /// The viewer pressed pause.
  void onPause(String playerId);

  /// The viewer pressed the single play/pause toggle.
  void onTogglePlayPause(String playerId);

  /// The viewer asked for the next track.
  void onNextTrack(String playerId);

  /// The viewer asked for the previous track.
  void onPreviousTrack(String playerId);

  /// [positionMs] is the position the user picked on the lock-screen slider.
  void onSeek(String playerId, int positionMs);
}

/// The platform seam this package drives: everything between the Dart-side
/// services and the iOS plugin.
///
/// A platform that cannot host activities (non-iOS, plugin missing) answers
/// `unsupported` from [capabilities] and accepts the rest as no-ops —
/// callers never branch on platform (spec §13.3: every error degrades).
abstract interface class MediaActivityPlatform {
  /// Reports the system's Live Activity capability.
  Future<MediaActivityCapabilitiesReport> capabilities();

  /// Creates the activity for [metadata], seeded with [initialState].
  Future<MediaActivityCallResult> startActivity({
    required MediaActivityMetadata metadata,
    required MediaActivityContentState initialState,
  });

  /// Pushes new dynamic content into the running activity.
  Future<MediaActivityCallResult> updateActivity({required String sessionId, required MediaActivityContentState state});

  /// Ends one activity. The lock screen may keep the final state briefly —
  /// ending is not immediate removal (spec §9.4).
  Future<MediaActivityCallResult> endActivity({required String sessionId});

  /// Ends every activity this app owns (cleanup on logout/dispose).
  Future<void> endAllActivities();

  /// Reports the lifecycle status of one activity.
  Future<MediaActivityStatus> activityStatus({required String sessionId});

  /// Updates Now Playing information.
  Future<void> updateNowPlaying(NowPlayingUpdate update);

  /// Clears Now Playing information.
  Future<void> clearNowPlaying();

  /// Configures which remote commands the system should currently offer.
  Future<void> configureRemoteCommands({
    required bool playPauseEnabled,
    required bool nextTrackEnabled,
    required bool previousTrackEnabled,
    required bool seekEnabled,
  });

  /// Registers `sink` for remote commands and dismissal events from iOS.
  /// Passing null detaches. Implementations must tolerate re-registration.
  void setCommandSink(MediaActivityCommandSink? sink);
}

/// One Now Playing payload (spec §11.1).
///
/// Live streams must not fake music progress: [durationMs] stays null and
/// [positionMs] is ignored while [isLive] is set.
final class NowPlayingUpdate {
  /// Creates the payload.
  const NowPlayingUpdate({
    required this.title,
    this.artist = '',
    this.album,
    this.artworkKey,
    this.durationMs,
    this.positionMs = 0,
    this.playbackRate = 1.0,
    this.isLive = false,
  });

  /// Track title (or stream title).
  final String title;

  /// Artist; empty when unknown.
  final String artist;

  /// Album; nullable for live streams.
  final String? album;

  /// Key of the artwork file in the App Group container; null keeps the
  /// previous artwork cleared.
  final String? artworkKey;

  /// Track duration in milliseconds; null for live streams.
  final int? durationMs;

  /// Elapsed position in milliseconds; ignored for live streams.
  final int positionMs;

  /// Playback speed; 0 while paused.
  final double playbackRate;

  /// Whether this is a live stream.
  final bool isLive;
}
