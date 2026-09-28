part of 'multiview_controller.dart';

/// Cell lifecycle internals: opening a cell, watching its progress,
/// stall recovery and snapshot emission.
extension _MultiviewControllerInternals on MultiviewController {
  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

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
      cell.status = MultiviewCellStatus.offline;
      cell.qualityLabel = null;
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

    cell.status = MultiviewCellStatus.starting;
    cell.failure = null;
    _emit();

    try {
      final resolved = await _resolveForCell(cell);
      final handle = await _handleFor(cell.index);
      await handle.open(resolved.source, autoPlay: true);
      cell.status = MultiviewCellStatus.playing;
      cell.qualityLabel = resolved.qualityLabel;
      _log.info(
        'cell is playing',
        fields: <String, Object?>{'index': cell.index, 'roomId': resolved.roomId, 'quality': resolved.qualityLabel},
      );
      _watchProgress(cell.index, handle);
      await _applyAudio();
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
      if (_playlists.containsKey(cell.index)) {
        unawaited(advanceCell(cell.index));
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<MultiviewCellSource> _resolveForCell(MultiviewCell cell) async {
    final resolver = qualityResolver;
    final source = cell.source!;
    if (resolver == null) {
      return source;
    }
    return resolver(source, _preferenceFor(cell.index));
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
    return handle;
  }

  Future<void> _releaseCell(int index) async {
    final subscription = _progressSubscriptions.remove(index);
    await subscription?.cancel();
    _progress.remove(index);
    final handle = _handles.remove(index);
    if (handle == null) {
      return;
    }
    await handle.pause();
    await handle.recycle();
    // Back to the host, which may return it from the kernel's instance pool: a
    // wall that keeps switching rooms must not pay for a cold player each time.
    await _players.release(handle);
  }

  void _watchProgress(int index, PoolPlayerHandle handle) {
    unawaited(_progressSubscriptions.remove(index)?.cancel());
    _progress[index] = (position: Duration.zero, at: _clock());
    _progressSubscriptions[index] = handle.playbackStream.listen(
      (state) => _noteProgress(index, state.position),
      onError: (_) {},
    );
  }

  void _noteProgress(int index, Duration position) {
    final previous = _progress[index];
    if (previous == null) {
      return;
    }
    if (position != previous.position) {
      _progress[index] = (position: position, at: _clock());
    }
  }

  Future<void> _applyAudio() async {
    if (_cells.isEmpty) {
      return;
    }

    for (final cell in _cells) {
      final handle = _handles[cell.index];
      if (handle == null) {
        continue;
      }

      final desired = switch (_config.audioMode) {
        MultiviewAudioMode.muted => 0.0,
        MultiviewAudioMode.mixed => _config.focusedVolume,
        MultiviewAudioMode.exclusive =>
          cell.index == (_audioIndex ?? _focusedIndex) ? _config.focusedVolume : _config.backgroundVolume,
      };

      cell.hasAudioFocus = desired > 0;
      await handle.setVolume(desired);
      await handle.setMute(desired <= 0);
    }
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
      session.updateConfig(session.config.copyWith(enabled: shouldFeed));
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
    if (_disposed) {
      return;
    }

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

  Future<void> _handleStall(MultiviewCell cell) async {
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
      if (_playlists.containsKey(cell.index)) {
        await advanceCell(cell.index);
      }
      return;
    }

    cell.restarts++;
    cell.status = MultiviewCellStatus.recovering;
    _log.info(
      'restarting a stalled cell',
      fields: <String, Object?>{'index': cell.index, 'roomId': cell.source?.roomId, 'attempt': cell.restarts},
    );
    _emit();

    await _releaseCell(cell.index);
    try {
      await _openCell(cell);
    } catch (error) {
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

    _memory.report(_memoryKey, 
      items: held,
      bytes: held * MemoryEstimates.videoStream720p + danmaku * MemoryEstimates.danmakuMessage,
      note: '$held cell(s), $playing playing, $danmaku danmaku queued',
    );
  }
}
