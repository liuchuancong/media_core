part of 'live_playback_controller.dart';

/// The sweep: engine × source candidates, each opened, staged and
/// verified before it is committed — the recovery story of one play.
extension _LivePlaybackSweep on LivePlaybackController {
  // ---------------------------------------------------------------------------
  // The sweep: engine × source, verified
  // ---------------------------------------------------------------------------

  Future<void> _startPlayback() async {
    final engines = _engineOrder();
    final primary = _sources.isNotEmpty ? _sources.first : null;
    final handle = _handle;

    // A duplicate play of exactly the playback already running - a
    // double-tap, or the app re-entering its play flow while the first
    // sweep is still verifying - must not supersede and tear down what it
    // just asked for. Full-URI comparison: refreshed signatures share the
    // path but differ in query, so a legitimate re-play still runs. A play
    // of a playback that published its failure is not a duplicate: the
    // viewer is asking the sweep to run again.
    if (handle != null &&
        !handle.disposed &&
        _playbackRequested &&
        state.playback != PlayerPlaybackState.error &&
        primary != null &&
        _currentSource?.uri == primary.uri &&
        (engines.isEmpty || handle.backendId == engines.first)) {
      return;
    }

    _engines = engines;
    _reportMemory();
    _engineIndex = 0;
    _sourceIndex = 0;

    await _sweep();
  }

  /// Whether the newer command that superseded the current play generation
  /// is a play of exactly [source] on [engine] - in which case committing the
  /// staged player is correct, and discarding it would only fail the sweep and
  /// burn the request's single-use URLs on a replay.
  bool _supersededBySamePlayback(String engine, PlayerSource source) {
    return _playbackRequested &&
        _request != null &&
        _sourceIndex < _sources.length &&
        _engineIndex < _engines.length &&
        _sources[_sourceIndex].uri == source.uri &&
        _engines[_engineIndex] == engine;
  }

  Future<void> _openCurrentSource() async {
    if (_engines.isEmpty || _engineIndex >= _engines.length) {
      _engines = _engineOrder();
      _engineIndex = 0;
    }

    await _sweep(startAtCurrent: true);
  }

  /// Tries candidates in order until one verifies, then reports failure.
  ///
  /// The whole sweep runs inside one queued task, so the only things that
  /// can interrupt it are a user action taking the queue or the task being
  /// cancelled — never another recovery path.
  Future<void> _sweep({bool startAtCurrent = false}) async {
    final generation = _playGeneration;
    var first = true;

    _sweepFailure = null;
    _sweepSawNonNetwork = false;

    MediaCoreLog.info(
      LogCategory.fallback,
      'sweep started',
      fields: <String, Object?>{
        'lines': _sources.length,
        'engines': _engines.length,
        'startAtLine': _sourceIndex,
        'reopen': startAtCurrent,
      },
    );

    while (!_disposed && !_offline && _playbackRequested && generation == _playGeneration) {
      final source = _sources[_sourceIndex];
      final engine = _engines[_engineIndex];

      try {
        await _openOn(engine, source);

        return;
      } on Object catch (error) {
        MediaCoreLog.warning(
          LogCategory.recovery,
          'candidate failed: ${_lineAddress(source)} on $engine'
          '${first && startAtCurrent ? ' (reopen of the playing line)' : ''}',
          error: error,
          fields: <String, Object?>{'sourceIndex': _sourceIndex, 'engineIndex': _engineIndex},
        );

        first = false;
        _sweepFailure = error;
        if (!_isNetworkFailure(error)) _sweepSawNonNetwork = true;

        final address = _lineAddress(source);
        if (address != null) _failedLines.add(address);

        // A candidate that failed because the playback it belonged to was
        // superseded or stopped is not a candidate failure: it has no
        // successor in this sweep. Advancing the ledger here used to move
        // `_sourceIndex` past the line a queued switchLine had already
        // chosen, and an exhausted report after that would describe a
        // playback the user had already replaced. A superseding play of
        // exactly this playback needs no advance either — its own sweep
        // starts the ladder again (or is dropped by the duplicate guard
        // after this sweep commits).
        if (_abandoned(generation)) {
          return;
        }
      }

      if (!await _nextCandidate()) {
        await _reportExhausted(source, engine);

        return;
      }
    }
  }

