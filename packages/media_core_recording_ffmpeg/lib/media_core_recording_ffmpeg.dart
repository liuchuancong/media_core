/// FFmpeg recording backend for media_core.
///
/// Captures a network stream to segmented MPEG-TS files plus a CSV journal, on
/// top of `ffmpeg_kit_extended_flutter`:
///
/// ```dart
/// final backend = FfmpegRecordingBackend(outputDirectory: recordingsDir);
/// await backend.initialize();
///
/// final manager = RecordingManager(backend: backend);
/// await manager.start(
///   source: RecordingSource.network(streamUrl, id: roomId),
///   config: const RecordingConfig(outputPath: recordingsDir),
/// );
/// // ... later
/// final result = await manager.stop();
/// ```
///
/// Segments rather than one file, and intent rather than exit code, are the two
/// decisions this package is built around; both are explained on
/// [FfmpegRecordingBackend].
library;

export 'src/ffmpeg_executor.dart';
export 'src/ffmpeg_record_arguments.dart';
export 'src/ffmpeg_record_config.dart';
export 'src/ffmpeg_recording_backend.dart';
