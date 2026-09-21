/// Stall kinds inferred by [LiveWatchdogs].
///
/// A stall is an inference, not a backend report: the watchdog
/// observed a missing expectation (no playing state, no frame,
/// sustained buffering) rather than an explicit error.
enum LiveStallKind {
  /// Source opened but produced no playable state in time.
  sourceReadyTimeout,

  /// An unexpected pause resumed successfully after a reassert.
  unexpectedPauseResumed,

  /// A reasserted playback did not start playing again.
  unexpectedPauseResumeFailed,

  /// Playback stayed paused after the continuity retry.
  unexpectedPauseTimeout,

  /// Buffering never ended within the deadline.
  bufferingStallTimeout,

  /// Playing state held but no new video frame arrived.
  videoFrameStallTimeout,
}

/// Which level of recovery a failure has reached.
///
/// The [LivePlaybackController] walks this ladder; each level is
/// cheaper than the one below it.
enum LiveRecoveryLevel {
  /// Replay the same URL on the same backend.
  sameSource,

  /// Switch to another line (CDN URL) on the same backend.
  line,

  /// Switch to another backend.
  engine,

  /// Delayed retry with backoff after everything above failed.
  backoff,

  /// Nothing left; the error is terminal.
  terminal,
}
