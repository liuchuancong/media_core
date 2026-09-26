import 'dart:async';
import 'dart:math' as math;

import 'download_config.dart';
import 'download_file_sink.dart';
import 'download_progress.dart';
import 'download_resume.dart';
import 'download_status.dart';
import 'download_task.dart';
import 'download_transport.dart';

/// One in-flight transfer.
final class _ActiveTransfer {
  _ActiveTransfer(this.taskId);

  final String taskId;
  final Completer<void> cancelled = Completer<void>();

  bool get isCancelled => cancelled.isCompleted;

  void cancel() {
    if (!cancelled.isCompleted) {
      cancelled.complete();
    }
  }
}

/// The download queue.
///
/// Responsibilities:
///
/// - own the task list and each task's status
/// - run at most [DownloadConfig.maxConcurrent] transfers, starting queued ones
///   as slots free up
/// - resume a partial file after verifying it, or restart it when it cannot be
///   trusted
/// - retry a failed transfer within its budget
///
/// It does not:
///
/// - decide where files go (the task carries a path)
/// - persist the queue across restarts (the host stores tasks; a task's file and
///   the resume check make restoring one cheap)
/// - fetch bytes itself (a [DownloadTransport] does)
///
/// ## Why the queue is a queue
///
/// A viewer who taps download on twenty items expects them to arrive, not to
/// saturate the link and stall the one they are watching. Concurrency is capped
/// and configurable; everything else waits its turn and says so.
///
/// ## Why a verification step exists
///
/// Resume is only safe when the partial file really is a prefix of the remote
/// one. See [DownloadResumePlanner]: the last few bytes are re-fetched and
/// compared, and a mismatch restarts the file instead of producing something
/// that plays up to the exact point where it broke.
final class DownloadManager {
  DownloadManager({
    DownloadTransport? transport,
    DownloadFileSink? files,
    DownloadConfig config = DownloadConfig.defaults,
    DownloadResumePlanner? resumePlanner,
    DateTime Function()? clock,
  }) : _transport = transport ?? HttpDownloadTransport(config: config),
       _files = files ?? const IoDownloadFileSink(),
       _config = config,
       _resumePlanner = resumePlanner ?? DownloadResumePlanner(config: config),
       _clock = clock ?? DateTime.now;

  DownloadTransport _transport;
  DownloadFileSink _files;
  DownloadConfig _config;
  DownloadResumePlanner _resumePlanner;
  final DateTime Function() _clock;

  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final Map<String, _ActiveTransfer> _active = <String, _ActiveTransfer>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final StreamController<DownloadTask> _taskController = StreamController<DownloadTask>.broadcast();

  bool _disposed = false;

  /// Tasks in insertion order.
  List<DownloadTask> get tasks => List<DownloadTask>.unmodifiable(_tasks.values);

  /// Task changes, including progress updates.
  Stream<DownloadTask> get onTaskChanged => _taskController.stream;

  /// Current configuration.
  DownloadConfig get config => _config;

  /// Number of transfers in flight.
  int get runningCount => _active.length;

  /// Whether another transfer could start right now.
  bool get canStartMore => _active.length < _config.maxConcurrent;

  /// The task with [id], or `null`.
  DownloadTask? task(String id) => _tasks[id];

  /// Adds [task] to the queue.
  ///
  /// Adding the same id twice replaces the previous task only when that task is
  /// terminal; replacing a running one would orphan its transfer.
  void add(DownloadTask task) {
    _ensureNotDisposed();
    final existing = _tasks[task.id];
    if (existing != null && !existing.isTerminal) {
      throw StateError('Task ${task.id} is already ${existing.status.name}.');
    }
    _emit(task.copyWith(status: DownloadStatus.queued));
    unawaited(_schedule());
  }

  /// Removes a task and any partial file it produced.
  Future<void> remove(String id, {bool deleteFile = false}) async {
    _ensureNotDisposed();
    await pause(id);
    _retryTimers.remove(id)?.cancel();
    final task = _tasks.remove(id);
    if (task != null && deleteFile) {
      await _files.delete(task.filePath);
    }
    if (task != null && !_taskController.isClosed) {
      _taskController.add(task.copyWith(status: DownloadStatus.cancelled));
    }
  }

  /// Queues [id] if it is not finished.
  Future<void> start(String id) async {
    _ensureNotDisposed();
    final task = _tasks[id];
    if (task == null || task.isTerminal || task.isRunning) {
      return;
    }
    _emit(task.copyWith(status: DownloadStatus.queued, clearError: true));
    await _schedule();
  }

  /// Suspends a running transfer, keeping the partial file.
  Future<void> pause(String id) async {
    _ensureNotDisposed();
    final task = _tasks[id];
    if (task == null || !task.isRunning) {
      return;
    }
    _retryTimers.remove(id)?.cancel();
    _active.remove(id)?.cancel();
    _emit(task.copyWith(status: DownloadStatus.paused));
  }

