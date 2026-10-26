/// Type of session operation.
enum SessionOperationType {
  /// Open media source.
  open,

  /// Start playback.
  play,

  /// Pause playback.
  pause,

  /// Stop playback.
  stop,

  /// Change media source.
  switchSource,

  /// Reload current source.
  reload,

  /// Release session.
  release,
}
