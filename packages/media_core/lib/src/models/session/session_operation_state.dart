/// State of session operation.
enum SessionOperationState {
  /// Waiting to execute.
  pending,

  /// Currently running.
  running,

  /// Finished successfully.
  completed,

  /// Failed.
  failed,

  /// Cancelled.
  cancelled,
}
