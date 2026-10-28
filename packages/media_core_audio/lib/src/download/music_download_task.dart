import 'package:media_core/media_core.dart' show MathUtils;
import 'package:media_core_audio/src/download/music_download_request.dart';

/// Lifecycle of one download.
///
/// The vocabulary mirrors lx-music's task list because each state is something
/// the viewer acts on: a queued task waits for a slot, a paused one waits for
/// the viewer, a processing one is having tags/lyrics written after the bytes
/// arrived, and a skipped one found its file already on disk.
enum MusicDownloadStatus {
  /// Waiting for a slot.
  queued,

  /// ffmpeg is running (or an HTTP transfer is).
  running,

  /// Suspended by the viewer; a direct transfer resumes from its partial file.
  paused,

  /// Bytes are complete; tags, cover art and sidecar lyrics are being written.
  processing,

  /// Finished successfully.
  completed,

  /// The output file already existed and [MusicDownloadRequest.skipExisting]
  /// was on, so nothing was transferred.
  skipped,

  /// Failed (and out of retries, when the queue is doing the retrying).
  failed,

  /// Cancelled by the user.
  cancelled;

  /// Whether the task is moving bytes or writing metadata.
  bool get isRunning => this == MusicDownloadStatus.running || this == MusicDownloadStatus.processing;

  /// Whether the task reached a terminal status.
  bool get isTerminal =>
      this == MusicDownloadStatus.completed ||
      this == MusicDownloadStatus.skipped ||
      this == MusicDownloadStatus.failed ||
      this == MusicDownloadStatus.cancelled;

  /// Whether the task can still make progress.
  bool get isResumable =>
      this == MusicDownloadStatus.queued ||
      this == MusicDownloadStatus.paused ||
      this == MusicDownloadStatus.failed;
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
    this.bytesReceived = 0,
    this.bytesTotal = -1,
    this.bytesPerSecond = 0,
    this.sessionId,
    this.error,
    this.attempt = 1,
    this.startedAt,
    this.finishedAt,
    this.lyricPath,
  });

  /// Restores a task from [toJson].
  factory MusicDownloadTask.fromJson(Map<String, Object?> json) {
    final status = MusicDownloadStatus.values
        .where((value) => value.name == json['status'])
        .firstOrNull ?? MusicDownloadStatus.paused;

    return MusicDownloadTask(
      id: json['id'] as String? ?? '',
      request: MusicDownloadRequest.fromJson(
        (json['request'] as Map<Object?, Object?>? ?? const <Object?, Object?>{}).cast<String, Object?>(),
      ),
      status: status,
      processed: Duration(milliseconds: (json['processedMs'] as num?)?.toInt() ?? 0),
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      bytesTotal: (json['bytesTotal'] as num?)?.toInt() ?? -1,
      bytesPerSecond: (json['bytesPerSecond'] as num?)?.toInt() ?? 0,
      sessionId: json['sessionId'] as String?,
      error: json['error'] as String?,
      attempt: (json['attempt'] as num?)?.toInt() ?? 1,
      startedAt: _date(json['startedAt']),
      finishedAt: _date(json['finishedAt']),
      lyricPath: json['lyricPath'] as String?,
    );
  }

  /// Stable identifier.
  final String id;

  /// What to download and where to put it.
  final MusicDownloadRequest request;

  /// Current status.
  final MusicDownloadStatus status;

  /// How much of the audio ffmpeg has already written.
  ///
  /// This is *media* time, not wall time: it is the only progress signal that
  /// is meaningful for both a fast copy and a slow transcode. Direct HTTP
  /// transfers leave it at zero and report [bytesReceived] instead.
  final Duration processed;

  /// Processing speed as a multiple of real time (2.0 = twice as fast).
  final double speed;

  /// Bytes written so far (direct transfers).
  final int bytesReceived;

  /// Total bytes of the remote file, or `-1` when the server did not say.
  final int bytesTotal;

  /// Recent transfer rate in bytes per second.
  final int bytesPerSecond;

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

  /// Sidecar lyric path, when one was written.
  final String? lyricPath;

  /// Output path.
  String get outputPath => request.outputPath;

  /// Whether the task reached a terminal status.
  bool get isTerminal => status.isTerminal;

  /// Whether the download finished successfully.
  bool get isCompleted => status == MusicDownloadStatus.completed;

  /// Whether the task is paused.
  bool get isPaused => status == MusicDownloadStatus.paused;

  /// Progress in 0.0–1.0, or null when neither a byte total nor a duration is
  /// known.
  ///
  /// Byte progress wins when the server reported a size: it is the real
  /// transfer, while ffmpeg's media clock can run ahead of the bytes on disk.
  /// Unknown durations are common on streaming sources (a `.m3u8` with no
  /// `EXTINF` total), and reporting 0 would look like a stuck download —
  /// callers should show a spinner instead of a bar when this is null.
  double? get progress {
    if (bytesTotal > 0) {
      return MathUtils.clampDouble(bytesReceived / bytesTotal, 0, 1);
    }

    final total = request.expectedDuration;

    if (total == null || total <= Duration.zero) {
      return null;
    }

    return MathUtils.clampDouble(MathUtils.percent(processed.inMilliseconds, total.inMilliseconds), 0, 1);
  }

  /// Estimated time left, when speed and total are both known.
  Duration? get remaining {
    if (bytesTotal > 0 && bytesPerSecond > 0) {
      final left = MathUtils.clampInt(bytesTotal - bytesReceived, 0, bytesTotal);

      return Duration(seconds: (left / bytesPerSecond).ceil());
    }

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
    int? bytesReceived,
    int? bytesTotal,
    int? bytesPerSecond,
    String? sessionId,
    String? error,
    bool clearError = false,
    int? attempt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? lyricPath,
  }) {
    return MusicDownloadTask(
      id: id,
      request: request,
      status: status ?? this.status,
      processed: processed ?? this.processed,
      speed: speed ?? this.speed,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      sessionId: sessionId ?? this.sessionId,
      error: clearError ? null : (error ?? this.error),
      attempt: attempt ?? this.attempt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lyricPath: lyricPath ?? this.lyricPath,
    );
  }

  /// Serializes the task for host-side persistence.
  ///
  /// A non-terminal task is restored as paused: the process that was moving
  /// the bytes is gone, and a restored "running" row would never progress.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'request': request.toJson(),
      'status': (status.isTerminal ? status : MusicDownloadStatus.paused).name,
      'processedMs': processed.inMilliseconds,
      'speed': speed,
      'bytesReceived': bytesReceived,
      'bytesTotal': bytesTotal,
      'bytesPerSecond': bytesPerSecond,
      'sessionId': sessionId,
      'error': error,
      'attempt': attempt,
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'lyricPath': lyricPath,
    }..removeWhere((key, value) => value == null);
  }

  static DateTime? _date(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  @override
  String toString() => 'MusicDownloadTask($id, ${status.name}, ${processed.inSeconds}s/$speed×, '
      '$bytesReceived/${bytesTotal > 0 ? bytesTotal : '?'}B)';
}
