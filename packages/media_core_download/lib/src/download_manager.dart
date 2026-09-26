import 'dart:async';

import 'package:media_core/media_core.dart';

import 'download_config.dart';
import 'download_file_sink.dart';
import 'download_progress.dart';
import 'download_resume.dart';
import 'download_status.dart';
import 'download_task.dart';
import 'download_transport.dart';

/// Decision trail for the download queue.
///
/// The questions a download bug report asks are all here: why did it not start
/// (queue capacity), why did it start over (the resume check rejected the
/// partial file), and why did it stop (retry budget spent, or a failure that is
/// not retryable).
final LogModule _log = MediaCoreLog.of(LogCategory.download);

/// The download queue.
///
/// Responsibilities:
///
/// - own the task list and each task's download status
/// - schedule transfers through the core task queue, which bounds concurrency
///   and orders work by priority
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
/// - **reimplement queueing or retry**: the core's [TaskManager] owns concurrency
///   and ordering, [TaskId]/[PlayerTask]/[TaskState] own task identity and
///   lifecycle, and [RetryUtils] owns the attempt policy
///
/// ## Why the core queue is used here
///
/// Capping concurrency, ordering by priority and cancelling in-flight work are
/// the same problems for a download as for a player operation, and the framework
/// already solves them once. A second scheduler inside this package would be a
/// second place to fix whenever scheduling is wrong, and it would report task
/// state in a vocabulary the rest of the framework does not understand.
///
/// ## What is genuinely download-specific
///
/// Two things, which is why this class is not just a wrapper:
///
/// - **pause**: a download can be suspended by the viewer and continued later.
///   The core queue's states are created/queued/running/terminal, so a paused
///   task leaves the queue while keeping its partial file — and does not silently
///   restart the moment a slot frees up.
/// - **resume verification**: a partial file is only appended to after its tail
///   has been proven to match the remote one (see [DownloadResumePlanner]).
///
/// ## Fixed concurrency
///
/// [DownloadConfig.maxConcurrent] is applied when the queue is created: the core
/// queue pins its capacity at construction, so changing the limit means building
/// a new manager rather than quietly keeping the old one.
final class DownloadManager {
  DownloadManager({
    DownloadTransport? transport,
    DownloadFileSink? files,
    DownloadConfig config = DownloadConfig.defaults,
    DownloadResumePlanner? resumePlanner,
    TaskManager? queue,
    DateTime Function()? clock,
  }) : _transport = transport ?? HttpDownloadTransport(config: config),
       _files = files ?? const IoDownloadFileSink(),
       _config = config,
       _resumePlanner = resumePlanner ?? DownloadResumePlanner(config: config),
       _queue = queue ?? TaskManager(maxConcurrentTasks: config.maxConcurrent),
       _clock = clock ?? DateTime.now;

  DownloadTransport _transport;
  final DownloadFileSink _files;
  DownloadConfig _config;
  DownloadResumePlanner _resumePlanner;

  /// Core task queue: concurrency, priority ordering and cancellation.
  final TaskManager _queue;

  final DateTime Function() _clock;

  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final Set<TaskId> _inFlight = <TaskId>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final StreamController<DownloadTask> _taskController = StreamController<DownloadTask>.broadcast();

  bool _disposed = false;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  /// Task type every download registers under.
  static final TaskType downloadTaskType = TaskType.custom('download');

  /// Tasks in insertion order.
  List<DownloadTask> get tasks => List<DownloadTask>.unmodifiable(_tasks.values);

  /// Task changes, including progress updates.
  Stream<DownloadTask> get onTaskChanged => _taskController.stream;

  /// Current configuration.
  DownloadConfig get config => _config;

  /// The core queue driving these downloads, for hosts that want its metrics.
  TaskManager get queue => _queue;

  /// Number of transfers in flight.
  int get runningCount => _queue.runningCount;

  /// Whether another transfer could start right now.
  bool get canStartMore => _queue.hasCapacity;

  /// The task with [id], or `null`.
  DownloadTask? task(String id) => _tasks[id];

