part of 'task_manager.dart';

/// Queueing, execution, completion and in-place update.
///
/// The manager owns the task lifecycle; the [TaskScheduler] inside it only
/// orders the queue and hands out execution slots.
extension TaskManagerExecution on TaskManager {
  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  /// Queues a registered task.
  ///
  /// A created task is transitioned:
  ///
  /// ```text
  /// created → queued
  /// ```
  ///
  /// An already queued task remains queued.
  bool queue(TaskId id) {
    _checkNotDisposed();

    final task = _requireTask(id);

    if (task.isTerminal || task.isRunning) {
      return false;
    }

    final queuedTask = task.isQueued ? task : task.queue();

    final scheduled = _scheduler.scheduleOrReplace(queuedTask);

    if (!scheduled) {
      return false;
    }

    _tasks[id] = queuedTask;

    return true;
  }

  /// Removes a queued task from scheduler membership.
  ///
  /// The task lifecycle state is unchanged.
  ///
  /// Use [cancel] when the task should become cancelled.
  PlayerTask? unschedule(TaskId id) {
    _checkNotDisposed();

    return _scheduler.unschedule(id);
  }

  /// Clears all queued tasks without changing their lifecycle state.
  void clearQueue() {
    _checkNotDisposed();

    _scheduler.clearQueue();
  }

  /// Removes queued tasks matching [test].
  ///
  /// The lifecycle state of removed tasks is not changed.
  int removeQueuedWhere(bool Function(PlayerTask task) test) {
    _checkNotDisposed();

    return _scheduler.removeWhere(test);
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Executes one available task.
  ///
  /// Lifecycle:
  ///
  /// ```text
  /// queued
  ///   ↓
  /// running
  ///   ├── completed
  ///   ├── failed
  ///   └── cancelled
  /// ```
  ///
  /// [TaskScheduler.takeNext] performs the scheduling transition from
  /// queued to running and reserves the execution slot.
  ///
  /// [TaskManager] then owns the actual execution and final lifecycle state.
  Future<PlayerTask?> execute(FutureOr<Object?> Function(PlayerTask task) handler) async {
    _checkNotDisposed();

    final task = _scheduler.takeNext();

    if (task == null) {
      return null;
    }

    _tasks[task.id] = task;

    final token = _cancelTokens.putIfAbsent(task.id, TaskCancelToken.new);

    try {
      if (token.isCancelled) {
        return _cancelTaskAfterExecution(task, token.reason);
      }

      final result = await handler(task);

      if (token.isCancelled) {
        return _cancelTaskAfterExecution(task, token.reason);
      }

      final completedTask = task.complete(result: result);

      if (!_isDisposed) {
        _tasks[task.id] = completedTask;
      }

      return completedTask;
    } catch (error, stackTrace) {
      if (token.isCancelled) {
        return _cancelTaskAfterExecution(task, token.reason ?? error);
      }

      final failedTask = task.fail(error: error);

      if (!_isDisposed) {
        _tasks[task.id] = failedTask;
      }

      Error.throwWithStackTrace(
        TaskExecutionFailure(task: failedTask, error: error, stackTrace: stackTrace),
        stackTrace,
      );
    } finally {
      // Cancellation is cooperative. The scheduler slot remains occupied
      // until the actual handler finishes.
      _scheduler.release(task.id);

      _disposeToken(task.id);
    }
  }

  /// Executes all tasks that can currently acquire an execution slot.
  ///
  /// At most [maxConcurrentTasks] tasks are started by this call.
  ///
  /// Results are returned in execution-start order.
  ///
  /// This method intentionally does not recursively refill slots after a task
  /// finishes. It represents the currently available scheduling capacity.
  Future<List<PlayerTask>> executeAvailable(FutureOr<Object?> Function(PlayerTask task) handler) async {
    _checkNotDisposed();

    final futures = <Future<PlayerTask>>[];

    while (!_isDisposed && _scheduler.hasCapacity && _scheduler.hasQueuedTasks) {
      final future = execute(handler);

      futures.add(
        future.then((task) {
          if (task == null) {
            throw StateError('Task execution unexpectedly returned null.');
          }

          return task;
        }),
      );
    }

    if (futures.isEmpty) {
      return const <PlayerTask>[];
    }

    final results = await Future.wait(futures);

    return List<PlayerTask>.unmodifiable(results);
  }

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  /// Marks a running task as completed.
  ///
  /// This API is intended for externally coordinated execution where the
  /// caller itself controls the underlying work.
  ///
  /// When used with [execute], the handler should normally be allowed to
  /// finish naturally instead of calling this method from another execution
  /// path.
  PlayerTask? complete(TaskId id, [Object? result]) {
    _checkNotDisposed();

    final task = _scheduler.findRunning(id);

    if (task == null) {
      return null;
    }

    final completedTask = task.complete(result: result);

    _tasks[id] = completedTask;

    _scheduler.release(id);
    _disposeToken(id);

    return completedTask;
  }

  /// Marks a running task as failed.
  ///
  /// This API is intended for externally coordinated execution.
  PlayerTask? fail(TaskId id, [Object? error]) {
    _checkNotDisposed();

    final task = _scheduler.findRunning(id);

    if (task == null) {
      return null;
    }

    final failedTask = task.fail(error: error);

    _tasks[id] = failedTask;

    _scheduler.release(id);
    _disposeToken(id);

    return failedTask;
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Updates a registered task.
  ///
  /// Running tasks cannot be replaced.
  ///
  /// Queued tasks are synchronized with the scheduler.
  bool update(PlayerTask task) {
    _checkNotDisposed();

    final previous = _tasks[task.id];

    if (previous == null) {
      return false;
    }

    if (previous.isRunning || _scheduler.isRunning(task.id)) {
      return false;
    }

    if (task.isQueued) {
      final scheduled = _scheduler.scheduleOrReplace(task);

      if (!scheduled) {
        return false;
      }
    } else {
      _scheduler.unschedule(task.id);
    }

    _tasks[task.id] = task;

    return true;
  }
}