  /// Moves to the next candidate: next source, else next engine (when
  /// allowed) restarting its sweep at the line the user was watching.
  ///
  /// Before the engine switch, [onEngineFallbackSources] gets one chance
  /// to hand over fresh lines: signed live URLs are frequently single-use,
  /// and replaying them on the next engine would fail the whole sweep for
  /// an expired signature rather than a broken engine.
  Future<bool> _nextCandidate() async {
    if (_sourceIndex + 1 < _sources.length) {
      _sourceIndex++;

      return true;
    }

    if (!_engineFallbackAllowed || _engineIndex + 1 >= _engines.length) {
      return false;
    }

    final nextEngine = _engines[_engineIndex + 1];

    // The refresh below is an await a newer command can overtake, so the
    // candidate move it feeds is fenced on the play generation: a refresh —
    // or a failure of one — that lands after play, switchLine, retry, pause,
    // close or dispose belongs to a playback that no longer exists, and
    // adopting it anyway would overwrite the ledger the newer command just
    // wrote. The queued task would then sweep the stale lines, not the
    // requested ones, because `_startPlayback` scores its engine order from
    // `_sources.first`.
    final generation = _playGeneration;

    // Creating the next engine's player does not depend on the refresh
    // answer — a player is source-agnostic — so it starts now and overlaps
    // the resolver's round-trip instead of running after it. Engine switches
    // happen on the failure paths a viewer is staring at, and the create is
    // the part of the switch the round-trip used to sit in front of. The
    // prefetch is consumed by the immediately following `_openOnStaged`
    // (nothing awaits between this return and that call), or released by the
    // fence below when this sweep is superseded while the refresh runs.
    final resolver = onEngineFallbackSources;

    if (resolver != null) {
      final prefetched = kernel.create(preferredBackend: nextEngine)..ignore();
      _engineSwitchPlayer = prefetched;
    }

    var nextSources = _sources;
    var resumeAt = _sweepStart;

    if (resolver != null) {
      var refreshed = const <PlayerSource>[];
      var refreshFailed = false;

      try {
        refreshed = await resolver(nextEngine, _sources);
      } on Object catch (error) {
        refreshFailed = true;

        MediaCoreLog.warning(
          LogCategory.fallback,
          'engine switch source refresh failed — reusing the current lines',
          error: error,
          fields: <String, Object?>{'nextEngine': nextEngine},
        );
      }

      if (_abandoned(generation)) {
        await _discardPrefetchedEngine();

        return true;
      }

      if (!refreshFailed && refreshed.isNotEmpty) {
        nextSources = List<PlayerSource>.unmodifiable(refreshed);
        resumeAt = 0;

        MediaCoreLog.info(
          LogCategory.fallback,
          'engine switch sources refreshed by the caller',
          fields: <String, Object?>{'nextEngine': nextEngine, 'lines': nextSources.length},
        );
      }
    }

    MediaCoreLog.info(
      LogCategory.fallback,
      'all sources failed on ${_engines[_engineIndex]} — switching to $nextEngine',
      fields: <String, Object?>{
        'from': _engines[_engineIndex],
        'to': nextEngine,
        'resumeAtLine': resumeAt,
        'refreshed': !identical(nextSources, _sources),
      },
    );

    _sources = nextSources;
    _sweepStart = resumeAt;
    _engineIndex++;
    _sourceIndex = resumeAt;

    return true;
  }

  /// Releases an engine-switch prefetch its sweep will no longer consume.
  ///
  /// Reached only when the generation fence in [_nextCandidate] saw the
  /// playback move while the refresh round-trip ran; the created player is
  /// idle (nothing was opened on it), so releasing it is all the unwind
  /// there is.
  Future<void> _discardPrefetchedEngine() async {
    final prefetched = _engineSwitchPlayer;
    _engineSwitchPlayer = null;

    if (prefetched == null) {
      return;
    }

    try {
      final staged = await prefetched;

      if (!staged.disposed) {
        await kernel.release(staged.id);
      }
    } on Object {
      // The create itself failed — there is nothing to release.
    }
  }

  /// Offers [onRecoverySources] the lines that just died and adopts what it
  /// hands back.
  ///
  /// A signed live URL expires on the platform's clock, not the player's, so
  /// re-opening the line that stalled retries an address the server has
  /// already rejected — the sweep then burns every candidate and every engine
  /// on one stale signature and reports the stream as dead. The refresh is a
  /// round-trip to the platform, which makes it the recovery's only await
  /// that a newer command can overtake: the answer is fenced on the play
  /// generation, and a caller that throws or has nothing fresher leaves the
  /// sweep on the lines it already holds.
  Future<void> _refreshSourcesForRecovery() async {
    final resolver = onRecoverySources;

    if (resolver == null || _sources.isEmpty) {
      return;
    }

    if (_refreshAttempts >= _refreshBudget) {
      MediaCoreLog.debug(
        LogCategory.recovery,
        'recovery refresh budget spent — reusing the current lines',
        fields: <String, Object?>{'attempts': _refreshAttempts},
      );

      return;
    }

    _refreshAttempts++;

    final generation = _playGeneration;
    final List<PlayerSource> refreshed;

    try {
      refreshed = await resolver(_sources);
    } on Object catch (error) {
      if (generation != _playGeneration || _disposed) {
        return;
      }

      if (_isNetworkFailure(error)) {
        MediaCoreLog.warning(
          LogCategory.recovery,
          'recovery source refresh failed — the network stopped answering',
          error: error,
          fields: <String, Object?>{'lines': _sources.length},
        );

        _enterOffline(error);

        return;
      }

      MediaCoreLog.warning(
        LogCategory.recovery,
        'recovery source refresh failed — reusing the current lines',
        error: error,
        fields: <String, Object?>{'lines': _sources.length},
      );

      return;
    }

    // play, switchLine, retry, pause, close and dispose all bump the
    // generation before they queue their own task; a refresh that lands
    // after one of them belongs to a playback that no longer exists, and
    // adopting it would swap the lines out from under the newer command.
    if (generation != _playGeneration || refreshed.isEmpty || _disposed) {
      return;
    }

    await _adoptRefreshedSources(refreshed);
  }

