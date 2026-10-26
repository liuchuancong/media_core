/// Describes the lifecycle state of an audio session.
enum AudioSessionStatus {
  /// The session has not been activated.
  inactive,

  /// The session is currently being activated.
  activating,

  /// The session is active and configured for media playback.
  active,

  /// The session is currently being deactivated.
  deactivating,

  /// The session was interrupted by the platform.
  interrupted,

  /// The session encountered an error.
  error,

  /// The session has been permanently disposed.
  disposed,
}
