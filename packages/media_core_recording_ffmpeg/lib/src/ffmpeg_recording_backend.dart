import 'dart:async';
import 'dart:io';

import 'package:media_core/media_core.dart';
import 'package:media_core_native/media_core_native.dart';

import 'ffmpeg_executor.dart';
import 'ffmpeg_record_arguments.dart';
import 'ffmpeg_record_config.dart';

/// Decision trail for a recording.
///
/// The argument list is logged at debug because an FFmpeg failure is usually a
/// statement about the arguments, and the exit code alone ("255") says nothing.
/// The list is what a developer pastes into a shell to reproduce it.
final LogModule _log = MediaCoreLog.of(LogCategory.recording);

/// Ledger of the running recording.
///
/// Reported in measured bytes: FFmpeg's statistics say how much has been written,
/// so a recording in progress shows up in a memory report as a real number —
/// which is what makes it possible to tell a recording that is writing a lot
/// from a queue that is holding a lot.
final MemoryAccount _memory = MediaCoreMemory.of(MemoryModule.recording);

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

  /// This instance's key in the shared account: a module can have several
  /// live instances, and a report sums their contributions rather than
  /// keeping whichever reported last.
  late final String _memoryKey = memoryContributorKey(this);
  /// Creates the backend.
  ///
  /// [executor] defaults to the FFmpegKit implementation; pass a fake in tests.
  /// [outputDirectory] is the default location for recordings, overridable per
  /// start through `RecordingConfig.outputPath`.
  FfmpegRecordingBackend({
    FfmpegExecutor? executor,
    this.config = FfmpegRecordConfig.defaults,
    String? outputDirectory,
    BackgroundExecutionStarter? keepAliveStarter,
  }) : _executor = executor,
       _outputDirectory = outputDirectory,
       _keepAliveStarter = keepAliveStarter ?? BackgroundExecution.acquire;

  /// Recording tunables.
  final FfmpegRecordConfig config;

  FfmpegExecutor? _executor;
  String? _outputDirectory;
  final BackgroundExecutionStarter _keepAliveStarter;

  /// The session holding this recording's process alive, if any.
  BackgroundExecutionLease? _keepAlive;

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
    _emit(const RecordingState(status: RecordingStatus.starting));

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

    _log.info(
      'starting a recording',
      fields: <String, Object?>{
        'url': source.value,
        'type': source.type.name,
        'directory': directory,
        'segmentPattern': segmentPattern,
      },
    );
    _log.debug('ffmpeg arguments', fields: <String, Object?>{'argv': arguments.join(' ')});

    try {
      // The lease is taken before the process exists. The wake lock must not
      // begin a moment after the recording does, and with nothing running yet
      // there is no process to unwind when a platform refuses or throws.
      await _acquireKeepAlive(prefix);

      final execution = await _executorOf().start(arguments: arguments, onStatistics: _handleStatistics);
      _execution = execution;
      _emit(_state.copyWith(status: RecordingStatus.recording));
      _log.info('recording started', fields: <String, Object?>{'session': identityHashCode(execution)});
      _exitWatcher = execution.exitCode.asStream().listen(_handleExit);
    } catch (error, stackTrace) {
      await _releaseKeepAlive();
      _log.error('could not start the recording', error: error, fields: <String, Object?>{'url': source.value});
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
    _log.info('stopping the recording', fields: <String, Object?>{'session': identityHashCode(execution)});
    _emit(_state.copyWith(status: RecordingStatus.stopping));
    await execution.stop();
    await _awaitExit(execution);
    await _releaseKeepAlive();

    _log.info(
      'recording stopped',
      fields: <String, Object?>{
        'directory': _activeDirectory,
        'durationMs': _lastMediaTime.inMilliseconds,
        'bytesWritten': _lastBytes,
      },
    );

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

    _log.info('cancelling the recording', fields: <String, Object?>{'session': identityHashCode(execution)});
    _intent = _StopIntent.cancel;
    await execution.cancel();
    await _awaitExit(execution);
    await _releaseKeepAlive();
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

    await _releaseKeepAlive();

    _disposed = true;
    _memory.withdraw(_memoryKey);
    await _exitWatcher?.cancel();
    _exitWatcher = null;
    await _executor?.dispose();
    await _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  FfmpegExecutor _executorOf() => _executor ??= FfmpegKitExecutor();

  /// Holds the process alive for as long as this recording runs.
  ///
  /// A platform that refuses (no implementation, or a notification permission
  /// the user declined) leaves the recording unprotected rather than failing
  /// it: the user asked for a recording, not for a notification.
  Future<void> _acquireKeepAlive(String prefix) async {
    if (!config.keepAlive) {
      return;
    }

    final session = await _keepAliveStarter(
      title: config.keepAliveTitle ?? 'Recording',
      text: prefix,
      wakeLock: true,
    );

    _keepAlive = session;

    if (session == null) {
      _log.debug('no background execution on this platform; the recording is unprotected');
    } else {
      _log.info('background execution held', fields: <String, Object?>{'session': session.id});
    }
  }

  Future<void> _releaseKeepAlive() async {
    final session = _keepAlive;

    _keepAlive = null;

    await session?.release();
  }

  void _handleStatistics(FfmpegStatistics statistics) {
    if (_disposed) {
      return;
    }
    _lastMediaTime = Duration(milliseconds: statistics.timeMs);
    _lastBytes = statistics.sizeBytes;
    _memory.report(_memoryKey, 
      items: 1,
      bytes: _lastBytes,
      note: 'recording, ${_lastMediaTime.inSeconds}s written',
    );
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
    _memory.withdraw(_memoryKey);
    // A process that ended on its own releases its own protection: the
    // notification must not outlive the job it described.
    unawaited(_releaseKeepAlive());
    final succeeded = code == 0;
    if (succeeded) {
      _log.info(
        'recording finished on its own',
        fields: <String, Object?>{'exitCode': code, 'durationMs': _lastMediaTime.inMilliseconds},
      );
    } else {
      // Nobody asked it to end, so a non-zero code is the process failing.
      _log.error(
        'recording ended on its own with a failure',
        fields: <String, Object?>{
          'exitCode': code,
          'durationMs': _lastMediaTime.inMilliseconds,
          'bytesWritten': _lastBytes,
        },
      );
    }
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

/// Starts a background-execution session for a recording.
///
/// A function rather than a direct call so a host — or a test, which has no
/// platform to hold a wake lock — can supply its own: the point of the seam is
/// that the backend's lifecycle (acquire on start, release on *every* end) is
/// what matters, and that is worth observing without a device.
typedef BackgroundExecutionStarter =
    Future<BackgroundExecutionLease?> Function({required String title, String? text, bool wakeLock});
