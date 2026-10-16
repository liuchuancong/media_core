/// Lifecycle of one download.
///
/// Mirrors the reference implementation's vocabulary because each state is a
/// distinct thing to show a viewer: a queued task is waiting for a slot, a
/// paused one is waiting for the viewer, and a stopped one was abandoned.
enum DownloadStatus {
  /// Created, not yet queued.
  idle,

  /// Waiting for a concurrency slot.
  queued,

  /// Transferring.
  running,

  /// Suspended by the viewer; resumable from where it stopped.
  paused,

  /// Suspended because the transfer could not continue right now; resumable.
  stopped,

  /// Finished; the file is complete and verified.
  completed,

  /// Gave up after the retry budget was spent.
  failed,

  /// Abandoned by the viewer; the partial file is kept for inspection.
  cancelled;

  /// Whether the task is moving bytes.
  bool get isRunning => this == DownloadStatus.running;

  /// Whether the task has finished, one way or another.
  bool get isTerminal =>
      this == DownloadStatus.completed || this == DownloadStatus.failed || this == DownloadStatus.cancelled;

  /// Whether the task can still make progress.
  bool get isResumable =>
      this == DownloadStatus.idle ||
      this == DownloadStatus.queued ||
      this == DownloadStatus.paused ||
      this == DownloadStatus.stopped;
}