  /// Continues a paused or stopped task.
  Future<void> resume(String id) => start(id);

  /// Abandons [id]; the partial file is kept.
  Future<void> cancel(String id) async {
    _ensureNotDisposed();
    final task = _tasks[id];
    if (task == null || task.isTerminal) {
      return;
    }
    _retryTimers.remove(id)?.cancel();
    _active.remove(id)?.cancel();
    _emit(task.copyWith(status: DownloadStatus.cancelled));
  }

  /// Clears the retry budget and starts [id] again.
  Future<void> retry(String id) async {
    _ensureNotDisposed();
    final task = _tasks[id];
    if (task == null || task.isRunning) {
      return;
    }
    _retryTimers.remove(id)?.cancel();
    _emit(
      task.copyWith(
        status: DownloadStatus.queued,
        progress: task.progress.copyWith(attempt: 1),
        clearError: true,
      ),
    );
    await _schedule();
  }

  /// Removes every finished task.
  Future<void> clearCompleted() async {
    _ensureNotDisposed();
    for (final task in _tasks.values.where((task) => task.isTerminal).toList()) {
      _tasks.remove(task.id);
    }
  }

  /// Applies a new configuration and starts anything the new limit allows.
  Future<void> updateConfig(DownloadConfig config) async {
    _ensureNotDisposed();
    _config = config;
    _resumePlanner = DownloadResumePlanner(config: config);
    final transport = _transport;
    if (transport is HttpDownloadTransport) {
      transport.updateConfig(config);
    }
    await _schedule();
  }

