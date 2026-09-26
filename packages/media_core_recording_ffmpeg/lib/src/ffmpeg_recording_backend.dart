import 'dart:async';
import 'dart:io';

import 'package:media_core/media_core.dart';

import 'ffmpeg_executor.dart';
import 'ffmpeg_record_arguments.dart';
import 'ffmpeg_record_config.dart';

/// What the caller asked for when a recording ended.
///
/// FFmpeg reports `255` both for a stream that died and for a process that was
/// killed on purpose, so the exit code alone cannot say whether a recording
/// succeeded. The intent is tracked here and decides how the end is reported.
enum _StopIntent { none, stop, cancel }

/// Records network streams with FFmpeg.
///
/// Responsibilities:
///
/// - build the FFmpeg argument list for a source and configuration
/// - own the process: start it, observe progress, end it
/// - map process outcomes onto the recording contract's states and results
///
/// It does not:
///
/// - choose what to record (the host does)
/// - manage several recordings or queue them (the core `RecordingManager` does)
/// - join segments into a single file (a separate step; the journal is written
///   for whoever does it)
///
/// ## Segmented output, on purpose
///
/// The capture writes MPEG-TS segments plus a CSV journal rather than one growing
/// file. A live recording has no natural end: if the process dies, or the phone
/// kills the app, a single file is usually unplayable because its index was
/// never written. Segments are playable individually, and the journal says how
/// they join — so the worst case is "a few seconds lost", not "hours lost".
///
/// ## Intent, not exit code
///
/// A user-requested stop is a **successful** recording: the file exists and is
/// playable. The same exit code from a crashed input is an error. The backend
/// therefore tracks why it ended the process instead of inferring it from the
/// code, and reports [RecordingResult.success] accordingly.
final class FfmpegRecordingBackend implements RecordingBackend {
  /// Creates the backend.
  ///
  /// [executor] defaults to the FFmpegKit implementation; pass a fake in tests.
  /// [outputDirectory] is the default location for recordings, overridable per
  /// start through `RecordingConfig.outputPath`.
  FfmpegRecordingBackend({
    FfmpegExecutor? executor,
    this.config = FfmpegRecordConfig.defaults,
    String? outputDirectory,
  }) : _executor = executor,
       _outputDirectory = outputDirectory;

  /// Recording tunables.
  final FfmpegRecordConfig config;

  FfmpegExecutor? _executor;
  String? _outputDirectory;

  final StreamController<RecordingState> _stateController = StreamController<RecordingState>.broadcast();

  RecordingState _state = const RecordingState();
  FfmpegExecution? _execution;
  _StopIntent _intent = _StopIntent.none;
  StreamSubscription<int>? _exitWatcher;
  String? _activeDirectory;
  Duration _lastMediaTime = Duration.zero;
  int _lastBytes = 0;
  bool _disposed = false;

  /// Current state.
  @override
  RecordingState get state => _state;

  /// State changes.
  Stream<RecordingState> get onStateChanged => _stateController.stream;

  /// Whether this backend can record right now.
  ///
  /// True as soon as it exists: the native FFmpeg loads lazily on the first
  /// start, and reporting "unavailable" until an explicit initialization would
  /// make a host gate its record button on a step the user does not care about.
  @override
  bool get isAvailable => !_disposed;

  /// Output directory the last recording was written to.
  String? get activeDirectory => _activeDirectory;

  /// Selects the output directory.
  void setOutputDirectory(String? directory) => _outputDirectory = directory;

  /// Warms the native FFmpeg up.
  Future<void> initialize() async {
    _ensureNotDisposed();
    await _executorOf().initialize();
  }

