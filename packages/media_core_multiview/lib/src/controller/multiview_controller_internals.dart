part of 'multiview_controller.dart';

/// Cell lifecycle internals: opening a cell, watching its progress,
/// stall recovery and snapshot emission.
extension _MultiviewControllerInternals on MultiviewController {
  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Runs [action] for cell [index] so that operations targeting the same cell
  /// settle in order instead of overlapping. Two overlapping opens would each
  /// acquire a player for the index and leak one (the loser is stored over or
  /// dropped), and a clear landing mid-open would detach a player the open was
  /// still attaching. Operations for *different* cells still overlap freely -
  /// that overlap is what keeps a wall fill fast.
  Future<void> _sequenced(int index, Future<void> Function() action) {
    if (_runningCellOps.contains(index)) {
      // Called from inside the operation already running for this cell (the
      // playlist advance a failed open triggers for its own cell): queueing
      // would wait for ourselves forever, and this continuation *is* the same
      // logical operation.
      return action();
    }
    final previous = _cellOps.remove(index);
    final Future<void> tracked;
    if (previous == null) {
      // Registered BEFORE action() runs, not around its returned future: the
      // synchronous prefix of action() can already descend into a same-index
      // _sequenced call (an open failing straight into a playlist advance),
      // and that call must see the cell as running - otherwise it queues
      // behind this very operation, which is awaiting it, and deadlocks.
      _runningCellOps.add(index);
      tracked = action().whenComplete(() => _runningCellOps.remove(index));
    } else {
      // A previous operation for this cell is still settling; this one runs
      // after it and through its error, so one failed open cannot poison the
      // next operation in the chain. Registered before action() for the same
      // reason as the direct branch above.
      tracked = previous.catchError((Object _) {}).then((_) {
        _runningCellOps.add(index);
        return action().whenComplete(() => _runningCellOps.remove(index));
      });
    }
    _cellOps[index] = tracked;
    return tracked;
  }

