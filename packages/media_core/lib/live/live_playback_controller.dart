import 'dart:async';

import 'live_request.dart';
import 'live_watchdogs.dart';
import '../core/player_state.dart';
import '../diagnostics/log_category.dart';
import '../diagnostics/media_core_log.dart';
import '../error/player_error_code.dart';
import '../error/player_failure.dart';
import '../identity/player_id.dart';
import '../operation/operation_type.dart';
import '../session/session_snapshot.dart';
import '../session/session_state.dart';
import '../identity/generation_id.dart';
import '../task/task_id.dart';
import '../adapter/player_adapter_event.dart';
import '../kernel/player_handle.dart';
import '../kernel/player_kernel.dart';
import '../source/player_source.dart';
import '../task/task_cancel_token.dart';
import '../task/task_manager.dart';
import '../task/task_type.dart';

/// How long a freshly opened source has to prove that playback is real.
const Duration _verificationWindow = Duration(seconds: 8);

/// Orchestrates live playback on top of a [PlayerKernel].
///
/// One structural idea holds the module together: **every action is a task
/// on a single-slot [TaskManager]** — play, switch line, retry, pause,
/// resume, close, recover. The queue serializes them, so none of the
/// classic live-playback races can exist by construction:
///
/// - a recovery task and a user action cannot interleave — the user's task
///   runs first, and queued recovery work is cancelled when the user takes
///   over ([pause], [close], [play], [retry], [switchLine]);
/// - two rapid `play()` calls cannot double-open — the first is cancelled
///   out of the queue before the second starts;
/// - an engine switch cannot replay a stale request over a newer one —
///   there is no delayed replay anywhere; a switch is just the next task.
///
/// Recovery is a plain function of the caller's declarations, not a
/// subsystem:
///
/// ```text
/// attempt(source, engine) fails
///   → next source on the same engine           (the lines the caller gave)
///   → sources exhausted → next engine, sweep again    (if the caller allowed)
///   → nothing left → PlayerFailure on [onError]
/// ```
///
/// "Fails" means one of: the open threw, the engine could not be attached,
/// or — the case that used to look like a freeze — the source opened
/// cleanly but playback position never advanced within
/// [_verificationWindow]. Verification is what makes the sweep honest.
///
/// Watchdogs stay pure detectors: a stall or an adapter error becomes a
/// recover task — reopen the current source once, then join the same
/// sweep. The kernel-side recovery ladder is disabled for live players, so
/// there is exactly one recovery path and the caller can read all of it
/// here.
final class LivePlaybackController {
  LivePlaybackController(this.kernel, {LiveWatchdogs? watchdogs})
    : watchdogs = watchdogs ?? LiveWatchdogs() {
    _wireWatchdogs();
  }

  /// The kernel providing players and adapters.
  final PlayerKernel kernel;

  /// Watchdog bundle inferring stalls.
  final LiveWatchdogs watchdogs;

  /// Single-slot queue. Every user action and every recovery step is a
  /// task here; capacity one makes the controller sequential by design.
  final TaskManager _tasks = TaskManager(maxConcurrentTasks: 1);

  final Map<TaskId, _PendingTask> _pending = <TaskId, _PendingTask>{};

  bool _draining = false;
  bool _disposed = false;

  /// Bumped by [play] and [close]. A sweep captures it when it starts and
  /// abandons itself if it moved meanwhile.
  int _playGeneration = 0;

  LiveSourceRequest? _request;
  List<PlayerSource> _sources = const <PlayerSource>[];
  List<String> _engines = const <String>[];
  int _engineIndex = 0;
  int _sourceIndex = 0;
  PlayerHandle? _handle;
  PlayerSource? _currentSource;
  String? _preferredBackend;
  bool _engineFallbackAllowed = true;
  bool _playbackRequested = false;
  bool _audioOnly = false;
  PlayerState state = PlayerState.idle;

  /// Line each engine's sweep starts from: the line that was being played
  /// when the previous engine failed, so a fresh engine first retries the
  /// line the user was watching.
  int _sweepStart = 0;

  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();
  final StreamController<PlayerFailure> _failureController = StreamController<PlayerFailure>.broadcast();
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;
  StreamSubscription<PlayerBackendChange>? _backendSub;