  @override
  Future<void> start(RecordingSource source, RecordingConfig config) async {
    _ensureNotDisposed();
    if (_execution != null) {
      throw StateError('A recording is already running.');
    }
    if (!source.isValid) {
      throw ArgumentError.value(source, 'source', 'Recording source is empty.');
    }
    if (source.type == RecordingSourceType.file) {
      throw UnsupportedError('FFmpeg recording captures network sources; a local file is already recorded.');
    }

    final directory = config.outputPath ?? _outputDirectory;
    if (directory == null || StringUtils.isBlank(directory)) {
      throw StateError('No recording directory configured. Set one on the backend or in RecordingConfig.outputPath.');
    }

    final prefix = FfmpegRecordArguments.safeFilePrefix(this.config.filePrefix);
    final segmentPattern = '${prefix}_%06d${this.config.segmentSuffix}';
    final journalPath = _join(directory, '$prefix${this.config.journalSuffix}');

    // A fresh state, not a copy: `copyWith` cannot clear an error from a
    // previous attempt, and a stale error would make a running recording look
    // failed.
    _emit(
      const RecordingState(status: RecordingStatus.starting),
    );

    await Directory(directory).create(recursive: true);

    final arguments = FfmpegRecordArguments(config: this.config).recordArguments(
      url: source.value,
      outputDirectory: directory,
      segmentPattern: segmentPattern,
      journalPath: journalPath,
      filePrefix: prefix,
    );

    _activeDirectory = directory;
    _intent = _StopIntent.none;
    _lastMediaTime = Duration.zero;
    _lastBytes = 0;

    try {
      final execution = await _executorOf().start(arguments: arguments, onStatistics: _handleStatistics);
      _execution = execution;
      _emit(_state.copyWith(status: RecordingStatus.recording));
      _exitWatcher = execution.exitCode.asStream().listen(_handleExit);
    } catch (error, stackTrace) {
      _emit(_state.copyWith(status: RecordingStatus.error, error: error));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<RecordingResult> stop() async {
    _ensureNotDisposed();
    final execution = _execution;
    if (execution == null) {
      return RecordingResult(success: false, outputPath: _activeDirectory, error: StateError('No recording to stop.'));
    }

    // The intent must be set before the process ends, or the exit watcher sees
    // an unexplained 255 and reports an error for a recording the user ended.
    _intent = _StopIntent.stop;
    _emit(_state.copyWith(status: RecordingStatus.stopping));
    await execution.stop();
    await _awaitExit(execution);

    return RecordingResult(
      success: true,
      outputPath: _activeDirectory,
      duration: _lastMediaTime,
      bytesWritten: _lastBytes,
    );
  }

  @override
  Future<void> cancel() async {
    _ensureNotDisposed();
    final execution = _execution;
    if (execution == null) {
      return;
    }

    _intent = _StopIntent.cancel;
    await execution.cancel();
    await _awaitExit(execution);
    _emit(_state.copyWith(status: RecordingStatus.cancelled));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    final execution = _execution;
    if (execution != null) {
      _intent = _StopIntent.cancel;
      await execution.cancel();
      await _awaitExit(execution);
    }

    _disposed = true;
    await _exitWatcher?.cancel();
    _exitWatcher = null;
    await _executor?.dispose();
    await _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  FfmpegExecutor _executorOf() => _executor ??= FfmpegKitExecutor();

  void _handleStatistics(FfmpegStatistics statistics) {
    if (_disposed) {
      return;
    }
    _lastMediaTime = Duration(milliseconds: statistics.timeMs);
    _lastBytes = statistics.sizeBytes;
    if (_state.status != RecordingStatus.recording) {
      return;
    }
    _emit(_state.copyWith(duration: _lastMediaTime, bytesWritten: _lastBytes));
  }

  /// Reacts to a process that ended on its own.
  ///
  /// Reached only when nobody asked it to end: [stop] and [cancel] set the
  /// intent first and await the same future, so their outcome is already
  /// decided by the time this runs.
  void _handleExit(int? code) {
    if (_disposed || _intent != _StopIntent.none) {
      return;
    }

    _execution = null;
    final succeeded = code == 0;
    _emit(
      RecordingState(
        status: succeeded ? RecordingStatus.completed : RecordingStatus.error,
        duration: _lastMediaTime,
        bytesWritten: _lastBytes,
        error: succeeded ? null : 'FFmpeg exited with code $code',
      ),
    );
  }

  Future<void> _awaitExit(FfmpegExecution execution) async {
    try {
      await execution.exitCode;
    } catch (_) {
      // A process that cannot be reaped is still gone; the caller's intent
      // already decided the outcome.
    } finally {
      if (identical(_execution, execution)) {
        _execution = null;
      }
    }
  }

  void _emit(RecordingState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  String _join(String directory, String name) {
    final separator = directory.contains(r'\') ? r'\' : '/';
    return directory.endsWith('/') || directory.endsWith(r'\') ? '$directory$name' : '$directory$separator$name';
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('FfmpegRecordingBackend has been disposed.');
    }
  }
}
