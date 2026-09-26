import 'music_download_request.dart';

/// Lifecycle of one download.
enum MusicDownloadStatus {
  /// Waiting for a slot.
  queued,

  /// ffmpeg is running.
  running,

  /// Finished successfully.
  completed,

  /// Failed (and out of retries, when the queue is doing the retrying).
  failed,

  /// Cancelled by the user.
  cancelled,
}

/// One download and everything known about it.
///
/// Immutable: the downloader and the queue publish new instances, so a UI can
/// diff them instead of polling, and a completed task keeps the numbers it
/// finished with.
final class MusicDownloadTask {
  /// Creates a task.
  const MusicDownloadTask({
    required this.id,
    required this.request,
    this.status = MusicDownloadStatus.queued,
    this.processed = Duration.zero,
    this.speed = 0,
    this.bytesWritten = 0,
    this.sessionId,
    this.error,
    this.attempt = 1,
    this.startedAt,
    this.finishedAt,
  });

  /// Stable identifier.
  final String id;

  /// What to download and where to put it.
  final MusicDownloadRequest request;

  /// Current status.
  final MusicDownloadStatus status;

  /// How much of the audio ffmpeg has already written.
  ///
  /// This is *media* time, not wall time: it is the only progress signal that
  /// is meaningful for both a fast copy and a slow transcode.
  final Duration processed;

  /// Processing speed as a multiple of real time (2.0 = twice as fast).
  final double speed;

  /// Bytes written so far.
  final int bytesWritten;

  /// ffmpeg session id, once running (used to cancel).
  final String? sessionId;

  /// Failure message, when [status] is [MusicDownloadStatus.failed].
  final String? error;

  /// 1-based attempt number; the queue increments it on retry.
  final int attempt;

  /// When the download started.
  final DateTime? startedAt;

  /// When it reached a terminal status.
  final DateTime? finishedAt;

  /// Output path.
  String get outputPath => request.outputPath;

  /// Whether the task reached a terminal status.
  bool get isTerminal =>
      status == MusicDownloadStatus.completed ||
      status == MusicDownloadStatus.failed ||
      status == MusicDownloadStatus.cancelled;

  /// Whether the download is finished successfully.
  bool get isCompleted => status == MusicDownloadStatus.completed;

  /// Progress in 0.0–1.0, or null when the duration is unknown.
  ///
  /// Unknown durations are common on streaming sources (a `.m3u8` with no
  /// `EXTINF` total), and reporting 0 would look like a stuck download —
  /// callers should show a spinner instead of a bar when this is null.
  double? get progress {
    final total = request.expectedDuration;

    if (total == null || total <= Duration.zero) {
      return null;
    }

    return (processed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Estimated time left, when speed and duration are both known.
  Duration? get remaining {
    final progress = this.progress;

    if (progress == null || progress <= 0 || speed <= 0) {
      return null;
    }

    final started = startedAt;

    if (started == null) {
      return null;
    }

    final elapsed = DateTime.now().difference(started);

    if (elapsed <= Duration.zero) {
      return null;
    }

    return Duration(milliseconds: ((elapsed.inMilliseconds / progress) * (1 - progress)).round());
  }

  /// Creates a copy with selected fields replaced.
  MusicDownloadTask copyWith({
    MusicDownloadStatus? status,
    Duration? processed,
    double? speed,
    int? bytesWritten,
    String? sessionId,
    String? error,
    bool clearError = false,
    int? attempt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return MusicDownloadTask(
      id: id,
      request: request,
      status: status ?? this.status,
      processed: processed ?? this.processed,
      speed: speed ?? this.speed,
      bytesWritten: bytesWritten ?? this.bytesWritten,
      sessionId: sessionId ?? this.sessionId,
      error: clearError ? null : (error ?? this.error),
      attempt: attempt ?? this.attempt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  String toString() => 'MusicDownloadTask($id, ${status.name}, ${processed.inSeconds}s/$speed×)';
}
