part of 'multiview_controller.dart';

/// Assigning rooms to cells, the decode budget that keeps the wall
/// inside the device's limits, and per-cell danmaku sessions.
extension MultiviewControllerCells on MultiviewController {
  // ---------------------------------------------------------------------------
  // Cells
  // ---------------------------------------------------------------------------

  /// Assigns [source] to [index] and starts it.
  Future<void> assign(int index, MultiviewCellSource source, {List<MultiviewCellSource>? playlist}) async {
    _ensureNotDisposed();
    final cell = _cellAt(index);

    if (_config.budgetPolicy == MultiviewBudgetPolicy.refuseNewCells && _isAtBudget && cell.isEmpty) {
      _log.warning(
        'refusing a new cell: at the decode budget',
        fields: <String, Object?>{
          'index': index,
          'roomId': source.roomId,
          'playing': _playingCount,
          'budget': _config.effectiveMaxCells,
        },
      );
      throw StateError(
        'The wall is at its decode budget (${_config.effectiveMaxCells} cells); '
        'refusing to add another under MultiviewBudgetPolicy.refuseNewCells.',
      );
    }

    // Opens for one cell are serialized per index: a re-assign racing the
    // playlist advance a failed open triggered for the same cell would
    // otherwise acquire two players for one slot and leak one. Cells are
    // still independent of each other, so a wall fill overlaps freely.
    await _sequenced(index, () => _assignNow(index, source, playlist: playlist));
  }

  /// The body of [assign], run inside the cell's operation chain.
  Future<void> _assignNow(int index, MultiviewCellSource source, {List<MultiviewCellSource>? playlist}) async {
    _log.info(
      'assigning a cell',
      fields: <String, Object?>{
        'index': index,
        'roomId': source.roomId,
        'uri': source.source.uri,
        'isLive': source.isLive,
        'playlistSize': playlist?.length,
      },
    );

    if (playlist != null && playlist.length > 1) {
      _playlists[index] = List<MultiviewCellSource>.unmodifiable(playlist);
    } else {
      _playlists.remove(index);
    }

    final cell = _cells[index]
      ..source = source
      ..failure = null
      ..restarts = 0;
    // No audio pass here: a successful open applies audio itself, and the
    // offline/failed paths hold no player to re-level. Applying again would
    // sweep every handle on the wall twice per assignment, which is exactly
    // the cost a wall fill multiplies by the cell count.
    await _openCell(cell);
    _emit();
  }

  /// Fills the wall from [sources], one per cell, in order.
  Future<void> assignAll(List<MultiviewCellSource> sources) async {
    _ensureNotDisposed();
    final limit = sources.length < _config.effectiveMaxCells ? sources.length : _config.effectiveMaxCells;
    // Cells open concurrently: filling a wall one assign at a time pays every
    // room's resolve + connect latency in sequence, which is most of what a
    // layout switch waits for. One dead room must not blank the rest of the
    // wall: each future carries its own catch, so the fill goes on with the
    // rooms that are live, exactly like the sequential fill did.
    await Future.wait(<Future<void>>[
      for (var index = 0; index < limit; index++)
        assign(index, sources[index]).catchError((Object error) {
          _log.warning(
            'wall fill skipped a failing cell',
            error: error,
            fields: <String, Object?>{'index': index, 'roomId': sources[index].roomId},
          );
        }),
    ]);
  }

  /// Advances [index] to the next source in its playlist, if it has one.
  ///
  /// A failed or ended cell with a playlist moves on instead of retrying the
  /// same dead room — which is what makes a wall usable as a monitor: the list
  /// keeps cycling through the rooms that are live.
  Future<bool> advanceCell(int index) async {
    _ensureNotDisposed();
    final playlist = _playlists[index];
    final current = _cells[index].source;
    if (playlist == null || playlist.isEmpty || current == null) {
      return false;
    }

    // Located by identity, not by roomId: roomIds are nullable (and can be
    // duplicated by a careless source list), and matching null against null
    // would always find entry 0 - advancing forever onto the same room.
    final position = playlist.indexWhere((candidate) => identical(candidate, current) || candidate == current);
    final next = playlist[(position + 1) % playlist.length];
    _log.debug(
      'advancing to the next room in the playlist',
      fields: <String, Object?>{
        'index': index,
        'from': current.roomId,
        'to': next.roomId,
        'playlistSize': playlist.length,
      },
    );
    await assign(index, next, playlist: playlist);
    return true;
  }

