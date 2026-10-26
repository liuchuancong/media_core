/// Defines stable categories of recording errors.
///
/// Error codes are intentionally independent of platform-specific exception
/// classes so callers can implement consistent recording behavior across
/// different backends and platforms.
enum RecordingErrorCode {
  /// Recording configuration is invalid or unsupported.
  invalidConfiguration,

  /// A recording is already active.
  alreadyRecording,

  /// No recording is currently active.
  notRecording,

  /// No suitable recording backend is available.
  backendUnavailable,

  /// The recording source is unavailable.
  sourceUnavailable,

  /// The requested recording output cannot be created or opened.
  outputUnavailable,

  /// Recording failed during execution.
  failed,

  /// Recording was explicitly cancelled.
  cancelled,
}

/// Provides common operations for [RecordingErrorCode].
extension RecordingErrorCodeX on RecordingErrorCode {
  /// Stable string representation of this error code.
  String get name {
    return switch (this) {
      RecordingErrorCode.invalidConfiguration => 'invalid_configuration',
      RecordingErrorCode.alreadyRecording => 'already_recording',
      RecordingErrorCode.notRecording => 'not_recording',
      RecordingErrorCode.backendUnavailable => 'backend_unavailable',
      RecordingErrorCode.sourceUnavailable => 'source_unavailable',
      RecordingErrorCode.outputUnavailable => 'output_unavailable',
      RecordingErrorCode.failed => 'failed',
      RecordingErrorCode.cancelled => 'cancelled',
    };
  }

  /// Whether this error indicates an expected cancellation rather than a
  /// recording failure.
  bool get isCancellation {
    return this == RecordingErrorCode.cancelled;
  }
}