  /// Playback state stream.
  Stream<PlayerState> get onStateChanged => _stateController.stream;

  /// Terminal failure stream. Emitted exactly once per exhausted sweep.
  Stream<PlayerFailure> get onError => _failureController.stream;

  /// The active player handle, when one exists.
  PlayerHandle? get handle => _handle;

  /// Current backend id, when a handle exists.
  String? get backendId => _handle?.backendId;

  /// Identity of the logical player, when a handle exists.
  ///
  /// One identity per player, owned by the handle — the controller does
  /// not mint its own.
  PlayerId? get playerId => _handle?.id;

  /// Latest session snapshot of the player.
  ///
  /// The session is the handle's; this is a passthrough, not a second one.
  SessionSnapshot? get sessionSnapshot => _handle?.snapshot;

  /// Candidate sources of the active request.
  List<PlayerSource> get sources => _sources;

  /// Index of the source currently being played.
  int get sourceIndex => _sourceIndex;

  /// Whether playback is restricted to the audio track.
  bool get audioOnly => _audioOnly;

  // ---------------------------------------------------------------------------
  // Public actions — every one of them a queued task
  // ---------------------------------------------------------------------------

  /// Starts playing [request].
  ///
  /// [preferredBackend] pins the engine for this playback; when omitted the
  /// engine order is the selector's scored order for the primary source.
  Future<void> play(LiveSourceRequest request, {String? preferredBackend}) {
    _request = request;
    _sources = request.sources;
    _preferredBackend = preferredBackend;
    _engineFallbackAllowed = request.allowEngineFallback ?? request.hasAlternatives;
    _playbackRequested = true;
    _playGeneration++;
    _sweepStart = 0;

    _supersedeQueued('superseded by play');

    return _enqueue(TaskType.open, (_) => _startPlayback());
  }

  /// Switches to the source at [index].
  Future<void> switchLine(int index) {
    if (index < 0 || index >= _sources.length) {
      return Future<void>.value();
    }

    _sourceIndex = index;
    _sweepStart = index;
    _playbackRequested = true;
    _playGeneration++;

    _supersedeQueued('superseded by line switch');

    return _enqueue(TaskType.load, (_) => _openCurrentSource());
  }

  /// Replays the current source from scratch.
  Future<void> retry() {
    if (_request == null || _sources.isEmpty) {
      return Future<void>.value();
    }

    _playbackRequested = true;
    _playGeneration++;

    _supersedeQueued('superseded by retry');

    return _enqueue(TaskType.retry, (_) => _openCurrentSource());
  }

  /// Pauses playback. Cancels queued recovery: a user pause is a recovery
  /// boundary, not a recovery opportunity.
  Future<void> pause() async {
    _playbackRequested = false;
    _playGeneration++;

    _supersedeQueued('superseded by pause');

    watchdogs.cancelAll();

    await _enqueue(TaskType.pause, (token) async {
      await _handle?.pause();
      _setState(_liveState(PlayerPlaybackState.paused));
    });
  }

  /// Resumes playback.
  Future<void> resume() async {
    _playbackRequested = true;

    await _enqueue(TaskType.play, (token) async {
      final handle = _handle;

      if (handle == null || handle.disposed) {
        return;
      }

      await handle.play();
      _setState(_liveState(PlayerPlaybackState.playing));
    });
  }