  /// Releases the manager.
  ///
  /// Running transfers are paused, not cancelled: the partial files are valid
  /// work, and a host that rebuilds the manager resumes them.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    for (final id in _active.keys.toList()) {
      await pause(id);
    }
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _disposed = true;
    await _transport.dispose();
    await _taskController.close();
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  Future<void> _schedule() async {
    if (_disposed) {
      return;
    }
    while (canStartMore) {
      final next = _tasks.values.firstWhere(
        (task) => task.status == DownloadStatus.queued,
        orElse: () => DownloadTask(id: '', url: '', filePath: '', status: DownloadStatus.idle),
      );
      if (next.id.isEmpty) {
        return;
      }
      // Not awaited: a transfer runs until it finishes, and waiting here would
      // serialize the whole queue behind the first task.
      unawaited(_run(next.id));
    }
  }

  Future<void> _run(String id) async {
    final task = _tasks[id];
    if (task == null || task.isTerminal) {
      return;
    }

    final transfer = _ActiveTransfer(id);
    _active[id] = transfer;
    _emit(task.copyWith(status: DownloadStatus.running));

    try {
      await _transfer(task, transfer);
      _completed(id);
    } catch (error) {
      _failed(id, error);
    } finally {
      _active.remove(id);
      if (!_disposed) {
        unawaited(_schedule());
      }
    }
  }

  /// Performs one attempt at [task].
  Future<void> _transfer(DownloadTask task, _ActiveTransfer transfer) async {
    await _files.ensureParentDirectory(task.filePath);

    var startByte = 0;
    var localBytes = await _files.length(task.filePath);
    int? remoteBytes;
    var verified = true;

    if (localBytes > 0) {
      final probe = _resumePlanner.plan(localBytes: localBytes, remoteBytes: null, serverAcceptsRanges: true);
      switch (probe.decision) {
        case DownloadResumeDecision.restart:
          await _files.truncate(task.filePath, 0);
          localBytes = 0;
        case DownloadResumeDecision.resume:
          startByte = probe.startByte;
        case DownloadResumeDecision.alreadyComplete:
          startByte = 0;
          localBytes = 0;
      }
    }

    if (transfer.isCancelled) {
      return;
    }

    var response = await _transport.fetch(
      DownloadRequest(
        url: task.url,
        startByte: startByte,
        headers: task.headers,
        userAgent: _config.userAgent,
        timeout: _config.timeout,
        maxRedirects: _config.maxRedirects,
      ),
    );
    remoteBytes = response.resolvedTotalBytes;

    // A server that ignores Range answers 200 with the whole body: appending it
    // would duplicate everything already on disk, so the file restarts.
    if (startByte > 0 && !response.isPartial) {
      await _files.truncate(task.filePath, 0);
      startByte = 0;
      localBytes = 0;
      response = await _transport.fetch(
        DownloadRequest(
          url: task.url,
          startByte: 0,
          headers: task.headers,
          userAgent: _config.userAgent,
          timeout: _config.timeout,
          maxRedirects: _config.maxRedirects,
        ),
      );
      remoteBytes = response.resolvedTotalBytes;
    }

    final verifyBytes = _config.verifyTailBytes;
    var received = startByte;
    var head = <int>[];

    // With a resume, the first `verifyBytes` bytes are the verification: they
    // are compared with what is already on disk, and the file is truncated to
    // the resume offset so the verified bytes are written again.
    final needsVerification = startByte > 0 && verifyBytes > 0;

    await for (final chunk in response.byteStream) {
      if (transfer.isCancelled) {
        return;
      }
      if (chunk.isEmpty) {
        continue;
      }

      if (needsVerification && head.length < verifyBytes) {
        head.addAll(chunk);
        if (head.length >= verifyBytes) {
          final localTail = await _files.readTail(task.filePath, verifyBytes);
          verified = _resumePlanner.tailMatches(localTail: localTail, remoteTail: head.sublist(0, verifyBytes));
          if (!verified) {
            // The local file is not a prefix of the remote one; keeping it would
            // produce a file that plays up to exactly this offset.
            await _files.truncate(task.filePath, 0);
            throw const _ResumeMismatch();
          }
          await _files.truncate(task.filePath, startByte);
          await _files.append(task.filePath, head);
          received = startByte + head.length;
          _reportProgress(task, received, remoteBytes);
        }
        continue;
      }

      await _files.append(task.filePath, chunk);
      received += chunk.length;
      _reportProgress(task, received, remoteBytes, transfer: transfer);
    }

    if (needsVerification && head.length < verifyBytes) {
      // The server sent fewer bytes than the verification window: nothing can be
      // verified, so the attempt is treated as a failure rather than trusted.
      await _files.truncate(task.filePath, 0);
      throw const _ResumeMismatch();
    }

    if (!verified) {
      throw const _ResumeMismatch();
    }

    final total = remoteBytes;
    if (total != null && received < total) {
      // A stream that ends early is an incomplete file, not a finished one.
      throw StateError('Transfer ended at $received of $total bytes.');
    }

    _emit(
      _tasks[task.id]!.copyWith(
        status: DownloadStatus.completed,
        progress: DownloadProgress(receivedBytes: received, totalBytes: total ?? received, attempt: task.progress.attempt),
        clearError: true,
      ),
    );
  }

  void _reportProgress(DownloadTask task, int received, int? remoteBytes, {_ActiveTransfer? transfer}) {
    final current = _tasks[task.id];
    if (current == null || current.status != DownloadStatus.running) {
      return;
    }
    final lastReceived = current.progress.receivedBytes;
    final elapsed = _clock().difference(_lastTick);
    var speed = current.progress.speedBytesPerSecond;
    if (elapsed.inMilliseconds >= 200) {
      speed = ((received - lastReceived) * 1000 / elapsed.inMilliseconds).round().clamp(0, 1 << 40);
      _lastTick = _clock();
    }
    _emit(
      current.copyWith(
        progress: DownloadProgress(
          receivedBytes: received,
          totalBytes: remoteBytes ?? current.progress.totalBytes,
          speedBytesPerSecond: speed,
          attempt: current.progress.attempt,
        ),
      ),
    );
  }

  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  void _completed(String id) {
    final task = _tasks[id];
    if (task == null) {
      return;
    }
    if (!task.status.isTerminal) {
      _emit(task.copyWith(status: DownloadStatus.completed, clearError: true));
    }
  }

  void _failed(String id, Object error) {
    final task = _tasks[id];
    if (task == null || task.status.isTerminal) {
      return;
    }

    final attempt = task.progress.attempt;
    final canRetry = attempt < _config.maxAttempts && !(error is _ResumeMismatch);

    if (canRetry) {
      // Waiting instead of retrying immediately: a stream that just failed is
      // usually still failing, and hammering it is how an account gets locked.
      _emit(
        task.copyWith(
          status: DownloadStatus.stopped,
          progress: task.progress.copyWith(attempt: attempt + 1),
          error: error,
        ),
      );
      _retryTimers[id]?.cancel();
      _retryTimers[id] = Timer(_config.retryDelay, () {
        _retryTimers.remove(id);
        final current = _tasks[id];
        if (current == null || current.status != DownloadStatus.stopped) {
          return;
        }
        _emit(current.copyWith(status: DownloadStatus.queued));
        unawaited(_schedule());
      });
      return;
    }

    _emit(task.copyWith(status: DownloadStatus.failed, error: error));
  }

  void _emit(DownloadTask task) {
    _tasks[task.id] = task;
    if (!_taskController.isClosed) {
      _taskController.add(task);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('DownloadManager has been disposed.');
    }
  }
}

/// A resumed file turned out not to be a prefix of the remote one.
final class _ResumeMismatch implements Exception {
  const _ResumeMismatch();

  @override
  String toString() => 'The partial file does not match the remote file.';
}

/// Largest chunk appended at once, so a huge response does not become one write.
const int _maxChunkBytes = 1 << 20;

/// Kept for hosts that tune chunking; clamped to [_maxChunkBytes].
int clampChunkSize(int requested) => math.min(requested, _maxChunkBytes);
