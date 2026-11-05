// Pigeon protocol for the iOS Media Activity bridge.
//
// Run from this package directory to regenerate both sides:
//
//   dart run pigeon --input pigeons/media_activity_api.dart
//
// The generated pair lands in lib/src/platform/media_activity_api.g.dart and
// ios/Classes/Plugin/media_activity_api.g.swift. Hand-written code wraps the
// generated types; nothing else may edit the .g files.
//
// Time rules (spec §6.1): every duration and position crosses the bridge in
// whole milliseconds; playbackRate is the only double. No seconds, no mixed
// units, no floating-point timestamps.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/media_activity_api.g.dart',
    // The generated Swift is Flutter-dependent, so it must live in the
    // Plugin subspec — the Widget Extension links only Shared.
    swiftOut: 'ios/Classes/Plugin/media_activity_api.g.swift',
    dartOptions: DartOptions(),
    swiftOptions: SwiftOptions(),
  ),
)

/// Static attributes of a Live Activity: stable for the activity's lifetime.
///
/// A track change updates or recreates the activity rather than letting stale
/// song information linger (spec §7.2).
class MediaActivityMetadata {
  /// Identifies one playback session; duplicates are refused by the manager.
  final String sessionId;

  /// Song title (or the live/video title once those types ship).
  final String title;

  /// Artist; empty string when unknown — never a null-vs-empty fork.
  final String artist;

  /// Album; nullable because many live streams have none.
  final String? album;

  /// Key of the artwork file the app placed in the App Group container
  /// (content hash naming, spec §12). Null shows the default artwork.
  final String? artworkKey;
}

/// Dynamic content of a Live Activity (ActivityKit `ContentState`).
class MediaActivityContentState {
  /// The lyric line on screen right now; empty when the track has none.
  final String currentLyric;

  /// Preview of the following line; empty when there is none.
  final String nextLyric;

  /// Whether playback is advancing. Paused activities stop lyric updates.
  final bool isPlaying;

  /// Playback position at the moment of the update, in milliseconds.
  final int positionMs;

  /// Playback speed; the lock screen advances its clock by rate × Δt.
  final double playbackRate;

  /// Monotonic revision of the lyric payload; guards out-of-order updates.
  final int lyricRevision;
}

/// System capability report (spec §13.2) — every layer keeps "unknown"
/// expressible, so the host decides "should we try" instead of guessing.
class MediaActivityCapabilitiesReport {
  /// The device can host Live Activities at all (iOS 16.1+, extension built).
  final bool isSupported;

  /// The user has Live Activities enabled system-wide.
  final bool activitiesEnabled;

  /// The user granted frequent-update authorization for this app.
  final bool frequentUpdatesEnabled;

  /// The device has a Dynamic Island (never inferred from the iOS version).
  final bool supportsDynamicIsland;

  /// Major iOS version, for version-gated features (buttons need iOS 17).
  final int systemMajorVersion;
}

/// Lifecycle status of one activity, as the native manager sees it.
class MediaActivityStatusReport {
  /// The activity exists and is active.
  final bool isActive;

  /// Whether the system has dismissed it (user swipe, staleness, budget).
  final bool isDismissed;
}

/// Now Playing payload for `MPNowPlayingInfoCenter` (spec §11.1).
///
/// Live streams must not fake music progress: duration stays null for them
/// and the elapsed position is only meaningful when `isLive` is false.
class NowPlayingMetadata {
  final String title;
  final String artist;
  final String? album;
  final String? artworkKey;

  /// Track duration in milliseconds; null for live streams.
  final int? durationMs;

  /// Elapsed position in milliseconds; ignored for live streams.
  final int positionMs;

  /// Playback speed; 0 while paused.
  final double playbackRate;

  /// Whether this is a live stream (progress controls are then disabled).
  final bool isLive;
}

/// Which remote commands the host's playback layer can honor right now
/// (spec §11.2). Disabled commands are hidden rather than erroring.
class RemoteCommandConfig {
  final bool playPauseEnabled;
  final bool nextTrackEnabled;
  final bool previousTrackEnabled;
  final bool seekEnabled;
}

/// Result of a lifecycle call, so the Dart side can degrade without parsing
/// native error strings (spec §13.3).
class MediaActivityCallResult {
  /// Whether the native side accepted the call.
  final bool ok;

  /// Stable error code when [ok] is false, e.g. `activity_disabled`.
  final String? errorCode;
}

@HostApi()
abstract class MediaActivityApi {
  /// Returns the system capability report.
  MediaActivityCapabilitiesReport getCapabilities();

  /// Starts the activity for [metadata]; refuses duplicates by sessionId.
  @objc.isUserVisible
  MediaActivityCallResult startActivity(MediaActivityMetadata metadata, MediaActivityContentState initialState);

  /// Pushes new dynamic content into the running activity.
  @objc.isUserVisible
  MediaActivityCallResult updateActivity(String sessionId, MediaActivityContentState state);

  /// Ends one activity. The lock screen may keep the final state briefly —
  /// ending is not immediate removal (spec §9.4).
  MediaActivityCallResult endActivity(String sessionId);

  /// Ends every activity this app owns (cleanup on logout/dispose).
  void endAllActivities();

  /// Reports the lifecycle status of one activity.
  MediaActivityStatusReport getActivityState(String sessionId);

  /// Updates Now Playing information.
  void updateNowPlaying(NowPlayingMetadata metadata);

  /// Clears Now Playing information.
  void clearNowPlaying();

  /// Configures which remote commands are currently enabled.
  void configureRemoteCommands(RemoteCommandConfig config);
}

/// Callbacks from iOS back into the host's playback layer.
///
/// Swift owns no playback state (spec §11.2, §20.1.7): every command routes
/// here and the host decides. The player id lets a multi-player host route.
@FlutterApi()
abstract class MediaActivityCommandApi {
  void onPlay(String playerId);

  void onPause(String playerId);

  void onTogglePlayPause(String playerId);

  void onNextTrack(String playerId);

  void onPreviousTrack(String playerId);

  /// [positionMs] is the position the user picked on the lock screen slider.
  void onSeek(String playerId, int positionMs);

  /// The system dismissed the activity (user swipe or budget).
  void onActivityDismissed(String sessionId);
}
