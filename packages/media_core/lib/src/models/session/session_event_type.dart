/// Types of session events.
enum SessionEventType {
  /// Session created.
  created,

  /// Session state changed.
  stateChanged,

  /// Media source changed.
  sourceChanged,

  /// Session error occurred.
  error,

  /// Session disposed.
  disposed,
}