  /// Swaps the sweep's lines for [refreshed] and re-locates the watched one.
  Future<void> _adoptRefreshedSources(List<PlayerSource> refreshed) async {
    // The line the viewer is on, in the list that replaced it. A refresh is
    // a new answer from the platform, not a re-sort of the old one: its own
    // preference order can put another CDN at index 0, and a signed query
    // changes every round-trip, so host and path are what names a line
    // across the two. Without this a stall moves the viewer to the platform's
    // first line — and the host's line mirror follows `sourceIndex`, so the
    // picker starts reporting a line nobody chose.
    final watched = _lineAddress(_currentSource ?? (_sources.isEmpty ? null : _sources[_sourceIndex]));
    _sources = List<PlayerSource>.unmodifiable(refreshed);
    var resume = watched == null ? -1 : refreshed.indexWhere((source) => _lineAddress(source) == watched);

    // A line the current window already watched fail is not reopened first:
    // the walk continues at the next line the window has not condemned.
    if (resume >= 0 && watched != null && _failedLines.contains(watched)) {
      for (var step = 1; step < refreshed.length; step++) {
        final candidate = _lineAddress(refreshed[(resume + step) % refreshed.length]);
        if (candidate == null || !_failedLines.contains(candidate)) {
          resume = (resume + step) % refreshed.length;
          break;
        }
      }
    }

    if (resume < 0) resume = 0;

    _sourceIndex = resume;
    _sweepStart = resume;

    _reportMemory();

    MediaCoreLog.info(
      LogCategory.recovery,
      'recovery sources refreshed by the caller',
      fields: <String, Object?>{
        'lines': _sources.length,
        'first': _lineAddress(_sources.first),
        'resumeAtLine': resume,
        'keptLine': watched != null && _lineAddress(refreshed[resume]) == watched,
      },
    );
  }

  /// Opens [source] on [engine], starts playback and verifies it.
  ///
  /// Line switches inside one engine re-open the existing handle. An
  /// engine switch is **staged**: the replacement player is created,
  /// opened and verified *alongside* the current one, and only a verified
  /// player is committed. Committing after verification is what keeps the
  /// engine-switch black flash short - the mounted surface is replaced at
  /// the moment the new engine already has a decoded frame, instead of
  /// showing a placeholder for the engine's whole time-to-first-frame.
  Future<void> _openOn(String engine, PlayerSource source) async {
    final generation = _playGeneration;

    final current = _handle;
    final sameEngine = current != null && !current.disposed && current.backendId == engine;

    if (!sameEngine) {
      await _openOnStaged(engine, source, generation: generation, previous: current);
      return;
    }

    final handle = current;

    if (_currentSource != source) {
      MediaCoreLog.info(
        LogCategory.fallback,
        'line switch: ${_lineAddress(_currentSource)} → ${_lineAddress(source)}',
        fields: <String, Object?>{'fromLine': _sourceIndex, 'engine': engine},
      );
    }

    _setState(_liveState(PlayerPlaybackState.opening));

    // Recovery is this module's job; the handle's own ladder stays
    // dormant so there is exactly one recovery path.
    handle
      ..recoveryEnabled = false
      ..playIntent = true;

    // Every watchdog armed for a previous candidate is stale now: cancel
    // them, and clear the position observation so the new source starts
    // unobserved. The first position sample of the *new* source is then
    // what enables and arms the stall detector - exactly once.
    watchdogs
      ..cancelAll()
      ..resetPositionSignal();

    _sweepAdapterError = null;

    await handle.open(source);

    // Same fencing as the staged path applies after its open: a superseding
    // play of exactly this playback wants this candidate committed, so the
    // attempt runs on — abandoning it here would make the queued duplicate
    // re-open a source this open has already consumed. Any other supersede
    // (another line, pause, close) leaves the handle for the newer command.
    if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
      return;
    }

    await handle.play();

    // The step that separates "opened" from "playing": without it an
    // engine that accepts a source but never delivers a frame reads as
    // success and the sweep stops on a frozen player.
    await _verifyPlayback(handle, source, generation: generation, engine: engine);

