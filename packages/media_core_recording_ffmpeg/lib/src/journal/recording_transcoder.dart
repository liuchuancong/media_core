import 'dart:io';

import 'package:media_core/media_core.dart';
import 'package:media_core_recording_ffmpeg/src/ffmpeg/ffmpeg_executor.dart';
import 'package:media_core_recording_ffmpeg/src/ffmpeg/ffmpeg_probe.dart';

/// The log module this file reports decisions through.
final LogModule _log = MediaCoreLog.of(LogCategory.recording);

/// How a finished recording is re-encoded.
///
/// A recording is captured by stream copy, which keeps the source's codec and
/// bitrate. This step exists for the viewer who wants a smaller file: it
/// re-encodes the video with H.264 and leaves the audio as it is, which is safe
/// because the input is already an MP4 produced by the recording's own join.
final class FfmpegTranscodeConfig {
  /// Creates a transcode configuration.
  const FfmpegTranscodeConfig({this.videoBitrateKbps = 4000, this.preset = 'veryfast', this.audioCodec = 'copy'});

  /// Target video bitrate, in kbit/s.
  ///
  /// The encoder pads toward this figure; it is a ceiling on the output's
  /// average rate, not a guarantee for complex scenes.
  final int videoBitrateKbps;

  /// `libx264` preset. `veryfast` is the recording reference's choice: a live
  /// capture is already long, and a slower preset turns a post-processing step
  /// into a fan running for an hour.
  final String preset;

  /// Audio codec. `copy` keeps the source stream, which is what a joined
  /// recording already carries.
  final String audioCodec;
}

/// What one transcode run produced.
final class FfmpegTranscodeResult {
  /// Creates a result.
  const FfmpegTranscodeResult({
    required this.success,
    required this.outputPath,
    required this.bytesWritten,
    required this.duration,
    required this.alreadyThere,
    this.elapsed = Duration.zero,
    this.error,
  });

  /// A run that produced a usable file.
  const FfmpegTranscodeResult.completed({
    required String outputPath,
    required int bytesWritten,
    Duration duration = Duration.zero,
    Duration elapsed = Duration.zero,
  }) : this(
         success: true,
         outputPath: outputPath,
         bytesWritten: bytesWritten,
         duration: duration,
         alreadyThere: false,
         elapsed: elapsed,
       );

  /// A run that found a complete output and left it alone.
  const FfmpegTranscodeResult.skipped({
    required String outputPath,
    required int bytesWritten,
    Duration duration = Duration.zero,
  }) : this(success: true, outputPath: outputPath, bytesWritten: bytesWritten, duration: duration, alreadyThere: true);

  /// A run that did not produce a usable file.
  const FfmpegTranscodeResult.failed({required String outputPath, required Object error})
    : this(
        success: false,
        outputPath: outputPath,
        bytesWritten: 0,
        duration: Duration.zero,
        alreadyThere: false,
        error: error,
      );

  /// Whether the file at [outputPath] is usable.
  final bool success;

  /// Where the transcoded file was written.
  final String outputPath;

  /// Bytes the output holds, measured from disk.
  final int bytesWritten;

  /// Duration FFprobe reported, or zero when no probe was available.
  final Duration duration;

  /// Whether a complete output already existed and the work was skipped.
  final bool alreadyThere;

  /// Wall-clock time the re-encode itself took.
  final Duration elapsed;

  /// Why the run failed, when it did.
  final Object? error;

  @override
  String toString() =>
      'FfmpegTranscodeResult(success: $success, alreadyThere: $alreadyThere, $outputPath, '
      '${bytesWritten}B${error == null ? '' : ', $error'})';
}

/// Re-encodes a finished recording into a smaller MP4.
///
/// This runs after the recording and after the segment join: re-encoding while
/// FFmpeg is still writing would race a segment that is still open, and doing it
/// as part of the capture would make the live process spend CPU on encoding
/// instead of keeping up with the stream.
///
/// The output is written to a partial file and renamed on success, so a
/// cancelled or crashed run never leaves a file a caller could mistake for a
/// complete recording.
final class FfmpegRecordingTranscoder {
  /// Creates a transcoder.
  FfmpegRecordingTranscoder({FfmpegExecutor? executor, FfmpegProbe? probe}) : _executor = executor, _probe = probe;

  FfmpegExecutor? _executor;
  final FfmpegProbe? _probe;

  /// The ledger this run reports to: re-encoding reads and writes the whole
  /// file, which a memory observer should see.
  final MemoryAccount _memory = MediaCoreMemory.of(MemoryModule.recording);

  late final String _memoryKey = memoryContributorKey(this);

