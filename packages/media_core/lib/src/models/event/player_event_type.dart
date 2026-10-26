/// Identifies the broad category of a player event.
///
/// The event bus does not attach behavior to these values. They are used by
/// filters and consumers to select the events they are interested in.
enum PlayerEventType {
  /// Category for events that have not been classified yet; filters can
  /// include or drop it explicitly.
  unknown,

  /// Events about the player instance as a whole.
  player,

  /// Events about a playback session's lifecycle.
  session,

  /// Events about the media source currently being played.
  source,

  /// Transport events such as play, pause and seek.
  playback,

  /// Events reporting buffer fill level and stalls.
  buffering,

  /// Events about the video rendering surface.
  renderer,

  /// Events about the audio track and output device.
  audio,

  /// Events about how video is presented on screen.
  presentation,

  /// Events reporting automatic recovery from a degraded state.
  recovery,

  /// Events fired when playback switches to a fallback source or engine.
  fallback,

  /// Events about cached or preloaded media.
  cache,

  /// Events about media being recorded.
  recording,

  /// Events reporting whether the player is visible to the user.
  visibility,

  /// Events describing component lifecycle transitions.
  lifecycle,

  /// Events carrying a failure.
  error,

  /// Low-priority telemetry used for troubleshooting.
  diagnostics,
}
