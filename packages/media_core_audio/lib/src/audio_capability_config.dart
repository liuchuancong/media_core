/// Configuration for the media_core_audio capability.
///
/// Notification icon names refer to Android drawable resources in
/// the host app (`res/drawable`). Ship matching drawables or pass
/// names of your own icons.
final class AudioCapabilityConfig {
  /// Creates the configuration.
  const AudioCapabilityConfig({
    this.androidNotificationChannelId = 'media_core.audio',
    this.androidNotificationChannelName = 'Media playback',
    this.androidNotificationOngoing = false,
    this.androidStopOnRemoveTask = false,
    this.showControls = true,
    this.processInterruptions = true,
    this.pauseOnBecomingNoisy = true,
    this.duckFactor = 0.3,
    this.resumeAfterInterruption = true,
    this.playIcon = 'ic_media_play',
    this.pauseIcon = 'ic_media_pause',
    this.stopIcon = 'ic_media_stop',
    this.androidCompactActionIndices = const <int>[0, 1],
  });

  /// Notification channel id used on Android.
  final String androidNotificationChannelId;

  /// Notification channel name used on Android.
  final String androidNotificationChannelName;

  /// Whether the Android notification is ongoing while playing.
  final bool androidNotificationOngoing;

  /// Whether playback stops when the task is removed on Android.
  final bool androidStopOnRemoveTask;

  /// Whether transport controls are shown in the notification.
  ///
  /// When true the icons [playIcon], [pauseIcon] and [stopIcon]
  /// must exist as drawables in the host app.
  final bool showControls;

  /// Whether audio focus interruptions (calls, other media apps)
  /// are handled automatically.
  final bool processInterruptions;

  /// Whether playback pauses when headphones are unplugged.
  final bool pauseOnBecomingNoisy;

  /// Volume multiplier applied during a duck interruption.
  final double duckFactor;

  /// Whether playback resumes after a transient interruption ends.
  final bool resumeAfterInterruption;

  /// Drawable name for the play control.
  final String playIcon;

  /// Drawable name for the pause control.
  final String pauseIcon;

  /// Drawable name for the stop control.
  final String stopIcon;

  /// Compact action indices for the Android notification.
  final List<int> androidCompactActionIndices;
}
