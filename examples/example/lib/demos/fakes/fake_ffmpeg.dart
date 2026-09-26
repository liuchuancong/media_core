import 'dart:async';

import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

/// An FFmpeg process that never starts.
///
/// Recording has two halves: the argument list, which is pure data and printed
/// verbatim, and the process lifecycle — state transitions, statistics, exit-code
/// attribution. The first needs nothing, the second needs a native FFmpeg, and
/// [FfmpegExecutor] is the seam between them. Faking it makes the second half
/// runnable on a machine with no FFmpeg at all, which is what a developer who
/// just cloned the repository has.
final class FakeFfmpegExecutor implements FfmpegExecutor {
  /// Creates a fake executor.
  FakeFfmpegExecutor({this.statisticsInterval = const Duration(milliseconds: 120)});

  /// How often the fake process reports progress.
  final Duration statisticsInterval;

  /// Argument lists this executor was asked to run.
  final List<List<String>> started = <List<String>>[];

  /// Whether [initialize] was called.
  bool initialized = false;

  /// Whether [dispose] was called.
  bool disposed = false;

  /// The most recent execution, for a demo that wants to end it deliberately.
  FakeFfmpegExecution? last;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<FfmpegExecution> start({
    required List<String> arguments,
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(String message)? onLog,
  }) async {
    started.add(arguments);
    final execution = FakeFfmpegExecution(statisticsInterval: statisticsInterval);
    last = execution;
    execution.run(onStatistics: onStatistics, onLog: onLog);
    return execution;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// One fake FFmpeg process.
///
/// It advances its own statistics like a real capture does — media time and
/// output size growing, drift between them — and it can be ended either way:
/// [stop] reports success (what a graceful quit looks like), [cancel] reports
/// FFmpeg's `255` (what a killed process reports).
final class FakeFfmpegExecution implements FfmpegExecution {
  /// Creates a fake process.
  FakeFfmpegExecution({this.statisticsInterval = const Duration(milliseconds: 120)});

  /// How often progress is reported.
  final Duration statisticsInterval;

  final Completer<int> _exitCode = Completer<int>();
  final StreamController<String> _logs = StreamController<String>.broadcast();

  Timer? _timer;
  int _ticks = 0;

  @override
  bool get isRunning => !_exitCode.isCompleted;

  @override
  Future<int> get exitCode => _exitCode.future;

  /// Log lines the process emitted.
  Stream<String> get logs => _logs.stream;

  /// How many statistic reports were emitted.
  int get reports => _ticks;

  /// Starts ticking.
  void run({void Function(FfmpegStatistics statistics)? onStatistics, void Function(String message)? onLog}) {
    _logs.add('ffmpeg started (fake)');
    onLog?.call('ffmpeg started (fake)');

    _timer = Timer.periodic(statisticsInterval, (_) {
      _ticks++;
      final statistics = FfmpegStatistics(
        timeMs: _ticks * 500,
        // A segmented capture writes in bursts; the fake grows smoothly.
        sizeBytes: _ticks * 24 * 1024,
        bitrate: 1200,
        speed: 1.0,
      );
      onStatistics?.call(statistics);
      _logs.add('frame=${_ticks * 30} ...');
    });
  }

  /// Ends the process as a graceful stop.
  @override
  Future<void> stop() async {
    _finish(0);
  }

  /// Ends the process the way a killed FFmpeg ends: code `255`.
  @override
  Future<void> cancel() async {
    _finish(255);
  }

  void _finish(int code) {
    _timer?.cancel();
    _timer = null;
    if (!_exitCode.isCompleted) {
      _exitCode.complete(code);
    }
  }
}