  /// Clears [index]: stops it and gives its player back.
  Future<void> clear(int index) async {
    _ensureNotDisposed();
    // Sequenced per index so a clear cannot detach a player an in-flight open
    // for the same cell is still about to attach (that handle would come back
    // to life as a ghost: playing, but absent from _handles).
    await _sequenced(index, () async {
      _cells[index]
        ..source = null
        ..qualityLabel = null
        ..failure = null
        ..restarts = 0
        ..status = MultiviewCellStatus.empty;
      _playlists.remove(index);
      await _releaseCell(index);
      _emit();
    });
  }

  /// Clears every cell.
  Future<void> clearAll() async {
    _ensureNotDisposed();
    // Released concurrently: a wall cleared one cell at a time waits on every
    // player hand-back in sequence, which is the slow part of a layout
    // switch. Each clear carries its own catch so one refusing player cannot
    // strand the rest of the wall still holding its players.
    await Future.wait(<Future<void>>[
      for (var index = 0; index < _cells.length; index++)
        clear(index).catchError((Object error) {
          _log.warning('clearing a cell failed', error: error, fields: {'index': index});
        }),
    ]);
    _audioIndex = null;
    _emit();
  }

  /// Starts [index] again from its current source.
  Future<void> restartCell(int index) async {
    _ensureNotDisposed();
    // Sequenced per index: a restart racing an in-flight assign for the same
    // cell would release the very player that assign was about to attach.
    await _sequenced(index, () async {
      final cell = _cells[index];
      if (cell.source == null) {
        return;
      }
      await _releaseCell(index);
      await _openCell(cell);
      _emit();
    });
  }

  /// Stops [index] but keeps its room assigned.
  Future<void> stopCell(int index) async {
    _ensureNotDisposed();
    final handle = _handles[index];
    if (handle != null) {
      await handle.pause();
    }
    // Paused, not empty: the player stays open (that is what makes resuming
    // cheap) and the room stays assigned, so an empty status would hide a
    // held decoder from the budget and the memory report and contradict the
    // cell's own source.
    _cells[index].status = MultiviewCellStatus.paused;
    _emit();
  }

  /// Pauses [index]; the stall watchdog skips paused cells.
  Future<void> pauseCell(int index) async {
    _ensureNotDisposed();
    final handle = _handles[index];
    final cell = _cellAt(index);
    if (handle == null || !cell.isPlaying) {
      return;
    }
    await handle.pause();
    cell.status = MultiviewCellStatus.paused;
    _emit();
  }

  /// Resumes a [MultiviewCellStatus.paused] cell and restarts its stall clock.
  Future<void> resumeCell(int index) async {
    _ensureNotDisposed();
    final handle = _handles[index];
    final cell = _cellAt(index);
    if (handle == null || !cell.isPaused) {
      return;
    }
    _progress[index] = (position: _progress[index]?.position ?? Duration.zero, at: _clock());
    await handle.play();
    cell.status = MultiviewCellStatus.playing;
    await _applyAudio();
    _emit();
  }

  /// Overrides the audio-mode volume of [index].
  ///
  /// The override survives focus changes and audio re-application until the
  /// cell is cleared or [clearCellVolume] removes it.
  Future<void> setCellVolume(int index, double volume) async {
    _ensureNotDisposed();
    final cell = _cellAt(index);
    if (cell.isEmpty) {
      return;
    }
    _cellVolumes[index] = volume.clamp(0.0, 1.0);
    final handle = _handles[index];
    if (handle != null) {
      await handle.setVolume(volume.clamp(0.0, 1.0));
      await handle.setMute(muted: volume <= 0);
    }
    await _applyAudio();
    _emit();
  }