  /// Adds [task] to the queue.
  ///
  /// Adding the same id twice replaces the previous task only when that task is
  /// terminal; replacing a running one would orphan its transfer.
  void add(DownloadTask task) {
    _ensureNotDisposed();
    final existing = _tasks[task.id.value];
    if (existing != null && !existing.isTerminal) {
      throw StateError('Task ${task.id} is already ${existing.status.name}.');
    }

    _log.info(
      'queued a download',
      fields: <String, Object?>{'id': task.id.value, 'url': task.url, 'priority': task.priority.name},
    );

    _register(task);
    _emit(task.copyWith(status: DownloadStatus.queued, clearError: true));
    unawaited(_pump());
  }

  /// Removes a task and any partial file it produced.
  Future<void> remove(String id, {bool deleteFile = false}) async {
    _ensureNotDisposed();
    await pause(id);
    _retryTimers.remove(id)?.cancel();
    _queue.remove(TaskId(id));
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

    if (_queue.get(TaskId(id)) == null) {
      _register(task);
    } else {
      _queue.queue(TaskId(id));
    }
    _emit(task.copyWith(status: DownloadStatus.queued, clearError: true));
    await _pump();
  }

  /// Suspends a running transfer, keeping the partial file.
  ///
  /// The task leaves the core queue: a paused download is not waiting for a
  /// slot, it is waiting for the viewer. Leaving it queued would restart it the
  /// moment capacity appeared.
  Future<void> pause(String id) async {
    _ensureNotDisposed();
    final task = _tasks[id];
    if (task == null || !task.isRunning) {
      return;
    }
    _log.info('pausing a download', fields: <String, Object?>{'id': id, 'receivedBytes': task.progress.receivedBytes});
    _retryTimers.remove(id)?.cancel();
    _queue.cancel(task.id, 'paused by the viewer');
    _inFlight.remove(task.id);
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
    _queue.cancel(task.id, 'cancelled by the viewer');
    _inFlight.remove(task.id);
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
    _queue.remove(TaskId(id));
    _register(task.copyWith(progress: task.progress.copyWith(attempt: 1)));
    _emit(task.copyWith(status: DownloadStatus.queued, progress: task.progress.copyWith(attempt: 1), clearError: true));
    await _pump();
  }

  /// Removes every finished task.
  Future<void> clearCompleted() async {
    _ensureNotDisposed();
    for (final task in _tasks.values.where((task) => task.isTerminal).toList()) {
      // The download view is keyed by the id value; the queue is keyed by the id.
      _tasks.remove(task.id.value);
      _queue.remove(task.id);
    }
  }

  /// Applies a new configuration.
  ///
  /// [DownloadConfig.maxConcurrent] is **not** applied: the core queue pins its
  /// capacity when it is created, so changing the limit means building a new
  /// manager.
  Future<void> updateConfig(DownloadConfig config) async {
    _ensureNotDisposed();
    _config = config;
    _resumePlanner = DownloadResumePlanner(config: config);
    final transport = _transport;
    if (transport is HttpDownloadTransport) {
      transport.updateConfig(config);
    }
    await _pump();
  }