  Future<void> _openCell(MultiviewCell cell) async {
    final source = cell.source;
    if (source == null) {
      return;
    }

    if (!source.isLive) {
      // A room the platform reports as offline needs no player: opening one
      // would show an error the viewer already knows the reason for.
      _log.debug(
        'cell is offline; no player opened',
        fields: <String, Object?>{'index': cell.index, 'roomId': source.roomId},
      );
      cell
        ..status = MultiviewCellStatus.offline
        ..qualityLabel = null;
      await _releaseCell(cell.index);
      return;
    }

    _log.debug(
      'opening a cell',
      fields: <String, Object?>{
        'index': cell.index,
        'roomId': source.roomId,
        'uri': source.source.uri,
        'restarts': cell.restarts,
        'preference': _preferenceFor(cell.index).name,
      },
    );

    cell
      ..status = MultiviewCellStatus.starting
      ..failure = null;
    _emit();

    try {
      await _renewSourceIfExpired(cell);
      if (_disposed) {
        return;
      }
      final resolved = await _resolveForCell(cell);
      if (_disposed) {
        return;
      }
      final handle = await _handleFor(cell.index);

      // A dispose that lands while this open was parked must not leave the
      // acquired player attached: nothing will ever watch it, and the pool
      // would hand the recycled player - with its live subscription - to the
      // next cell.
      if (_disposed) {
        await _releaseCell(cell.index);

        return;
      }

      await handle.open(resolved.source, autoPlay: true);

      if (_disposed) {
        await _releaseCell(cell.index);

        return;
      }

      cell
        ..status = MultiviewCellStatus.playing
        ..qualityLabel = resolved.qualityLabel;
      _log.info(
        'cell is playing',
        fields: <String, Object?>{'index': cell.index, 'roomId': resolved.roomId, 'quality': resolved.qualityLabel},
      );
      _watchProgress(cell.index, handle);
      await _applyAudio();
      // Publish the starting -> playing transition: hosts mirror the wall
      // through this snapshot, and without it a cell stays "resolving" on the
      // host side — audio plays while the video widget never mounts.
      _emit();
    } catch (error, stackTrace) {
      cell.failure = MultiviewCellFailure(
        kind: MultiviewCellFailureKind.startFailure,
        message: error.toString(),
        attempt: cell.restarts + 1,
        cause: error,
      );
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'cell failed to open',
        error: error,
        fields: <String, Object?>{'index': cell.index, 'roomId': source.roomId},
      );
      // A cell that cannot open might still have somewhere to go: a playlist
      // moves on, which is what turns a dead room into the next live one.
      // Rate-limited, or a playlist whose entries all fail cycles forever.
      if (_playlists.containsKey(cell.index)) {
        final last = _lastAdvanceAt[cell.index];
        // The injected clock, not DateTime.now(): the stall watchdog and the
        // stall-side advance gate are already clock-driven, and a wall built
        // with a deterministic clock would otherwise rate-limit advances
        // against real wall time.
        final now = _clock();

        if (last == null || now.difference(last) >= config.cellStallTimeout) {
          _lastAdvanceAt[cell.index] = now;
          unawaited(advanceCell(cell.index));
        }

        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _renewSourceIfExpired(MultiviewCell cell) async {
    final source = cell.source;
    if (source == null) {
      return;
    }
    if (!source.isExpired(_clock())) {
      return;
    }
    final renew = source.renew;
    if (renew == null) {
      return;
    }
    final renewed = await renew(source);
    if (renewed != null) {
      cell.source = renewed;
    }
  }

  Future<MultiviewCellSource> _resolveForCell(MultiviewCell cell) async {
    final resolver = qualityResolver;
    final source = cell.source!;
    if (resolver == null) {
      return source;
    }
    return await resolver(source, _preferenceFor(cell.index));
  }

  MultiviewQualityPreference _preferenceFor(int index) {
    if (_config.qualityPolicy == MultiviewQualityPolicy.uniform) {
      return MultiviewQualityPreference.best;
    }
    return index == _focusedIndex ? MultiviewQualityPreference.best : MultiviewQualityPreference.lowest;
  }

  Future<PoolPlayerHandle> _handleFor(int index) async {
    final existing = _handles[index];
    if (existing != null && !existing.isDisposed) {
      return existing;
    }
    final handle = await _players.acquire();
    _handles[index] = handle;
    // Stamp the acquired player onto the cell: hosts resolve the video
    // surface by reading the cell's playerId against the kernel.
    _cells[index].playerId = handle.id;
    _log.info('cell player acquired', fields: {'index': index});
    return handle;
  }

  Future<void> _releaseCell(int index) async {
    // Every per-cell bookkeeping entry is detached synchronously, before the
    // first await: a resize shrink fires these releases unawaited, so an
    // assign() to the same index that lands while a release is parked at an
    // await must not find the old handle still registered in _handles (it
    // would bind to a player this release is about to pause and recycle), and
    // a shrink that is followed by a re-grow must not inherit the removed
    // cell's playlist, volume override or watchdog state.
    final subscription = _progressSubscriptions.remove(index);
    _progress.remove(index);
    _cellVolumes.remove(index);
    _lastAdvanceAt.remove(index);
    _restartedAt.remove(index);
    final handle = _handles.remove(index);
    // The cell is captured before any await: a wall that shrinks and re-grows
    // while this release is parked would otherwise let the deferred
    // `playerId = null` below land on the NEW cell at this index and hide its
    // freshly acquired player from the host. A removed index has no cell left
    // to stamp, so the capture is simply null there.
    final cell = index < _cells.length ? _cells[index] : null;
    await subscription?.cancel();
    if (handle == null) {
      return;
    }
    cell?.playerId = null;
    try {
      await handle.pause();
    } on Object catch (error) {
      // A player that refuses to pause still goes back to the pool.
      _log.debug('cell player pause failed before recycle', error: error, fields: {'index': index});
    }
    await handle.recycle();
    // Back to the host, which may return it from the kernel's instance pool: a
    // wall that keeps switching rooms must not pay for a cold player each time.
    await _players.release(handle);
    _log.info('cell player released', fields: {'index': index});
  }

  void _watchProgress(int index, PoolPlayerHandle handle) {
    unawaited(_progressSubscriptions.remove(index)?.cancel());
    _progress[index] = (position: Duration.zero, at: _clock());
    _progressSubscriptions[index] = handle.playbackStream.listen(
      (state) => _noteProgress(index, state.position, alive: state.buffering || state.isPlaying),
      onError: (Object error) {
        _log.debug('cell playback stream error', error: error, fields: {'index': index});
      },
    );
  }

  void _noteProgress(int index, Duration position, {bool alive = false}) {
    final previous = _progress[index];
    if (previous == null) {
      return;
    }

    if (position != previous.position) {
      // One clock read per event: this handler runs for every transport
      // update of every cell, so a wall of N players multiplies it.
      final now = _clock();
      _progress[index] = (position: position, at: now);

      // Stability retires the restart budget: a cell that has played cleanly
      // for a stall window since its last restart is not "one hiccup away
      // from permanent dark" any more.
      final restartedAt = _restartedAt[index];

      if (restartedAt != null && now.difference(restartedAt) >= _config.cellStallTimeout) {
        _restartedAt.remove(index);
        final cell = index < _cells.length ? _cells[index] : null;

        if (cell != null && cell.restarts > 0) {
          cell.restarts = 0;
        }
      }

      return;
    }

    if (alive) {
      // A position that has not moved while the engine reports buffering or
      // playing is a re-buffering cell, not a dead one: the liveness clock
      // refreshes so the stall detector does not restart it mid-recovery.
      _progress[index] = (position: previous.position, at: _clock());
    }
  }

  Future<void> _applyAudio() async {
    if (_cells.isEmpty) {
      return;
    }

    // The audio mode decides the level, and a per-cell volume only overrides it
    // where that cell is the one being listened to. Two rules matter here:
    //
    // * Muting the wall is authoritative. A host restores each room's own saved
    //   volume through `setCellVolume` when a cell starts, so letting the
    //   override win also let the wall keep playing at full volume with the mute
    //   button on.
    // * In exclusive mode every non-focused cell stays at `backgroundVolume`
    //   (silent by default) even when it carries an override, otherwise the
    //   whole wall is audible at once and switching the audio focus changes
    //   nothing.
    final changes = <Future<void>>[];
    for (final cell in _cells) {
      final handle = _handles[cell.index];
      if (handle == null) {
        continue;
      }

      final desired = switch (_config.audioMode) {
        MultiviewAudioMode.muted => 0.0,
        MultiviewAudioMode.mixed => _cellVolumes[cell.index] ?? _config.focusedVolume,
        MultiviewAudioMode.exclusive =>
          cell.index == (_audioIndex ?? _focusedIndex)
              ? _cellVolumes[cell.index] ?? _config.focusedVolume
              : _config.backgroundVolume,
      };

      cell.hasAudioFocus = desired > 0;
      changes
        ..add(handle.setVolume(desired))
        ..add(handle.setMute(muted: desired <= 0));
    }
    // Applied in parallel: every focus switch re-levels every handle on the
    // wall, and awaiting each engine call in turn is what makes the switch
    // feel laggy - N cells means N serialized round-trips before the new
    // focus is actually audible. The decisions above are already final, so
    // the order the engine sees them in does not matter.
    await Future.wait(changes);
  }

  Future<void> _applyQuality() async {
    final resolver = qualityResolver;
    if (resolver == null || !_config.degradeQualityWhenCrowded) {
      return;
    }
    // The desired quality is reported per cell; the host decides when to act on
    // it. A wall does not tear down a playing stream to change its ladder mid
    // wall — that would cost every other cell a re-buffer.
    for (final cell in _cells) {
      if (cell.isEmpty) {
        continue;
      }
      cell.hasVideoFocus = cell.index == _focusedIndex;
    }
  }

  void _applyDanmakuRouting() {
    for (final cell in _cells) {
      cell.hasVideoFocus = cell.index == _focusedIndex;
      final session = cell.danmaku;
      if (session == null) {
        continue;
      }
      // One queue per cell, fed only while the cell is the one being read.
      final shouldFeed = !_config.danmakuOnlyOnFocused || cell.index == _focusedIndex;
      session.setEnabled(enabled: shouldFeed);
    }
  }

  // ---------------------------------------------------------------------------
  // Progress tick and stall recovery
  // ---------------------------------------------------------------------------

  void _startTicking() {
    _tick = Timer.periodic(MultiviewController._tickInterval, (_) => unawaited(_checkCells()));
  }

  /// Watches every playing cell for a stall.
  ///
  /// The core's live watchdogs own the *main* player; a wall of N cells needs
  /// the same idea per cell, with its own restart budget, because one dead
  /// stream must not take the wall down with it.
  Future<void> _checkCells() async {
    if (_disposed || _sweeping) {
      return;
    }
    _sweeping = true;
    try {
      await _sweepCells();
    } on Object catch (error) {
      // The timer fires this unawaited; a throwing sweep (a disposed pool, a
      // shrunken wall mid-iteration) must land in the log, not the zone.
      _log.warning('cell sweep failed', error: error);
    } finally {
      _sweeping = false;
    }
  }

  Future<void> _sweepCells() async {
    final now = _clock();
    for (final cell in _cells) {
      if (!cell.isPlaying) {
        continue;
      }
      final progress = _progress[cell.index];
      if (progress == null) {
        continue;
      }
      if (now.difference(progress.at) < _config.cellStallTimeout) {
        continue;
      }
      await _handleStall(cell);
    }

    await _applyBudget();
  }

  Future<void> _handleStall(MultiviewCell cell) {
    // Sequenced per index: a stall restart racing a host assign for the same
    // cell would release the player that assign was about to attach, or
    // re-point it after the attach and leave the cell showing a source that
    // is not the one it reports.
    return _sequenced(cell.index, () => _handleStallNow(cell));
  }

  Future<void> _handleStallNow(MultiviewCell cell) async {
    _log.warning(
      'cell stalled',
      fields: <String, Object?>{
        'index': cell.index,
        'roomId': cell.source?.roomId,
        'restarts': cell.restarts,
        'maxRestarts': _config.cellMaxRestarts,
        'timeoutSeconds': _config.cellStallTimeout.inSeconds,
      },
    );

    cell.failure = MultiviewCellFailure(
      kind: MultiviewCellFailureKind.stallFailure,
      message: 'No progress for ${_config.cellStallTimeout.inSeconds}s',
      attempt: cell.restarts + 1,
    );

    if (cell.restarts >= _config.cellMaxRestarts) {
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'cell stalled past its restart budget',
        fields: <String, Object?>{
          'index': cell.index,
          'roomId': cell.source?.roomId,
          'restarts': cell.restarts,
          'hasPlaylist': _playlists.containsKey(cell.index),
        },
      );
      _emit();
      // Out of restarts: a playlist cell moves on, which is the difference
      // between a wall that watches and one that stares at a frozen frame.
      // Rate-limited like the open-failure path, or a playlist of dead rooms
      // cycles the wall forever.
      if (_playlists.containsKey(cell.index)) {
        final last = _lastAdvanceAt[cell.index];
        final advanceNow = _clock();

        if (last == null || advanceNow.difference(last) >= _config.cellStallTimeout) {
          _lastAdvanceAt[cell.index] = advanceNow;
          await advanceCell(cell.index);
        }
      }
      return;
    }

    cell.restarts++;
    cell.status = MultiviewCellStatus.recovering;
    _restartedAt[cell.index] = _clock();
    _log.info(
      'restarting a stalled cell',
      fields: <String, Object?>{'index': cell.index, 'roomId': cell.source?.roomId, 'attempt': cell.restarts},
    );
    _emit();

    await _releaseCell(cell.index);
    try {
      await _openCell(cell);
    } on Object catch (error) {
      // The cell reports the stall as its reason and the failed restart as the
      // detail: an operator wants to know that this camera froze, not only that
      // the last attempt to bring it back did not work.
      cell.failure = MultiviewCellFailure(
        kind: MultiviewCellFailureKind.stallFailure,
        message: 'Stalled; the restart attempt failed: $error',
        attempt: cell.restarts,
        cause: error,
      );
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'restart after a stall failed',
        error: error,
        fields: <String, Object?>{'index': cell.index, 'attempt': cell.restarts},
      );
      _emit();
    }
  }