  /// Re-encodes [inputPath] into [outputPath].
  ///
  /// Returns a failed result rather than throwing when the run cannot be done:
  /// the input recording is safe on disk, and the host should be told what went
  /// wrong, not interrupted.
  Future<FfmpegTranscodeResult> run({
    required String inputPath,
    required String outputPath,
    FfmpegTranscodeConfig config = const FfmpegTranscodeConfig(),
    void Function(double? progress)? onProgress,
    void Function(FfmpegExecution execution)? onExecution,
  }) async {
    final watch = Stopwatch()..start();
    final input = File(inputPath);
    final inputStat = FileStat.statSync(inputPath);

    if (inputStat.type == FileSystemEntityType.notFound || inputStat.size <= 0) {
      return FfmpegTranscodeResult.failed(
        outputPath: outputPath,
        error: FfmpegTranscodeException('the recording to transcode is missing or empty: $inputPath'),
      );
    }

    final existing = FileStat.statSync(outputPath);

    if (existing.type != FileSystemEntityType.notFound && existing.size > 0) {
      return FfmpegTranscodeResult.skipped(outputPath: outputPath, bytesWritten: existing.size);
    }

    final partialPath = _partialPathOf(outputPath);

    try {
      File(partialPath).deleteSync();
    } on FileSystemException {
      // A partial file that cannot be removed will fail the open below.
    }

    final arguments = List<String>.unmodifiable(<String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'info',
      '-i',
      input.path,
      // The same mapping rule as the recording: first video and first audio,
      // either allowed to be absent.
      '-map',
      '0:v:0?',
      '-map',
      '0:a:0?',
      '-c:v',
      'libx264',
      '-preset',
      config.preset,
      '-b:v',
      '${config.videoBitrateKbps.clamp(1, 100000)}k',
      '-c:a',
      config.audioCodec,
      '-movflags',
      '+faststart',
      '-max_muxing_queue_size',
      '2048',
      '-f',
      'mp4',
      partialPath,
    ]);

    _log.info(
      'transcoding a recording',
      fields: <String, Object?>{
        'input': inputPath,
        'output': outputPath,
        'bitrateKbps': config.videoBitrateKbps,
        'preset': config.preset,
      },
    );

    final inputDuration = await _probeOf()?.durationOf(inputPath);

    try {
      final executor = _executorOf();
      await executor.initialize();
      final execution = await executor.start(
        arguments: arguments,
        onStatistics: (statistics) {
          _memory.report(
            _memoryKey,
            items: 1,
            bytes: statistics.sizeBytes,
            note: 'transcode of ${inputPath.split(RegExp(r'[/\\]')).last}',
          );
          if (onProgress != null) {
            final total = inputDuration?.inMilliseconds ?? 0;
            onProgress(total > 0 ? (statistics.timeMs / total).clamp(0.0, 1.0) : null);
          }
        },
      );
      onExecution?.call(execution);

      final code = await _awaitExit(execution);
      final partial = FileStat.statSync(partialPath);

      if (code != 0 || partial.type == FileSystemEntityType.notFound || partial.size <= 0) {
        return FfmpegTranscodeResult.failed(
          outputPath: outputPath,
          error: FfmpegTranscodeException(
            'FFmpeg exited with $code and left '
            '${partial.type == FileSystemEntityType.notFound ? 'no' : '${partial.size}B'} output',
          ),
        );
      }

      // Rename only after a complete encode: a file named as the result must
      // never be a truncated one.
      await File(partialPath).rename(outputPath);
      final output = FileStat.statSync(outputPath);
      final duration = await _probeOf()?.durationOf(outputPath) ?? Duration.zero;

      _log.info(
        'recording transcoded',
        fields: <String, Object?>{'output': outputPath, 'bytes': output.size, 'durationMs': duration.inMilliseconds},
      );

      return FfmpegTranscodeResult.completed(
        outputPath: outputPath,
        bytesWritten: output.size,
        duration: duration,
        elapsed: watch.elapsed,
      );
    } on Object catch (error) {
      _log.error('the transcode could not run', error: error, fields: <String, Object?>{'output': outputPath});

      return FfmpegTranscodeResult.failed(outputPath: outputPath, error: error);
    } finally {
      _memory.withdraw(_memoryKey);
      try {
        final partial = File(partialPath);
        if (partial.existsSync()) {
          partial.deleteSync();
        }
      } on Object catch (error) {
        // A leftover partial file is not a failed transcode.
        _log.warning('partial transcode file delete failed', error: error);
      }
    }
  }

  /// The sibling path the encode writes before it is complete.
  static String _partialPathOf(String outputPath) {
    const extension = '.mp4';
    final lower = outputPath.toLowerCase();
    if (lower.endsWith(extension)) {
      return '${outputPath.substring(0, outputPath.length - extension.length)}.partial.mp4';
    }
    return '$outputPath.partial.mp4';
  }

  FfmpegExecutor _executorOf() => _executor ??= FfmpegKitExecutor();

  FfmpegProbe? _probeOf() => _probe ?? const FFprobeKitFfmpegProbe();

  Future<int?> _awaitExit(FfmpegExecution execution) async {
    try {
      return await execution.exitCode;
    } on Object {
      return null;
    }
  }
}

/// Why a recording could not be transcoded.
final class FfmpegTranscodeException implements Exception {
  /// Creates the exception.
  const FfmpegTranscodeException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'FfmpegTranscodeException: $message';
}