  /// Removes the manual volume of [index]; the audio mode decides again.
  Future<void> clearCellVolume(int index) async {
    _ensureNotDisposed();
    if (_cellVolumes.remove(index) == null) {
      return;
    }
    await _applyAudio();
    _emit();
  }

  // ---------------------------------------------------------------------------
  // Budget
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Budget
  // ---------------------------------------------------------------------------

  /// Reports device pressure.
  ///
  /// Applied immediately rather than at the next tick: a device in trouble does
  /// not wait two seconds for the wall to notice.
  Future<void> reportPressure(ResourcePressure pressure) async {
    _ensureNotDisposed();
    _pressure = pressure;
    _log.debug(
      'device pressure reported',
      fields: <String, Object?>{
        'hasPressure': pressure.hasPressure,
        'stopPreload': pressure.shouldStopPreload,
        'releaseResources': pressure.shouldReleaseResources,
      },
    );
    await _applyBudget();
    _emit();
  }

  Future<void> _applyBudget() async {
    // Counted by decoders held, not by cells playing: a starting, paused or
    // stopped cell keeps its player open, and counting only the playing ones
    // let a wall drift past its budget one "not yet playing" cell at a time.
    // `_handles` is exactly the set of open players - `_releaseCell` detaches
    // its entry before its first await - so its length is the held count.
    final crowded = _handles.length > _config.effectiveMaxCells || _pressure.hasPressure;
    _budgetExceeded = crowded;
    if (!crowded) {
      return;
    }

    switch (_config.budgetPolicy) {
      case MultiviewBudgetPolicy.keepFocusedOnly:
        final severe = _pressure.shouldStopPreload || _pressure.shouldReleaseResources;
        if (!severe && _playingCount <= _config.effectiveMaxCells) {
          return;
        }
        _log.warning(
          'over budget: pausing every cell but the focused one',
          fields: <String, Object?>{'playing': _playingCount, 'budget': _config.effectiveMaxCells, 'severe': severe},
        );
        // Decisions first, engine calls in parallel: under pressure a wall of
        // N cells must not wait N serialized pauses to shed its decoders.
        final pauses = <Future<void>>[];
        for (final cell in _cells) {
          if (cell.index == _focusedIndex || !cell.isPlaying) {
            continue;
          }
          final handle = _handles[cell.index];
          if (handle == null) {
            continue;
          }
          // Paused, not empty: the player stays open and the room assigned,
          // so the cell stays counted by the budget and resumable instead of
          // becoming an "empty" slot that quietly holds a decoder.
          cell.status = MultiviewCellStatus.paused;
          pauses.add(handle.pause());
        }
        await Future.wait(pauses);
      case MultiviewBudgetPolicy.letPlatformDrop:
      case MultiviewBudgetPolicy.refuseNewCells:
        _log.debug(
          'over budget, policy leaves the cells alone',
          fields: <String, Object?>{'policy': _config.budgetPolicy.name, 'playing': _playingCount},
        );
        return;
    }
  }

  bool get _isAtBudget => _handles.length >= _config.effectiveMaxCells;

  int get _playingCount {
    // A plain loop: this runs on the sweep tick and in the refuse-a-cell log,
    // and `where(...).length` allocated a fresh iterable every call.
    var count = 0;
    for (final cell in _cells) {
      if (cell.isPlaying) {
        count++;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Danmaku sessions
  // ---------------------------------------------------------------------------

  /// Creates the focused cell's danmaku session on demand.
  ///
  /// Lazily, because most walls never use it and a session per cell that is
  /// never fed is a queue nobody reads.
  DanmakuOverlaySession ensureDanmakuFor(int index) {
    _ensureNotDisposed();
    final cell = _cellAt(index);
    final existing = cell.danmaku;
    if (existing != null) {
      return existing;
    }
    final session = DanmakuOverlaySession();
    cell.danmaku = session;
    return session;
  }
}
