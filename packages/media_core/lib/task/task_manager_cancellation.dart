part of 'task_manager.dart';

/// Cancellation, removal and cancellation-token bookkeeping.
extension TaskManagerCancellation on TaskManager {
  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  /// Cancels a task.
  ///
  /// Behavior:
  ///
  /// ```text
  /// created
  ///   → cancelled
  ///
  /// queued
  ///   → cancelled
  ///
  /// running
  ///   → cancellation requested
  ///   → cancelled when execution observes cancellation / finishes
  ///
  /// terminal
  ///   → unchanged
  /// ```
  ///
  /// Running tasks are cancelled cooperatively.
  ///
  /// Most importantly, cancelling a running task does NOT immediately
  /// release the scheduler execution slot.
  ///
  /// The slot is released by [execute] only after the actual handler returns
  /// or throws.
  PlayerTask? cancel(TaskId id, [Object? reason]) {
    _checkNotDisposed();

    final task = _tasks[id];

    if (task == null) {
      return null;
    }

    if (task.isTerminal) {
      return task;
    }

    final token = _cancelTokens[id];

    token?.cancel(reason);

    if (task.isQueued) {
      _scheduler.unschedule(id);
    }

    final cancelledTask = task.cancel(error: reason);

    _tasks[id] = cancelledTask;

    return cancelledTask;
  }

  /// Cancels all non-terminal tasks.
  ///
  /// Running execution slots remain occupied until their handlers actually
  /// finish.
  ///
  /// Returns the number of cancellation requests issued.
  int cancelAll([Object? reason]) {
    _checkNotDisposed();

    final ids = _tasks.values.where((task) => !task.isTerminal).map((task) => task.id).toList(growable: false);

    for (final id in ids) {
      cancel(id, reason);
    }

    return ids.length;
  }

  /// Cancels all queued tasks.
  ///
  /// Running tasks are not affected.
  List<PlayerTask> cancelQueuedTasks([Object? reason]) {
    _checkNotDisposed();

    final queued = _scheduler.queuedTasks;

    if (queued.isEmpty) {
      return const <PlayerTask>[];
    }

    _scheduler.clearQueue();

    final cancelled = <PlayerTask>[];

    for (final task in queued) {
      final cancelledTask = task.cancel(error: reason);

      _tasks[task.id] = cancelledTask;
      cancelled.add(cancelledTask);
    }

    return List<PlayerTask>.unmodifiable(cancelled);
  }

  // ---------------------------------------------------------------------------
  // Removal
  // ---------------------------------------------------------------------------

  /// Removes a task from the manager.
  ///
  /// Terminal and non-running tasks can be removed immediately.
  ///
  /// A task that still occupies an execution slot receives a cancellation
  /// request but remains registered until its handler actually finishes.
  PlayerTask? remove(TaskId id) {
    _checkNotDisposed();

    final task = _tasks[id];

    if (task == null) {
      return null;
    }

    if (task.isRunning || _scheduler.isRunning(id)) {
      return cancel(id);
    }

    if (!task.isTerminal) {
      cancel(id);
    }

    _scheduler.unschedule(id);
    _disposeToken(id);

    return _tasks.remove(id);
  }

  /// Removes all terminal tasks.
  ///
  /// A terminal task that still occupies an execution slot is kept until its
  /// handler finishes, because that handler registers its result afterwards.
  ///
  /// Returns the number of removed tasks.
  int removeTerminal() {
    _checkNotDisposed();

    final executingIds = _scheduler.runningTaskIds;

    final ids = _tasks.values
        .where((task) => task.isTerminal && !executingIds.contains(task.id))
        .map((task) => task.id)
        .toList(growable: false);

    for (final id in ids) {
      _scheduler.unschedule(id);
      _disposeToken(id);
      _tasks.remove(id);
    }

    return ids.length;
  }

  /// Clears all tasks that are not actively executing.
  ///
  /// Running tasks receive cancellation requests and remain registered until
  /// their asynchronous execution finishes.
  void clear() {
    _checkNotDisposed();

    // Execution slots decide which tasks are still running, not lifecycle
    // state: cancelling a running task rewrites it to a terminal task, so
    // `isRunning` is false while its handler keeps executing and will write
    // its result back into the registry when it finishes.
    final executingIds = _scheduler.runningTaskIds;

    for (final id in _tasks.keys.toList(growable: false)) {
      final task = _tasks[id];

      if (task == null) {
        continue;
      }

      if (!task.isTerminal) {
        cancel(id);
      }
    }

    _scheduler.clearQueue();

    final removableIds = _tasks.keys.where((id) => !executingIds.contains(id)).toList(growable: false);

    for (final id in removableIds) {
      _disposeToken(id);
      _tasks.remove(id);
    }

    _disposeCompletedTokens();
  }

  // ---------------------------------------------------------------------------
  // Cancellation tokens
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Cancellation tokens
  // ---------------------------------------------------------------------------

  /// Returns the cancellation token for [id], if one exists.
  TaskCancelToken? cancelToken(TaskId id) {
    return _cancelTokens[id];
  }

  /// Creates or returns the cancellation token associated with [id].
  ///
  /// The task must already be registered.
  TaskCancelToken createCancelToken(TaskId id) {
    _checkNotDisposed();

    if (!_tasks.containsKey(id)) {
      throw StateError('Task "$id" is not registered.');
    }

    return _cancelTokens.putIfAbsent(id, TaskCancelToken.new);
  }
}