    // Same rule as the staged tail: a superseding play of exactly this
    // playback is answered by committing, not by skipping the bookkeeping
    // that lets its duplicate guard recognise what is already playing.
    if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
      return;
    }

    _currentSource = source;

    _setVerifiedState(handle);
  }

  /// Reports a candidate that verification just accepted.
  ///
  /// `buffering` is only the floor: verification proved the position moved, so the
  /// engine's own state is the answer wherever it has one. Writing `buffering`
  /// unconditionally used to sit on top of that truth — on an engine switch
  /// [_attach] seeds it a moment earlier and this line overwrote it — which left
  /// every consumer that trusts the mirror showing a spinner over a stream that had
  /// already started, until the next position heartbeat corrected it.
  void _setVerifiedState(PlayerHandle handle) {
    _setState(_liveState(PlayerPlaybackState.buffering));
    _adoptPlaybackTruth(handle);
    _resetBufferingProgress();

    // The deadline stays for the one case verification cannot rule out: an engine
    // that produced a single position advance and then went silent altogether. When
    // the truth adopted above already says playing, it answers itself.
    watchdogs.armSourceReady();

    _armBudgetReset();
  }

  /// Builds the replacement player for [engine], proves it plays, then
  /// commits it. Any failure disposes the staged player and rethrows - the
  /// sweep moves on, and nothing already on screen is torn down for a
  /// lost race.
  Future<void> _openOnStaged(
    String engine,
    PlayerSource source, {
    required int generation,
    required PlayerHandle? previous,
  }) async {
    MediaCoreLog.info(
      LogCategory.fallback,
      'attaching engine $engine for ${_lineAddress(source)}',
      fields: <String, Object?>{'line': _sourceIndex, 'staged': previous != null},
    );

    _setState(_liveState(PlayerPlaybackState.opening));

    watchdogs.cancelAll();

    _sweepAdapterError = null;

    // The engine being replaced keeps playing while this attempt runs, and
    // its subscription is otherwise only swapped at commit - so for the
    // whole verification window it kept feeding observations (position,
    // playing, buffering) to a watchdog set that had just been cancelled
    // for this attempt. That is what produced a second "armed" line per
    // engine switch, armed from the retiring source's samples. Detach it
    // for the attempt; a failed attempt restores the subscription so the
    // still-running playback keeps its coverage.
    final retireeSub = previous == null ? null : _adapterSub;

    if (retireeSub != null) {
      _adapterSub = null;

      await retireeSub.cancel();
    }

    final PlayerHandle staged;

    try {
      // Consume the player the sweep created for this engine while the
      // source-refresh round-trip ran (see `_nextCandidate`). With no
      // resolver there is no prefetch and this creates here, as before.
      // `kernel.create` takes the engine as a preference, so consuming a
      // prefetch made for this exact engine id is the same ask the inline
      // create made.
      final pending = _engineSwitchPlayer;
      _engineSwitchPlayer = null;

      staged = await (pending ?? kernel.create(preferredBackend: engine));
    } on Object catch (error) {
      MediaCoreLog.warning(
        LogCategory.fallback,
        'staged engine creation failed; re-attached the retired engine',
        error: error,
        fields: {'engine': engine},
      );
      // Creation runs after the retiree's subscription was detached, and the
      // restore path lives in the staging try below - which was never
      // entered. Without restoring here, the still-playing engine loses
      // stall detection and error recovery for good.
      if (previous != null && !previous.disposed && identical(_handle, previous) && _adapterSub == null) {
        _adapterSub = previous.adapterEvents.listen(_onAdapterEvent, onError: (Object error) {
          MediaCoreLog.debug(LogCategory.player, 'adapter event stream errored during staging', error: error);
        });

        watchdogs.updateCapabilities(previous.adapter.capabilities);
        watchdogs.setVideoExpected(expected: !_audioOnly);
        watchdogs.onPlayingChanged(playing: _playbackRequested, fromUserIntent: false);
      }

      rethrow;
    }

    // A staged attempt owns no subscription until it commits, so an engine
    // that fails *while opening* — a playlist that 404s, a refused connection
    // — told the sweep nothing at all: verification sat out its whole window
    // and then reported "position frozen", blaming the stream for what the
    // engine had already stated. Observe errors only; playback state and the
    // watchdogs stay unattached until commit, exactly as before.
    final stagedErrors = staged.adapterEvents.listen((event) {
      if (event case PlayerAdapterErrorEvent(:final message)) {
        _sweepAdapterError ??= message;
      }
    }, onError: (Object error) {
      MediaCoreLog.debug(LogCategory.player, 'adapter event stream errored during staging', error: error);
    });

    try {
      staged
        ..recoveryEnabled = false
        ..playIntent = true;

      // Options that must reach the engine before the first request (the
      // player proxy) are written here, while the attempt is still staged:
      // the handle is only committed after open/verify, so consumers cannot
      // apply them in time through `onHandleChanged`.
      if (_engineOptions.isNotEmpty) {
        try {
          await staged.applyEngineOptions(_engineOptions);
        } on Object catch (error) {
          // An option the engine refused must not turn into a failed stream.
          MediaCoreLog.debug(LogCategory.fallback, 'engine refused an engine option', error: error, fields: {'engine': engine});
        }
      }

      if (_audioOnly) {
        await staged.setAudioOnly(audioOnly: true);
      }

      await staged.open(source);

      if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
        throw StateError('Staged engine $engine was abandoned mid-open.');
      }

      await staged.play();
      await _verifyPlayback(staged, source, generation: generation, engine: engine);

      if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
        throw StateError('Staged engine $engine was abandoned mid-verify.');
      }

      // Commit: the replacement has proven itself. Surface consumers see
      // the new handle through onHandleChanged and rebind at this moment,
      // when the first frame is already decoded.
      //
      // The per-source position observation is cleared first: the retiring
      // engine has been feeding the watchdogs throughout verification (its
      // subscription is only replaced by _attach), so its samples would
      // otherwise arm the stall detector for a source that is going away -
      // one arm per engine switch too many in the log.
      watchdogs.resetPositionSignal();

      MediaCoreLog.info(
        LogCategory.fallback,
        'engine switch committed',
        fields: <String, Object?>{'from': previous?.backendId, 'to': engine, 'line': _sourceIndex},
      );

      _attach(staged);

      // After the commit, not before: cancelling first would open a gap in
      // which an error event reaches neither listener.
      await stagedErrors.cancel();

      if (previous != null && !previous.disposed) {
        try {
          await kernel.release(previous.id);
        } on Object catch (error) {
          // Best-effort release of the retired engine.
          MediaCoreLog.debug(LogCategory.player, 'release of the retired engine failed', error: error, fields: {'id': previous.id});
        }
      }
    } on Object catch (_) {
      await stagedErrors.cancel();

      try {
        await kernel.release(staged.id);
      } on Object catch (error) {
        // Best-effort cleanup of the failed staging.
        MediaCoreLog.debug(LogCategory.player, 'release of the staged engine failed', error: error, fields: {'id': staged.id});
      }

      // The retired engine is still the active one after a failed attempt:
      // give its adapter events back, or a stream that keeps playing would
      // run without stall detection until the next candidate commits. The
      // watchdog capabilities and playing state are re-seeded with it -
      // the attempt cancelled them, and the retiring handle's Playing event
      // is long past, so without this the position stall could never re-arm
      // for a stream that is in fact still running.
      if (previous != null && !previous.disposed && identical(_handle, previous) && _adapterSub == null) {
        _adapterSub = previous.adapterEvents.listen(_onAdapterEvent, onError: (Object error) {
          MediaCoreLog.debug(LogCategory.player, 'adapter event stream errored during staging', error: error);
        });

        watchdogs.updateCapabilities(previous.adapter.capabilities);
        watchdogs.setVideoExpected(expected: !_audioOnly);
        watchdogs.onPlayingChanged(playing: _playbackRequested, fromUserIntent: false);
      }

      rethrow;
    }

    // The commit above already happened, so a superseded generation only
    // skips the bookkeeping — unless the superseder is a play of exactly
    // this playback, in which case the bookkeeping IS the answer: writing
    // `_currentSource` here is what lets `_startPlayback`'s duplicate guard
    // drop the queued duplicate instead of re-opening a source this commit
    // just consumed.
    if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
      return;
    }

    _currentSource = source;

    _setVerifiedState(staged);
  }

  /// Waits until [handle] shows any sign of real playback.
  ///
  /// An engine that accepts a source but never delivers a frame — the
  /// "freeze that looks like success" — fails here instead of ending the
  /// sweep on a silent player.
  ///
  /// The success bar is *any* positive position progress, not a jump:
  /// some live sources (huya FLV, for one) start their demuxer clock near
  /// zero and only creep forward a few tens of milliseconds while the
  /// picture is in fact playing. Requiring a 400ms jump used to condemn
  /// exactly those healthy streams, and the sweep then tore down engine
  /// after engine that was already on screen. A stream that moves at all
  /// has passed verification; if it later stops moving, the position-stall
  /// watchdog is the detector for that, not this gate.
  ///
  /// The deadline is [LiveWatchdogs.sourceReadyTimeout] — the tolerance
  /// this module already declares for "opened but not playing", of which
  /// this is the first phase. It used to be a private, tighter constant,
  /// which meant one question with two deadlines and the stricter one
  /// winning: engines that were demonstrably still working (fetching the
  /// renditions of a multi-variant HLS master) were reported as frozen.
  /// Silence at this point is not evidence of death, because there is no
  /// signal that says "still probing" — no position and no buffering
  /// report exist until the demuxer has finished opening.
  Future<void> _verifyPlayback(
    PlayerHandle handle,
    PlayerSource source, {
    required int generation,
    required String engine,
  }) async {
    final window = watchdogs.sourceReadyTimeout;

    // Zero turns the deadline off, and verification *is* that deadline.
    if (window <= Duration.zero) {
      return;
    }

    final until = DateTime.now().add(window);
    var last = handle.playbackStream.value.position;

    // The wait below ends on the transport's own updates instead of sleeping
    // a fixed slice between polls: the first position advance is declared the
    // moment the engine reports it, not up to one poll interval later — a
    // fixed tax the old loop put on every candidate's happy path, including
    // the first one a viewer is staring at. The wait is still bounded, so the
    // abandonment and adapter-error checks keep their cadence when the engine
    // has gone fully silent. A dropped wakeup is harmless: every iteration
    // re-reads the mirror's current value, so the decision is
    // level-triggered, not edge-triggered.
    var wake = Completer<void>();
    final updates = handle.playbackStream.listen((_) {
      if (!wake.isCompleted) {
        wake.complete();
      }
    });

    try {
      while (DateTime.now().isBefore(until)) {
        // Superseded or stopped mid-verification: this sweep is done
        // waiting. The check used to test only `_playbackRequested`, so a
        // play or line switch — which keeps it true — left the dead
        // candidate sitting out its whole window while the queued command
        // waited behind the sweep task; the open the user asked for started
        // late by up to `sourceReadyTimeout`. A play of exactly this
        // playback is the exception, with the same fencing the open path
        // applies: committing the staged player is the correct answer to it.
        if (_abandoned(generation) && !_supersededBySamePlayback(engine, source)) {
          throw StateError('Playback verification abandoned: playback was stopped.');
        }

        final adapterError = _sweepAdapterError;

        if (adapterError != null) {
          throw StateError('${_lineAddress(source)} on ${handle.backendId} failed while verifying: $adapterError');
        }

        final position = handle.playbackStream.value.position;

        // A reopen restarts the demuxer clock: the mirror still holds the
        // previous playback's position (18s of the old session, say), and
        // the fresh stream starts near zero. Without re-baselining, every
        // new sample is "smaller than last" and a perfectly healthy reopen
        // is condemned as frozen at the stale value.
        if (position < last) {
          last = position;
          continue;
        }

        if (position > last) {
          return;
        }

        final remaining = until.difference(DateTime.now());

        if (remaining <= Duration.zero) {
          break;
        }

        await wake.future.timeout(
          remaining < _verifyCheckEvery ? remaining : _verifyCheckEvery,
          onTimeout: () {},
        );

        wake = Completer<void>();
      }
    } finally {
      await updates.cancel();
    }

    throw StateError(
      '${_lineAddress(source)} on ${handle.backendId} opened but never played '
      '(position frozen at ${last.inMilliseconds}ms for '
      '${window.inSeconds}s).',
    );
  }

  /// Terminal: every allowed candidate failed. Exactly one failure per
  /// sweep — the caller decides what happens next.
  ///
  /// The message names the request's title when it has one, and never a signed
  /// address's query: which room died is the question a caller with several open
  /// has to answer from this line, and the URL that answers it best is the one that
  /// carries a credential.
  Future<void> _reportExhausted(PlayerSource source, String engine) async {
    final room = _request?.title;

    // Every candidate died at the transport level: neither the stream nor
    // the platform answers through these lines, and other lines and
    // decoders would go through the same network. The offline machine takes
    // over from the sweep.
    if (!_sweepSawNonNetwork && _isNetworkFailure(_sweepFailure) && _enterOffline(_sweepFailure!)) {
      return;
    }

    if (_scheduleRetryRound()) {
      return;
    }

    MediaCoreLog.error(
      LogCategory.recovery,
      'live sweep exhausted — reporting to the caller',
      fields: <String, Object?>{
        'title': ?room,
        'sources': _sources.length,
        'enginesTried': _engineFallbackAllowed ? _engineIndex + 1 : 1,
        'lastEngine': engine,
        'lastLine': _lineAddress(source),
        'retryRounds': _retryRounds,
      },
    );

    _setState(_liveState(PlayerPlaybackState.error));

    if (!_failureController.isClosed) {
      _failureController.add(
        PlayerFailure.of(
          code: PlayerErrorCode.noPlayableStream,
          message:
              '${room == null ? '' : '$room: '}'
              'Live playback failed after trying ${_sources.length} source(s)'
              '${_engineFallbackAllowed ? ' across ${_engineIndex + 1} engine(s)' : ''}'
              '${_retryRounds > 0 ? ' across $_retryRounds retry round(s)' : ''}. '
              'Last attempt: ${_lineAddress(source)} on $engine.',
        ),
      );
    }
  }

  /// One more bounded round for a sweep that just exhausted: after the
  /// round's delay the refresh, line and counter budgets are fresh while
  /// the round budget itself only resets on sustained playback.
  ///
  /// Bound to the recovery resolver, like the offline machine: without the
  /// platform seam a round re-opens the same signatures the sweep just
  /// consumed, and the failure reports to the caller instead.
  bool _scheduleRetryRound() {
    if (_disposed || !_playbackRequested || _offline || onRecoverySources == null) {
      return false;
    }

    if (_retryRounds >= watchdogs.liveRetryDelays.length) {
      return false;
    }

    final generation = _playGeneration;
    final delay = watchdogs.liveRetryDelays[_retryRounds++];
    final current = _currentSource;
    final at = current == null ? -1 : _sources.indexOf(current);

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;

      if (_disposed || !_playbackRequested || generation != _playGeneration || _offline) {
        return;
      }

      _resetRecoveryBudgets();
      _sourceIndex = at < 0 ? 0 : at;
      _sweepStart = _sourceIndex;

      MediaCoreLog.info(
        LogCategory.recovery,
        'retry round $_retryRounds after ${delay.inMilliseconds}ms',
        fields: <String, Object?>{'rounds': _retryRounds, 'recoveries': _recoveries, 'line': _sourceIndex},
      );

      _setState(_liveState(PlayerPlaybackState.buffering));
      _emitRecoveryState();

      unawaited(_enqueue(TaskType.recover, _runRecoverTask));
    });

    return true;
  }

  /// Sustained playback restores the refresh, round and attempt budgets.
  void _armBudgetReset() {
    _budgetTimer?.cancel();
    final generation = _playGeneration;
    _budgetTimer = Timer(watchdogs.recoveryBudgetReset, () {
      _budgetTimer = null;

      if (_disposed || generation != _playGeneration || _offline || _draining) {
        return;
      }

      if (state.playback != PlayerPlaybackState.playing) {
        return;
      }

      _refreshAttempts = 0;
      _retryRounds = 0;
      _recoveries = 0;
      _recoveryCause = null;
      _attemptCounted = false;
      _failedLines.clear();

      MediaCoreLog.debug(
        LogCategory.recovery,
        'recovery budgets restored after sustained playback',
        fields: <String, Object?>{'resetAfterMs': watchdogs.recoveryBudgetReset.inMilliseconds},
      );

      _emitRecoveryState();
    });
  }

  /// Enters the offline state: the network stopped answering, so the sweep
  /// hands the stream over to the probe loop instead of burning candidates
  /// on a connection nothing can use. False when there is no way to look at
  /// the network (no resolver) — the caller reports its failure as before.
  bool _enterOffline(Object error) {
    if (_offline || _disposed || onRecoverySources == null) {
      return false;
    }

    _offline = true;
    _offlineSince = DateTime.now();
    _offlinePublished = false;
    _offlineError = error;

    _cancelRecoveryTimers();
    _supersedeQueued('superseded by offline');

    watchdogs.cancelAll();

    MediaCoreLog.warning(
      LogCategory.recovery,
      'network lost — probing every ${watchdogs.networkProbeInterval.inMilliseconds}ms, '
          'publishing after ${watchdogs.offlineGrace.inSeconds}s',
      error: error,
      fields: <String, Object?>{'line': _lineAddress(_currentSource), 'backend': backendId},
    );

    _setState(_liveState(PlayerPlaybackState.buffering));
    _emitRecoveryState();

    _scheduleProbe();

    return true;
  }

  void _scheduleProbe() {
    _probeTimer?.cancel();
    _probeTimer = Timer(watchdogs.networkProbeInterval, () {
      _probeTimer = null;

      unawaited(_probeNetwork());
    });
  }

  /// One look at the network: the recovery resolver, which asks the
  /// platform. Nothing answering again is another probe (after
  /// [LiveWatchdogs.offlineGrace] the offline failure is published); a
  /// non-empty answer reopens the stream as the next attempt with fresh
  /// budgets.
  Future<void> _probeNetwork() async {
    if (_disposed || !_offline || !_playbackRequested) {
      return;
    }

    final resolver = onRecoverySources;
    if (resolver == null) {
      return;
    }

    final generation = _playGeneration;
    List<PlayerSource> fresh;

    try {
      fresh = await resolver(_sources).timeout(watchdogs.networkProbeTimeout);
    } on Object catch (error) {
      if (_disposed || !_offline || generation != _playGeneration) {
        return;
      }

      if (_isNetworkFailure(error)) {
        _offlineError = error;
        _maybePublishOffline();
        _scheduleProbe();

        return;
      }

      // Something answered (a refusal is an answer): the network is back,
      // the sweep reopens from the lines it already holds.
      await _backOnline(const <PlayerSource>[]);

      return;
    }

    if (_disposed || !_offline || generation != _playGeneration) {
      return;
    }

    // An empty answer is inconclusive — a resolver that folds its failures
    // into an empty list looks exactly like a platform with nothing new —
    // so only lines count as the network being back.
    if (fresh.isEmpty) {
      _maybePublishOffline();
      _scheduleProbe();

      return;
    }

    await _backOnline(fresh);
  }

  void _maybePublishOffline() {
    if (_offlinePublished || _offlineSince == null) {
      return;
    }

    if (DateTime.now().difference(_offlineSince!) < watchdogs.offlineGrace) {
      return;
    }

    _offlinePublished = true;

    final room = _request?.title;

    MediaCoreLog.error(
      LogCategory.recovery,
      'network still gone — publishing the offline failure',
      fields: <String, Object?>{'title': ?room, 'offlineForMs': DateTime.now().difference(_offlineSince!).inMilliseconds},
    );

    _setState(_liveState(PlayerPlaybackState.error));

    if (!_failureController.isClosed) {
      _failureController.add(
        PlayerFailure.of(
          code: PlayerErrorCode.networkUnavailable,
          cause: _offlineError,
          message:
              '${room == null ? '' : '$room: '}'
              'The network is gone; playback resumes by itself once it answers.',
        ),
      );
    }
  }

  /// The network answered: fresh budgets, one more counted attempt when the
  /// failure was already on screen, and the sweep reopens the watched line.
  Future<void> _backOnline(List<PlayerSource> fresh) async {
    final published = _offlinePublished;

    _leaveOffline();
    _resetRecoveryBudgets();

    if (published) {
      _recoveries++;
    }

    _recoveryCause = PlayerErrorCode.networkUnavailable.value;
    _attemptCounted = false;

    MediaCoreLog.info(
      LogCategory.recovery,
      'network answered — reopening after $_recoveries attempt(s)',
      fields: <String, Object?>{'lines': fresh.isEmpty ? _sources.length : fresh.length},
    );

    if (fresh.isNotEmpty) {
      await _adoptRefreshedSources(fresh);
    }

    _setState(_liveState(PlayerPlaybackState.buffering));
    _emitRecoveryState();

    unawaited(_enqueue(TaskType.recover, _runRecoverTask));
  }

  /// The recovery attempt is announced ahead of the stall verdict: a live
  /// source that was advancing and stopped shows the reconnect counter now.
  void _noticeStall() {
    if (_disposed || _offline || _draining || !_playbackRequested) {
      return;
    }

    _recoveries++;
    _recoveryCause = LiveStallKind.positionStallNotice.name;
    _attemptCounted = true;

    MediaCoreLog.info(
      LogCategory.recovery,
      'reconnect announced ahead of the stall verdict',
      fields: <String, Object?>{'attempt': _recoveries, 'line': _lineAddress(_currentSource)},
    );

    _setState(_liveState(PlayerPlaybackState.buffering));
    _emitRecoveryState();
  }

  /// A position during a buffering the engine never ended: only
  /// comparisons, until the progress proves the stream lives.
  void _observeBufferingProgress(Duration position) {
    if (_disposed || _offline || !_playbackRequested) {
      return;
    }

    if (state.playback != PlayerPlaybackState.buffering) {
      return;
    }

    final from = _bufferingProgressFrom;

    if (from == null || position < from) {
      _bufferingProgressFrom = position;
      _bufferingProgressAt = DateTime.now();
      _bufferingProgressTo = position;

      return;
    }

    _bufferingProgressTo = position;

    if (position - from < _bufferingProgress) {
      return;
    }

    final to = _bufferingProgressTo;
    final at = _bufferingProgressAt;

    if (at == null || to == null) {
      return;
    }

    final moved = to - from;

    if (moved > DateTime.now().difference(at) + _bufferingProgressSlack) {
      // Further than the clock allows: a timestamp jump; the next progress
      // counts from here.
      _bufferingProgressFrom = position;
      _bufferingProgressAt = DateTime.now();

      return;
    }

    _reconcileBuffering();
  }

  void _observeBufferingFrame() {
    if (_disposed || _offline || !_playbackRequested) {
      return;
    }

    if (state.playback != PlayerPlaybackState.buffering) {
      return;
    }

    final now = DateTime.now();
    final since = _bufferingFramesAt;

    if (since == null || now.difference(since) > const Duration(seconds: 1)) {
      _bufferingFramesAt = now;
      _bufferingFrames = 1;

      return;
    }

    if (++_bufferingFrames >= _bufferingProgressFrames) {
      _reconcileBuffering();
    }
  }

  /// Ends the buffering the engine did not end, the way its own
  /// notification would.
  void _reconcileBuffering() {
    _resetBufferingProgress();

    watchdogs.onBufferingChanged(buffering: false);

    final handle = _handle;

    if (handle == null || handle.disposed) {
      return;
    }

    MediaCoreLog.info(
      LogCategory.recovery,
      'buffering ended by position progress, not by the engine',
      fields: <String, Object?>{'line': _lineAddress(_currentSource), 'backend': handle.backendId},
    );

    _setState(_liveState(PlayerPlaybackState.playing));
  }

  void _resetBufferingProgress() {
    _bufferingProgressFrom = null;
    _bufferingProgressTo = null;
    _bufferingProgressAt = null;
    _bufferingFrames = 0;
    _bufferingFramesAt = null;
  }
}

