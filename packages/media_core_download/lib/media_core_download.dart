/// Offline media downloads for media_core.
///
/// A task queue with a concurrency limit, resumable transfers and a retry
/// budget:
///
/// ```dart
/// final manager = DownloadManager();
/// manager.onTaskChanged.listen((task) => print('${task.fileName}: ${task.progress.percent}%'));
///
/// manager.add(DownloadTask(
///   id: roomId,
///   url: streamUrl,
///   filePath: '$downloadsDir/$roomId.ts',
///   headers: {'Referer': pageUrl},
/// ));
/// ```
///
/// The two decisions worth reading about are on [DownloadManager]: a bounded
/// queue, and a resume that verifies the partial file before appending to it
/// (see [DownloadResumePlanner]).
library;

export 'src/download_config.dart';
export 'src/download_file_sink.dart';
export 'src/download_manager.dart';
export 'src/download_progress.dart';
export 'src/download_resume.dart';
export 'src/download_status.dart';
export 'src/download_task.dart';
export 'src/download_transport.dart';