  /// Toggles pause/resume.
  Future<void> togglePlayPause() async {
    if (state.playback == PlayerPlaybackState.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Sets volume (0.0–1.0).
  Future<void> setVolume(double volume) {
    return _handle?.setVolume(volume.clamp(0.0, 1.0).toDouble()) ?? Future<void>.value();
  }

  /// Mutes or unmutes audio output.
  Future<void> setMute(bool muted) {
    return _handle?.setMute(muted) ?? Future<void>.value();
  }

  /// Whether audio output is muted.
  bool get muted => _handle?.muted ?? false;

  /// Sets whether playback restarts after completion.
  Future<void> setLoop(bool loop) {
    return _handle?.setLoop(loop) ?? Future<void>.value();
  }

  /// Current playback position on the attached engine.
  Duration get position => _handle?.position ?? Duration.zero;

  /// Stream duration on the attached engine (zero for live streams).
  Duration get duration => _handle?.duration ?? Duration.zero;

  /// Restricts playback to the audio track.
  Future<void> setAudioOnly(bool audioOnly) async {
    _audioOnly = audioOnly;

    watchdogs.setVideoExpected(!audioOnly);

    await _handle?.setAudioOnly(audioOnly);
  }

  /// Marks whether the current route owns the mounted video presentation.
  void setPresentationVisible(bool visible) {
    watchdogs.setPresentationVisible(visible);
  }

  /// Records that the app was backgrounded and the player was auto-paused.
  ///
  /// Without this, the unexpected-pause watchdog reads the background
  /// auto-pause as a network fault and silently resumes playback the user
  /// cannot see. A background pause is a system intent: playback is no
  /// longer requested until the user resumes.
  void noteBackgrounded() {
    _playbackRequested = false;

    watchdogs.cancelAll();
  }

  /// Stops playback and releases the player.
  Future<void> close() async {
    _playbackRequested = false;
    _playGeneration++;

    _supersedeQueued('superseded by close');

    watchdogs.cancelAll();

    await _enqueue(TaskType.close, (token) async {
      await _releaseHandle();
      _setState(PlayerState.idle);
    });
  }

  /// Disposes the controller.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _playbackRequested = false;
    _playGeneration++;

    _supersedeQueued('superseded by dispose');
    watchdogs.cancelAll();

    await _adapterSub?.cancel();
    _adapterSub = null;
    await _backendSub?.cancel();
    _backendSub = null;

    await _releaseHandle();

    watchdogs.dispose();

    _tasks.dispose();
    await _stateController.close();
    await _failureController.close();
  }

  // ---------------------------------------------------------------------------
  // The sweep: engine × source, verified
  // ---------------------------------------------------------------------------

  Future<void> _startPlayback() async {
    _engines = _engineOrder();
    _engineIndex = 0;
    _sourceIndex = 0;

    await _sweep();
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

    while (!_disposed && _playbackRequested && generation == _playGeneration) {
      final source = _sources[_sourceIndex];
      final engine = _engines[_engineIndex];

      try {
        await _openOn(engine, source);

        return;
      } catch (error) {
        MediaCoreLog.warning(
          LogCategory.recovery,
          'candidate failed: ${source.uri} on $engine'
              '${first && startAtCurrent ? ' (reopen of the playing line)' : ''}',
          error: error,
          fields: <String, Object?>{'sourceIndex': _sourceIndex, 'engineIndex': _engineIndex},
        );

        first = false;
      }

      if (!_nextCandidate()) {
        await _reportExhausted(source, engine);

        return;
      }
    }
  }

  /// Moves to the next candidate: next source, else next engine (when
  /// allowed) restarting its sweep at the line the user was watching.
  bool _nextCandidate() {
    if (_sourceIndex + 1 < _sources.length) {
      _sourceIndex++;

      return true;
    }

    if (!_engineFallbackAllowed || _engineIndex + 1 >= _engines.length) {
      return false;
    }

    MediaCoreLog.info(
      LogCategory.fallback,
      'all sources failed on ${_engines[_engineIndex]} — switching to ${_engines[_engineIndex + 1]}',
      fields: <String, Object?>{
        'from': _engines[_engineIndex],
        'to': _engines[_engineIndex + 1],
        'resumeAtLine': _sweepStart,
      },
    );

    _engineIndex++;
    _sourceIndex = _sweepStart;

    return true;
  }

  /// Opens [source] on [engine], starts playback and verifies it.
  ///
  /// The handle is created per engine and kept while the engine stays the
  /// same: line switches inside one engine re-open on the existing handle,
  /// an engine switch releases and rebuilds it.
  Future<void> _openOn(String engine, PlayerSource source) async {
    final generation = _playGeneration;

    var handle = _handle;

    if (handle == null || handle.disposed || handle.backendId != engine) {
      await _releaseHandle();

      MediaCoreLog.info(
        LogCategory.fallback,
        'attaching engine $engine for ${source.uri}',
        fields: <String, Object?>{'line': _sourceIndex},
      );

      handle = await kernel.create(preferredBackend: engine);
      _attach(handle);
    }

    _setState(_liveState(PlayerPlaybackState.opening));

    // Recovery is this module's job; the handle's own ladder stays
    // dormant so there is exactly one recovery path.
    handle.setRecoveryEnabled(false);
    handle.declarePlayIntent(true);

    await handle.open(source);

    if (_abandoned(generation)) {
      return;
    }

    await handle.play();

    // The step that separates "opened" from "playing": without it an
    // engine that accepts the source but never delivers a frame reads as
    // success and the sweep stops on a frozen player.
    await _verifyPlayback(handle, source);

    if (_abandoned(generation)) {
      return;
    }

    _currentSource = source;

    watchdogs.armSourceReady();
    watchdogs.resetPositionSignal();

    _setState(_liveState(PlayerPlaybackState.buffering));
  }

  /// Waits until [handle]'s playback position actually advances.
  ///
  /// An engine that accepts a source but never delivers a frame — the
  /// "freeze that looks like success" — fails here instead of ending the
  /// sweep on a silent player.
  Future<void> _verifyPlayback(PlayerHandle handle, PlayerSource source) async {
    final until = DateTime.now().add(_verificationWindow);
    var last = handle.playbackStream.value.position;

    while (DateTime.now().isBefore(until)) {
      if (_disposed || !_playbackRequested) {
        throw StateError('Playback verification abandoned: playback was stopped.');
      }

      final position = handle.playbackStream.value.position;

      if (position > last + const Duration(milliseconds: 400)) {
        return;
      }

      if (position > last) {
        last = position;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw StateError(
      '${source.uri} on ${handle.backendId} opened but never played '
      '(no position progress in ${_verificationWindow.inSeconds}s).',
    );
  }

  /// Terminal: every allowed candidate failed. Exactly one failure per
  /// sweep — the caller decides what happens next.
  Future<void> _reportExhausted(PlayerSource source, String engine) async {
    MediaCoreLog.error(
      LogCategory.recovery,
      'live sweep exhausted — reporting to the caller',
      fields: <String, Object?>{
        'sources': _sources.length,
        'enginesTried': _engineFallbackAllowed ? _engineIndex + 1 : 1,
        'lastEngine': engine,
        'lastLine': source.uri.toString(),
      },
    );

    _setState(_liveState(PlayerPlaybackState.error));

    if (!_failureController.isClosed) {
      _failureController.add(
        PlayerFailure(
          code: PlayerErrorCode.noPlayableStream,
          message: 'Live playback failed after trying ${_sources.length} source(s)'
              '${_engineFallbackAllowed ? ' across ${_engineIndex + 1} engine(s)' : ''}. '
              'Last attempt: ${source.uri} on $engine.',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Engine order and handle lifecycle
  // ---------------------------------------------------------------------------

  /// Backend ids to try, best first: the pinned engine (if any), then the
  /// selector's scored order for the primary source.
  List<String> _engineOrder() {
    final primary = _sources.isNotEmpty ? _sources.first : _request?.primary;
    final scored = kernel.selector
        .candidatesFor(primary ?? _request!.primary)
        .where((registration) => registration.enabled)
        .map((registration) => registration.id)
        .toList(growable: false);

    final pinned = _preferredBackend;

    if (pinned == null || !scored.contains(pinned)) {
      return scored;
    }

    return <String>[pinned, ...scored.where((id) => id != pinned)];
  }

  void _attach(PlayerHandle handle) {
    _handle = handle;

    handle.setRecoveryEnabled(false);

    watchdogs.updateCapabilities(handle.adapter.capabilities);
    watchdogs.setVideoExpected(!_audioOnly);

    _adapterSub?.cancel();
    _adapterSub = handle.adapterEvents.listen(_onAdapterEvent, onError: (Object _) {});

    _backendSub?.cancel();
    _backendSub = handle.backendChanges.listen((change) {
      watchdogs.updateCapabilities(change.adapter.capabilities);
      watchdogs.setVideoExpected(!_audioOnly);
    });

    if (_audioOnly) {
      unawaited(handle.setAudioOnly(true));
    }
  }

  Future<void> _releaseHandle() async {
    _adapterSub?.cancel();
    _adapterSub = null;
    _backendSub?.cancel();
    _backendSub = null;

    final handle = _handle;
    _handle = null;
    _currentSource = null;

    watchdogs.updateCapabilities(null);

    if (handle != null) {
      try {
        await kernel.release(handle.id);
      } catch (_) {
        // Best-effort release of an engine that may already be gone.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Watchdogs and adapter events → recover tasks
  // ---------------------------------------------------------------------------

  void _wireWatchdogs() {
    watchdogs.onStall = (kind) {
      if (!_playbackRequested || _disposed) {
        return;
      }

      MediaCoreLog.warning(
        LogCategory.recovery,
        'watchdog stall: ${kind.name}',
        fields: <String, Object?>{'line': _currentSource?.uri.toString(), 'backend': backendId},
      );

      // A stall is a failure like any other: reopen the playing line
      // first, then let the sweep decide. Queued behind whatever is in
      // flight; superseded by the next user action.
      _supersedeQueued('superseded by stall recovery');
      _sweepStart = _sourceIndex;

      unawaited(_enqueue(TaskType.recover, _runRecoverTask));
    };

    watchdogs.onRecoveryRequested = (action) {
      if (!_playbackRequested || _disposed) {
        watchdogs.reportRecoveryResult(false);
        return;
      }

      // reassertPlay is a command, not a recovery: it goes through the
      // handle directly so the watchdog gets its answer immediately.
      final handle = _handle;

      if (handle == null || handle.disposed) {
        watchdogs.reportRecoveryResult(false);
        return;
      }

      unawaited(
        handle.play().then((_) {
          watchdogs.reportRecoveryResult(true);
        }, onError: (Object _) {
          watchdogs.reportRecoveryResult(false);
        }),
      );
    };
  }

  Future<void> _runRecoverTask(TaskCancelToken token) {
    return _sweep(startAtCurrent: true);
  }

  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case PlayerAdapterPlaying():
        _setState(_liveState(PlayerPlaybackState.playing));
        watchdogs.onPlayingChanged(true, fromUserIntent: false);

      case PlayerAdapterPaused():
        watchdogs.onPlayingChanged(false, fromUserIntent: !_playbackRequested);

        if (!_playbackRequested) {
          _setState(_liveState(PlayerPlaybackState.paused));
        }

      case PlayerAdapterBuffering(buffering: final buffering):
        _setState(_liveState(buffering ? PlayerPlaybackState.buffering : PlayerPlaybackState.playing));
        watchdogs.onBufferingChanged(buffering);

      case PlayerAdapterPositionChanged(position: final position):
        watchdogs.onPositionProgress(position);

      case PlayerAdapterVideoFrameProgress():
        watchdogs.onFrameProgress();

      case PlayerAdapterErrorEvent(message: final message):
        MediaCoreLog.warning(
          LogCategory.error,
          'adapter error: $message',
          fields: <String, Object?>{'backend': backendId, 'line': _currentSource?.uri.toString()},
        );

        if (_playbackRequested) {
          _supersedeQueued('superseded by adapter error');
          _sweepStart = _sourceIndex;

          unawaited(_enqueue(TaskType.recover, _runRecoverTask));
        }

      case PlayerAdapterVideoSizeChanged():
      case PlayerAdapterStopped():
      case PlayerAdapterCompleted():
      case PlayerAdapterOpened():
      case PlayerAdapterDurationChanged():
      case PlayerAdapterVideoReconfigured():
      case PlayerAdapterHwdecChanged():
      case PlayerAdapterAudioReconfigured():
      case PlayerAdapterAudioDeviceChanged():
      case PlayerAdapterSubtitleChanged():
      case PlayerAdapterCacheChanged():
      case PlayerAdapterMetadataChanged():
      case PlayerAdapterPlaylistChanged():
      case PlayerAdapterClientMessage():
      case PlayerAdapterLogMessage():
      case PlayerAdapterVolumeChanged():
      case PlayerAdapterRateChanged():
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Task queue plumbing
  // ---------------------------------------------------------------------------

  /// Queues [action] as a task and starts draining.
  ///
  /// The action travels with its task: the drain handler dispatches by
  /// task id, so the order actions were enqueued in is the order they run
  /// in, regardless of which enqueue happened to start the drain.
  Future<void> _enqueue(TaskType type, Future<void> Function(TaskCancelToken token) action) {
    final pending = _PendingTask(action);
    final task = _tasks.createAndQueue(
      id: TaskId.generate(),
      type: type,
      playerId: _handle?.id,
      generationId: GenerationId.generate(),
    );

    _pending[task.id] = pending;

    unawaited(_drain());

    return pending.completer.future;
  }

  /// Runs queued tasks one at a time. Capacity is one; this loop is what
  /// turns the queue into the controller's serialization spine.
  Future<void> _drain() async {
    if (_draining) {
      return;
    }

    _draining = true;

    try {
      while (!_disposed && _tasks.hasQueuedTasks) {
        try {
          await _tasks.executeAvailable((task) async {
            final pending = _pending.remove(task.id);

            if (pending == null) {
              return null;
            }

            final token = _tasks.cancelToken(task.id);

            // The operation record lives on the handle (the anchor every
            // consumer holds). A task that creates the handle records from
            // the moment it exists; earlier there is simply nothing to
            // record on.
            _handle?.beginOperation(_operationTypeOf(task.type));

            try {
              if (token == null || !token.isCancelled) {
                await pending.action(token ?? TaskCancelToken());
              }

              pending.completer.complete();
              _handle?.completeOperation();
            } catch (error, stackTrace) {
              pending.completer.completeError(error, stackTrace);
              _handle?.failOperation();
              rethrow;
            }

            return null;
          });
        } catch (error) {
          // A task that threw after its own completer was already settled
          // (or a manager-level failure) ends here; the task record keeps
          // the failure for diagnostics.
          MediaCoreLog.debug(LogCategory.player, 'live task ended: $error');
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Cancels every queued (not yet started) task and releases its waiter.
  void _supersedeQueued(String reason) {
    final cancelled = _tasks.cancelQueuedTasks(reason);

    for (final task in cancelled) {
      _pending.remove(task.id)?.completer.complete();
    }
  }

  /// Task types and operation types describe the same actions; the record
  /// is written in the operation module's vocabulary.
  OperationType _operationTypeOf(TaskType type) {
    return switch (type) {
      TaskType.open => OperationType.open,
      TaskType.load => OperationType.load,
      TaskType.retry => OperationType.retry,
      TaskType.pause => OperationType.pause,
      TaskType.play => OperationType.play,
      TaskType.close => OperationType.close,
      TaskType.recover => OperationType.recover,
      TaskType.fallback => OperationType.fallback,
      _ => OperationType.load,
    };
  }

  bool _abandoned(int generation) {
    return _disposed || !_playbackRequested || generation != _playGeneration;
  }

  // ---------------------------------------------------------------------------
  // State mirroring
  // ---------------------------------------------------------------------------

  PlayerState _liveState(PlayerPlaybackState playback) {
    return PlayerState(lifecycle: PlayerLifecycleState.ready, playback: playback, hasSource: _sources.isNotEmpty);
  }

  void _setState(PlayerState next) {
    if (state == next) {
      return;
    }

    state = next;

    // Mirror into the handle's session — the one session this player has.
    // Consumers reading SessionSnapshot from the handle see the same
    // lifecycle the controller reports on [onStateChanged].
    _handle?.session.updateState(_toSessionState(next));

    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  SessionState _toSessionState(PlayerState playerState) {
    return switch (playerState.playback) {
      PlayerPlaybackState.idle => const SessionState.idle(),
      PlayerPlaybackState.opening => const SessionState.opening(),
      PlayerPlaybackState.playing => const SessionState.playing(),
      PlayerPlaybackState.paused => const SessionState.paused(),
      PlayerPlaybackState.buffering => const SessionState.buffering(),
      PlayerPlaybackState.stopped || PlayerPlaybackState.stopping => const SessionState.stopped(),
      PlayerPlaybackState.completed => const SessionState.completed(),
      PlayerPlaybackState.error => const SessionState.error(),
      // Live streams do not seek; treat as an in-flight transition.
      PlayerPlaybackState.seeking => const SessionState.buffering(),
    };
  }
}

/// A queued action paired with the future of whoever awaited it.
final class _PendingTask {
  _PendingTask(this.action) : completer = Completer<void>();

  final Future<void> Function(TaskCancelToken token) action;
  final Completer<void> completer;
}