/// A candidate's address without the part of it that is a credential.
///
/// A signed live URL's query *is* the signature the platform handed out, and the
/// sweep used to write the whole address of every candidate it tried — into each
/// failure log line and into the terminal failure message, which a host may well put
/// on screen. Host and path still answer the only question these lines ask, which is
/// *which line* failed; the same rule the recording manifest follows for its source.
String? _lineAddress(PlayerSource? source) {
  final uri = source?.uri;

  return uri == null ? null : '${uri.host}${uri.path}';
}

/// How often verification re-checks its abandonment and adapter-error
/// conditions while no transport update arrives. Only a fully silent engine
/// ever waits this long: any transport update ends the wait at once.
const Duration _verifyCheckEvery = Duration(milliseconds: 100);

/// Refreshes the recovery window may spend on the platform before it
/// reuses the lines it already holds.
const int _refreshBudget = 2;

/// Position progress that ends an engine's stuck buffering.
const Duration _bufferingProgress = Duration(seconds: 1);

/// How much further than the wall clock a position may jump and still
/// count as progress rather than a seek or a timestamp leap.
const Duration _bufferingProgressSlack = Duration(seconds: 2);

/// Decoded frames within one second that end an engine's stuck buffering.
const int _bufferingProgressFrames = 10;

/// Whether [error] says nothing answered at all: no connection, TLS, a
/// timeout, or an engine failure of the network kind. A cancelled request,
/// a malformed answer and every refusal of the platform are answers, not a
/// missing network.
bool _isNetworkFailure(Object? error) {
  if (error == null) {
    return false;
  }

  if (error is PlayerException) {
    return error.code.isNetworkRelated;
  }

  if (error is PlayerFailure) {
    return error.isNetworkRelated;
  }

  if (error is TimeoutException) {
    return true;
  }

  final reason = RecoveryReason.classify('$error', error);

  return reason.isNetwork || reason.isTimeout;
}
