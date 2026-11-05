/// iOS Media Activity backend for media_core: lock-screen lyrics and
/// Dynamic Island through ActivityKit Live Activities, plus Now Playing and
/// remote commands through MediaPlayer.
///
/// Architecture (spec §3): Flutter stays the media data source — lyric
/// parsing, current-line computation and playback state all live above this
/// package. The seam is `MediaActivityCoordinator`: hosts feed it typed
/// events (track changed, lyric boundary, play/pause, seek) and it drives
/// `MediaActivityController`, which is the only writer onto
/// `MediaActivityPlatform` — the bridge to the iOS ActivityKit plugin.
///
/// Nothing here renders: the lock-screen and Dynamic Island surfaces are a
/// SwiftUI Widget Extension owned by the host app, reading the shared
/// `MediaActivityAttributes` from the iOS pod (spec §10, §20.1.2).
///
/// Every failure degrades: an unsupported device, a disabled Live Activity
/// toggle or a refused create all read as "feature off" without touching
/// playback (spec §13.3).
library;

export 'src/interfaces/media_activity_platform.dart';
export 'src/models/media_activity_capabilities.dart';
export 'src/models/media_activity_metadata.dart';
export 'src/models/media_activity_state.dart';
export 'src/platform/platform_media_activity.dart';
export 'src/services/media_activity_controller.dart';
export 'src/services/media_activity_coordinator.dart';
export 'src/services/media_activity_sync_policy.dart';