  MultiviewCell _cellAt(int index) {
    if (index < 0 || index >= _cells.length) {
      throw RangeError.index(index, _cells, 'index');
    }
    return _cells[index];
  }

  MultiviewSnapshot _buildSnapshot() {
    return MultiviewSnapshot(
      cells: cells,
      layout: _config.layout,
      focusedIndex: _focusedIndex,
      audioIndex: _audioIndex,
      pressure: _pressure,
      budgetExceeded: _budgetExceeded,
    );
  }

  void _emit() {
    _reportMemory();
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_buildSnapshot());
    }
  }

  /// Reports the cells and what they hold.
  ///
  /// Counts every assigned cell, not only the playing ones: a paused cell keeps
  /// its player open (that is what makes resuming it cheap), so it is still
  /// holding a decoder.
  void _reportMemory() {
    var playing = 0;
    var held = 0;
    var danmaku = 0;
    for (final cell in _cells) {
      if (cell.isPlaying) {
        playing++;
      }
      if (!cell.isEmpty) {
        held++;
      }
      danmaku += cell.danmaku?.length ?? 0;
    }

    _memory.report(
      _memoryKey,
      items: held,
      bytes: held * MemoryEstimates.videoStream720p + danmaku * MemoryEstimates.danmakuMessage,
      note: '$held cell(s), $playing playing, $danmaku danmaku queued',
    );
  }
}
