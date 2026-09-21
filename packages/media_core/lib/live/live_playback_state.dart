/// Semantic live playback state.
enum LivePlaybackState {
  /// No source.
  idle,

  /// Opening / switching the source.
  preparing,

  /// Buffering (native or inferred).
  buffering,

  /// Actively playing.
  playing,

  /// Paused by user intent.
  paused,

  /// Terminal error; every recovery level exhausted.
  error,
}
