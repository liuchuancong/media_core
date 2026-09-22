/// Stall kinds inferred by [LiveWatchdogs].
///
/// A stall is an inference, not a backend report: the watchdog
/// observed a missing expectation (no playing state, no frame,
/// sustained buffering) rather than an explicit error.
///
/// This enum is intentionally *not* an error model. The controller
/// maps each kind onto a [PlayerFailure] with a concrete
/// [PlayerErrorCode] before handing it to [ErrorPolicy].
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