  /// Releases the manager.
  ///
  /// Running transfers are paused, not cancelled: the partial files are valid
  /// work, and a host that rebuilds the manager resumes them.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    for (final id in _inFlight.toList()) {
      await pause(id.value);
    }
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _disposed = true;
    // TaskManager.dispose is synchronous.
    _queue.dispose();
    await _transport.dispose();
    await DisposeUtils.close(_taskController);
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Registers [task] with the core queue and puts it in the queue.
  ///
  /// The core separates the two on purpose — a task can exist without being
  /// scheduled — so both steps are needed here: a download the viewer asked for
  /// is work to do, not a record of work.
  void _register(DownloadTask task) {
    _queue.register(
      PlayerTask(
        id: task.id,
        type: downloadTaskType,
        priority: task.priority,
        context: TaskContext(
          source: task.url,
          description: task.title ?? task.fileName,
          metadata: <String, Object?>{'filePath': task.filePath},
        ),
      ),
    );
    _queue.queue(task.id);
  }

  /// Runs as many queued transfers as the core queue has capacity for.
  ///
  /// The queue decides *how many* and *which one*; this only keeps asking while
  /// it can still hand out work.
  Future<void> _pump() async {
    if (_disposed) {
      return;
    }
    while (!_disposed && _queue.hasCapacity && _queue.hasQueuedTasks) {
      // Not awaited: a transfer runs until it finishes, and waiting here would
      // serialize the whole queue behind the first task.
      unawaited(_executeNext());
    }
  }

  Future<void> _executeNext() async {
    if (_disposed) {
      return;
    }

    try {
      await _queue.execute((coreTask) async {
        final id = coreTask.id.value;
        final task = _tasks[id];
        if (task == null || task.isTerminal) {
          return null;
        }

        _inFlight.add(task.id);
        _log.debug(
          'transfer started',
          fields: <String, Object?>{'id': id, 'attempt': task.progress.attempt, 'priority': task.priority.name},
        );
        _emit(task.copyWith(status: DownloadStatus.running, clearError: true));
        try {
          await _transfer(task);
          _complete(id);
          return null;
        } catch (error) {
          // Rethrown on purpose: the core queue is what records a failed task.
          // Swallowing it here would leave the task completed while the download
          // is broken, and a retry would then be refused because the task is
          // already terminal.
          Error.throwWithStackTrace(error, StackTrace.current);
        } finally {
          _inFlight.remove(task.id);
        }
      });
    } on TaskExecutionFailure catch (failure) {
      // The core queue records the failure on the task and throws it here: this
      // is the queue's verdict, and the only place a download learns that its
      // transfer failed.
      _fail(failure.task.id.value, failure.error);
    } catch (_) {
      // A failure that is not the task's own (the queue was disposed, or the
      // task was cancelled) has already been reflected in the download status.
    }

    if (!_disposed && _queue.hasQueuedTasks) {
      await _pump();
    }
  }

  /// Performs one transfer attempt, restarting once if the partial file cannot
  /// be trusted.
  ///
  /// A mismatch is not a failure: the attempt restarts from zero, which is the
  /// point of verifying before appending. Only a *second* mismatch — from a file
  /// this attempt just wrote — is reported.
  Future<void> _transfer(DownloadTask task) async {
    await _files.ensureParentDirectory(task.filePath);

    var resumable = await _files.length(task.filePath) > 0;
    if (resumable) {
      _log.debug(
        'partial file found; resuming after verification',
        fields: <String, Object?>{'id': task.id.value, 'localBytes': await _files.length(task.filePath)},
      );
    }
    while (true) {
      try {
        await _transferOnce(task, resume: resumable);
        return;
      } on _ResumeMismatch {
        if (!resumable) {
          rethrow;
        }
        // The tail check rejected the file on disk: it is not a prefix of the
        // remote one, so the only correct move is to start over rather than
        // append to bytes that would never play.
        _log.warning(
          'partial file did not match the remote file; restarting from zero',
          fields: <String, Object?>{'id': task.id.value},
        );
        await _files.truncate(task.filePath, 0);
        resumable = false;
      }
    }
  }

  Future<void> _transferOnce(DownloadTask task, {required bool resume}) async {
    var startByte = 0;
    final localBytes = await _files.length(task.filePath);
    int? remoteBytes;
    var verified = true;

    if (resume && localBytes > 0) {
      final probe = _resumePlanner.plan(localBytes: localBytes, remoteBytes: null, serverAcceptsRanges: true);
      switch (probe.decision) {
        case DownloadResumeDecision.restart:
          await _files.truncate(task.filePath, 0);
        case DownloadResumeDecision.resume:
          startByte = probe.startByte;
        case DownloadResumeDecision.alreadyComplete:
          startByte = 0;
      }
    }

    if (!_inFlight.contains(task.id)) {
      return;
    }

    var response = await _transport.fetch(_requestFor(task, startByte));
    remoteBytes = response.resolvedTotalBytes;

    // A server that ignores Range answers 200 with the whole body: appending it
    // would duplicate everything already on disk, so the file restarts.
    if (startByte > 0 && !response.isPartial) {
      await _files.truncate(task.filePath, 0);
      startByte = 0;
      response = await _transport.fetch(_requestFor(task, 0));
      remoteBytes = response.resolvedTotalBytes;
    }

    final verifyBytes = _config.verifyTailBytes;
    var received = startByte;
    var head = <int>[];

    // With a resume, the first `verifyBytes` bytes are the verification: they
    // are compared with what is already on disk, and the file is truncated back
    // to the resume offset so the verified bytes are written again.
    final needsVerification = startByte > 0 && verifyBytes > 0;

    await for (final chunk in response.byteStream) {
      if (!_inFlight.contains(task.id)) {
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
      _reportProgress(task, received, remoteBytes);
    }

    if (needsVerification && head.length < verifyBytes) {
      // Fewer bytes than the verification window: nothing can be verified, so
      // the attempt is not trusted.
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
      _tasks[task.id.value]!.copyWith(
        status: DownloadStatus.completed,
        progress: DownloadProgress(
          receivedBytes: received,
          totalBytes: total ?? received,
          attempt: task.progress.attempt,
        ),
        clearError: true,
      ),
    );
  }

  DownloadRequest _requestFor(DownloadTask task, int startByte) {
    return DownloadRequest(
      url: task.url,
      startByte: startByte,
      headers: task.headers,
      userAgent: _config.userAgent,
      timeout: _config.timeout,
      maxRedirects: _config.maxRedirects,
    );
  }

  void _reportProgress(DownloadTask task, int received, int? remoteBytes) {
    final current = _tasks[task.id.value];
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

  void _complete(String id) {
    final task = _tasks[id];
    if (task == null || task.status.isTerminal) {
      return;
    }
    _log.info(
      'download completed',
      fields: <String, Object?>{'id': id, 'bytes': task.progress.receivedBytes, 'filePath': task.filePath},
    );
    _emit(task.copyWith(status: DownloadStatus.completed, clearError: true));
  }

  /// Reports a failure and decides between waiting for a retry and giving up.
  ///
  /// The attempt budget and the backoff come from the core's [RetryUtils], so a
  /// download backs off the same way the rest of the framework does instead of
  /// growing a second retry policy.
  void _fail(String id, Object error) {
    final task = _tasks[id];
    if (task == null || task.status.isTerminal || task.status == DownloadStatus.paused) {
      return;
    }

    final attempt = task.progress.attempt;
    final mayRetry =
        error is! _ResumeMismatch && RetryUtils.until(_config.maxAttempts)(error, StackTrace.current, attempt);

    if (!mayRetry) {
      _log.error(
        'download failed; no attempts left',
        error: error,
        fields: <String, Object?>{'id': id, 'attempt': attempt, 'url': task.url},
      );
      _queue.fail(TaskId(id), error);
      _emit(task.copyWith(status: DownloadStatus.failed, error: error));
      return;
    }

    final delay = RetryUtils.backoff(attempt, base: _config.retryDelay);
    _log.warning(
      'download attempt failed; retrying',
      error: error,
      fields: <String, Object?>{
        'id': id,
        'attempt': attempt,
        'maxAttempts': _config.maxAttempts,
        'delayMs': delay.inMilliseconds,
      },
    );
    _emit(
      task.copyWith(
        status: DownloadStatus.stopped,
        progress: task.progress.copyWith(attempt: attempt + 1),
        error: error,
      ),
    );
    _retryTimers[id]?.cancel();
    _retryTimers[id] = Timer(delay, () {
      _retryTimers.remove(id);
      final current = _tasks[id];
      if (current == null || current.status != DownloadStatus.stopped || _disposed) {
        return;
      }
      _emit(current.copyWith(status: DownloadStatus.queued));
      // A fresh core task: the previous one is terminal, and a terminal task
      // cannot be queued again.
      _queue.remove(current.id);
      _register(current);
      unawaited(_pump());
    });
  }

  void _emit(DownloadTask task) {
    _tasks[task.id.value] = task;
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
