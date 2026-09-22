import 'dart:async';
import 'live_watchdogs.dart';
import '../core/player_state.dart';
import 'live_playback_models.dart';
import '../error/error_policy.dart';
import '../identity/player_id.dart';
import '../identity/source_id.dart';
import '../error/error_context.dart';
import '../identity/session_id.dart';
import '../operation/operation.dart';
import '../error/player_failure.dart';
import '../kernel/player_handle.dart';
import '../kernel/player_kernel.dart';
import '../source/player_source.dart';
import '../identity/operation_id.dart';
import '../session/session_state.dart';
import '../source/source_headers.dart';
import '../fallback/line_fallback.dart';
import '../identity/generation_id.dart';
import '../session/player_session.dart';
import '../error/player_error_code.dart';
import '../session/session_context.dart';
import '../session/session_manager.dart';
import '../operation/operation_type.dart';
import '../session/session_snapshot.dart';
import '../fallback/backend_fallback.dart';
import '../operation/operation_tracker.dart';
import '../adapter/player_adapter_event.dart';
import '../operation/operation_registry.dart';
import '../operation/operation_cancel_token.dart';

/// A live playback request: primary URL plus fallback lines.
final class LiveSourceRequest {
  const LiveSourceRequest({required this.urls, this.headers = const <String, String>{}, this.title});

  /// Candidate URLs, best first. [urls].first is opened first.
  final List<String> urls;

  /// Optional HTTP headers applied to every line.
  final Map<String, String> headers;

  /// Optional display title for events.
  final String? title;
}

/// Orchestrates live playback on top of a [PlayerKernel].
///
/// Three layers cooperate:
///
/// * **core** — [PlayerState] (observable playback state) and
///   [PlayerFailure] (terminal errors); this is what the app consumes.
/// * **session** — [PlayerSession] / [SessionManager] track the logical
///   playback lifecycle and generation counter. Each open() advances the
///   session generation, which is exactly the "throw away stale async work"
///   guard that used to be a bare int.
/// * **operation** — [Operation] / [OperationTracker] record every
///   user-triggered high-level action (play / retry / switch line / switch
///   engine / close) plus internal recovery attempts. This is diagnostic
///   metadata, not control flow.
///
/// The controller still owns the recovery ladder (same source → line →
/// engine → backoff → terminal) and the watchdog wiring; session and
/// operation are plumbing underneath it.
final class LivePlaybackController {
  LivePlaybackController(
    this.kernel, {
    LiveWatchdogs? watchdogs,
    ErrorPolicy? policy,
    this.backoffDelays = const <Duration>[Duration(milliseconds: 750), Duration(seconds: 2)],
    this.maxSameEngineRecoveryAttempts = 1,
  }) : watchdogs = watchdogs ?? LiveWatchdogs(),
       policy = policy ?? ErrorPolicy.defaults(),
       _playerId = PlayerId.generate(),
       _sessionManager = SessionManager(),
       _operationRegistry = OperationRegistry(),
       _operationTracker = OperationTracker() {
    _wireWatchdogs();
  }

  /// The kernel providing players and adapters.
  final PlayerKernel kernel;

  /// Watchdog bundle inferring stalls.
  final LiveWatchdogs watchdogs;

  /// Policy deciding whether a failure should be retried, recovered,
  /// fallen back, or considered terminal.
  final ErrorPolicy policy;

  /// Backoff schedule after immediate recovery is exhausted.
  final List<Duration> backoffDelays;

  /// Bounded same-engine (source replay) attempts per failure.
  final int maxSameEngineRecoveryAttempts;

  // ---------------------------------------------------------------------------
  // Session / operation infrastructure
  // ---------------------------------------------------------------------------

  /// Stable identity of the logical player owned by this controller.
  final PlayerId _playerId;

  /// Registry of sessions owned by this controller. Today there is exactly
  /// one active session; the manager exists so the shape matches the module
  /// contract and so future multi-session use does not reshape the class.
  final SessionManager _sessionManager;

  /// Authoritative registry of operations known to this controller.
  final OperationRegistry _operationRegistry;

  /// Lifecycle observer for those operations.
  final OperationTracker _operationTracker;

  PlayerSession? _session;

  /// The operation currently in flight, if any.
  Operation? _currentOperation;

  /// Cancellation token paired with [_currentOperation].
  OperationCancelToken? _currentCancelToken;

  // ---------------------------------------------------------------------------
  // Handle + streams
  // ---------------------------------------------------------------------------

  PlayerHandle? _handle;
  StreamSubscription<Object?>? _eventSub;

  int _generation = 0;
  bool _playbackRequested = false;

  LiveSourceRequest? _request;
  String? _currentUrl;
  int _sameEngineAttempts = 0;
  int _backoffAttempt = 0;
  Timer? _backoffTimer;

  final BackendFallback _engineFallback = BackendFallback();
  final LineFallback _lineFallback = LineFallback();

  final _stateController = StreamController<PlayerState>.broadcast();
  final _failureController = StreamController<PlayerFailure>.broadcast();

  /// Playback state stream.
  Stream<PlayerState> get onStateChanged => _stateController.stream;

  /// Terminal failure stream.
  Stream<PlayerFailure> get onError => _failureController.stream;

  /// Live stream of tracked operations.
  ///
  /// Diagnostic surface: emitted for every operation the controller opens,
  /// advances, or closes. Not used for control flow.
  Stream<Operation> get onOperation => _operationTracker.operations;

  /// The operation currently in flight, if any.
  Operation? get currentOperation => _currentOperation;

  /// Latest session snapshot, if a session has been created.
  SessionSnapshot? get sessionSnapshot => _session?.snapshot;

  /// Current playback state.
  PlayerState state = PlayerState.idle;

  /// The active player handle, when one exists.
  PlayerHandle? get handle => _handle;

  /// Current backend id, when a handle exists.
  String? get backendId => _handle?.backendId;

  /// Candidate URLs of the active request.
  List<String> get lines => _request?.urls ?? const <String>[];

  /// Index of the line currently played.
  int get lineIndex {
    final urls = lines;
    final index = urls.indexOf(_currentUrl ?? '');
    return index < 0 ? 0 : index;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts playing [request].
  Future<void> play(LiveSourceRequest request) {
    _request = request;
    _playbackRequested = true;
    _sameEngineAttempts = 0;
    _backoffAttempt = 0;
    _cancelBackoff();

    final generation = ++_generation;
    _beginOperation(OperationType.open);

    return _open(generation, request.urls.first);
  }

  /// Switches to line [index] of the current request.
  Future<void> switchLine(int index) {
    final urls = lines;
    if (index < 0 || index >= urls.length) return Future<void>.value();

    final generation = _generation;
    _beginOperation(OperationType.load);

    return _open(generation, urls[index]);
  }

  /// Replays the current source from scratch.
  Future<void> retry() {
    final url = _currentUrl;
    if (url == null || _request == null) return Future<void>.value();

    _playbackRequested = true;
    _sameEngineAttempts = 0;
    _backoffAttempt = 0;
    _cancelBackoff();

    final generation = ++_generation;
    _beginOperation(OperationType.retry);

    return _open(generation, url);
  }

  /// Pauses playback (a user intent — watchdogs stand down).
  Future<void> pause() async {
    _playbackRequested = false;
    watchdogs.cancelAll();
    _cancelBackoff();
    await _handle?.pause();
    _setState(_liveState(PlayerPlaybackState.paused));
  }

  /// Resumes playback.
  Future<void> resume() async {
    _playbackRequested = true;
    await _handle?.play();
    _setState(_liveState(PlayerPlaybackState.playing));
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
  Future<void> setVolume(double volume) async {
    await _handle?.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Marks whether the current route owns the mounted video
  /// presentation.
  void setPresentationVisible(bool visible) {
    watchdogs.setPresentationVisible(visible);
  }

  /// Stops playback and releases the player.
  Future<void> close() async {
    _beginOperation(OperationType.close);
    _playbackRequested = false;
    _generation++;
    watchdogs.cancelAll();
    _cancelBackoff();
    await _eventSub?.cancel();
    _eventSub = null;
    final handle = _handle;
    _handle = null;
    _currentUrl = null;
    if (handle != null) {
      await kernel.release(handle.id);
    }
    _setState(PlayerState.idle);
    _completeCurrentOperation();
  }

  /// Disposes the controller.
  Future<void> dispose() async {
    await close();

    _cancelCurrentOperation();
    _operationTracker.dispose();
    _operationRegistry.dispose();
    await _sessionManager.dispose();
    _session = null;

    watchdogs.dispose();
    await _stateController.close();
    await _failureController.close();
  }

  // ---------------------------------------------------------------------------
  // Session plumbing
  // ---------------------------------------------------------------------------

  /// Ensures a session exists, creating one if needed.
  PlayerSession _ensureSession(PlayerSource source) {
    final existing = _session;
    if (existing != null) return existing;

    final session = _sessionManager.create(
      SessionContext(
        playerId: _playerId,
        sessionId: SessionId.generate(),
        generationId: GenerationId.generate(),
        sourceId: source.id,
        source: source,
      ),
    );

    _session = session;
    return session;
  }

  /// Advances the session generation and refreshes its source context.
  void _advanceSession(PlayerSource source) {
    final session = _session;
    if (session == null) return;

    session.updateContext(
      session.context.copyWith(sourceId: source.id, source: source, generationId: session.generation.id),
    );

    session.nextGeneration();
  }

  // ---------------------------------------------------------------------------
  // Operation plumbing
  // ---------------------------------------------------------------------------

  /// Opens a new operation, cancelling whichever one was in flight.
  void _beginOperation(OperationType type) {
    _cancelCurrentOperation();

    final created = Operation.created(id: OperationId.generate(), type: type);

    _operationRegistry.register(created);
    _operationTracker.track(created);

    final started = created.start();

    _operationRegistry.update(started);
    _operationTracker.update(started);

    _currentOperation = started;
    _currentCancelToken = OperationCancelToken();
  }

  /// Marks the current operation complete.
  void _completeCurrentOperation() {
    final operation = _currentOperation;
    if (operation == null || operation.isTerminal) return;

    final completed = operation.complete();

    _operationRegistry.update(completed);
    _operationTracker.update(completed);

    _currentCancelToken?.dispose();
    _currentCancelToken = null;
    _currentOperation = null;
  }

  /// Marks the current operation failed.
  void _failCurrentOperation() {
    final operation = _currentOperation;
    if (operation == null || operation.isTerminal) return;

    final failed = operation.fail();

    _operationRegistry.update(failed);
    _operationTracker.update(failed);

    _currentCancelToken?.dispose();
    _currentCancelToken = null;
    _currentOperation = null;
  }

  /// Cancels the current operation.
  void _cancelCurrentOperation() {
    final operation = _currentOperation;
    if (operation == null || operation.isTerminal) {
      _currentCancelToken?.dispose();
      _currentCancelToken = null;
      _currentOperation = null;
      return;
    }

    _currentCancelToken?.cancel('superseded');

    final cancelled = operation.cancel();

    _operationRegistry.update(cancelled);
    _operationTracker.update(cancelled);

    _currentCancelToken?.dispose();
    _currentCancelToken = null;
    _currentOperation = null;
  }

  // ---------------------------------------------------------------------------
  // Opening
  // ---------------------------------------------------------------------------

  Future<void> _open(int generation, String url) async {
    if (!_isCurrent(generation)) return;
    final request = _request;
    if (request == null) return;

    _currentUrl = url;
    _setState(_liveState(PlayerPlaybackState.opening));
    watchdogs.cancelAll();

    try {
      var handle = _handle;

      if (handle == null || handle.disposed) {
        handle = await kernel.create();
        _bindHandle(handle);
      }

      if (!_isCurrent(generation)) return;

      final source = _toSource(url, request);
      _ensureSession(source);
      _advanceSession(source);

      await handle.open(source);
      watchdogs.armSourceReady();
      _setState(_liveState(PlayerPlaybackState.buffering));

      _completeCurrentOperation();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _failCurrentOperation();
      await _recover(
        PlayerFailure(
          code: PlayerErrorCode.backendOpenFailed,
          message: 'open failed: $error',
          cause: error,
          context: _contextFor(url),
        ),
        generation,
      );
    }
  }

  PlayerSource _toSource(String url, LiveSourceRequest request) {
    final headers = request.headers;
    return PlayerSource(
      id: SourceId('live_${_generation}_$lineIndex'),
      uri: Uri.parse(url),
      headers: headers.isEmpty ? null : SourceHeaders(headers),
      title: request.title,
    );
  }

  ErrorContext _contextFor(String? url) {
    return ErrorContext(
      uri: url,
      backend: backendId,
      lineId: lineIndex.toString(),
      state: state.playback.name,
      metadata: <String, Object?>{'generation': _generation},
    );
  }

  // ---------------------------------------------------------------------------
  // Handle binding
  // ---------------------------------------------------------------------------

  void _bindHandle(PlayerHandle handle) {
    _handle = handle;
    _eventSub?.cancel();
    _eventSub = handle.adapter.events.listen(_onAdapterEvent, onError: _onAdapterEventError);
  }

  void _onAdapterEvent(PlayerAdapterEvent adapterEvent) {
    final generation = _generation;
    switch (adapterEvent) {
      case PlayerAdapterPlaying():
        _setState(_liveState(PlayerPlaybackState.playing));
        watchdogs.onPlayingChanged(true, fromUserIntent: false);
        _sameEngineAttempts = 0;
        _backoffAttempt = 0;
        _cancelBackoff();
        _lineFallback.complete();
        _completeCurrentOperation();
      case PlayerAdapterPaused():
        watchdogs.onPlayingChanged(false, fromUserIntent: !_playbackRequested);
        if (!_playbackRequested) {
          _setState(_liveState(PlayerPlaybackState.paused));
        }
      case PlayerAdapterBuffering(buffering: final buffering):
        _setState(_liveState(buffering ? PlayerPlaybackState.buffering : PlayerPlaybackState.playing));
        watchdogs.onBufferingChanged(buffering);
      case PlayerAdapterPositionChanged():
        watchdogs.onFrameProgress();
      case PlayerAdapterErrorEvent(message: final message):
        _scheduleRecovery(
          PlayerFailure(code: PlayerErrorCode.playbackFailed, message: message, context: _contextFor(_currentUrl)),
          generation,
        );
      default:
        break;
    }
  }

  void _onAdapterEventError(Object error) {
    _scheduleRecovery(
      PlayerFailure(
        code: PlayerErrorCode.unknown,
        message: error.toString(),
        cause: error,
        context: _contextFor(_currentUrl),
      ),
      _generation,
    );
  }

  // ---------------------------------------------------------------------------
  // Recovery ladder
  // ---------------------------------------------------------------------------

  void _scheduleRecovery(PlayerFailure failure, int generation) {
    Timer.run(() => _recover(failure, generation));
  }

  Future<void> _recover(PlayerFailure failure, int generation) async {
    if (!_isCurrent(generation) || !_playbackRequested) return;

    watchdogs.cancelAll();
    _setState(_liveState(PlayerPlaybackState.buffering));

    final action = policy.decide(failure, retryCount: _sameEngineAttempts);

    if (action == ErrorPolicyAction.ignore || action == ErrorPolicyAction.cancel) {
      return;
    }

    if (action == ErrorPolicyAction.fail) {
      _failCurrentOperation();
      await _terminate(failure);
      return;
    }

    // Open a fresh operation for the recovery attempt itself. The
    // originating user operation (play/retry/switchLine) is already
    // terminal by now — either completed on success or failed on
    // error — so this replaces it cleanly.
    _beginOperation(_operationTypeFor(action));

    // 1. Same-engine bounded replay.
    if ((action == ErrorPolicyAction.retry || action == ErrorPolicyAction.recover) &&
        _currentUrl != null &&
        _sameEngineAttempts < maxSameEngineRecoveryAttempts) {
      _sameEngineAttempts++;
      await _open(generation, _currentUrl!);
      return;
    }

    // 2. Line switch.
    if (action == ErrorPolicyAction.fallback ||
        action == ErrorPolicyAction.retry ||
        action == ErrorPolicyAction.recover) {
      final urls = lines;
      if (urls.length > 1 && _currentUrl != null) {
        final nextIndex = (lineIndex + 1) % urls.length;
        if (urls[nextIndex] != _currentUrl) {
          _sameEngineAttempts = 0;
          await _open(generation, urls[nextIndex]);
          return;
        }
      }
    }

    // 3. Engine switch.
    if (action == ErrorPolicyAction.fallback ||
        action == ErrorPolicyAction.retry ||
        action == ErrorPolicyAction.recover) {
      final switched = await _trySwitchEngine(generation);
      if (switched) {
        _sameEngineAttempts = 0;
        return;
      }
    }

    // 4. Backoff retry.
    if (_backoffAttempt < backoffDelays.length) {
      final delay = backoffDelays[_backoffAttempt++];
      _setState(_liveState(PlayerPlaybackState.buffering));
      _cancelBackoff();
      _backoffTimer = Timer(delay, () {
        _backoffTimer = null;
        if (!_isCurrent(generation) || !_playbackRequested) return;
        _sameEngineAttempts = 0;
        _backoffAttempt = 0;
        final url = _currentUrl;
        if (url != null) {
          unawaited(_open(generation, url));
        }
      });
      return;
    }

    // 5. Terminal.
    _failCurrentOperation();
    await _terminate(failure);
  }

  OperationType _operationTypeFor(ErrorPolicyAction action) {
    switch (action) {
      case ErrorPolicyAction.retry:
        return OperationType.retry;
      case ErrorPolicyAction.recover:
        return OperationType.recover;
      case ErrorPolicyAction.fallback:
        return OperationType.fallback;
      case ErrorPolicyAction.fail:
      case ErrorPolicyAction.cancel:
      case ErrorPolicyAction.ignore:
        return OperationType.retry;
    }
  }

  Future<void> _terminate(PlayerFailure failure) async {
    _playbackRequested = false;
    _setState(_liveState(PlayerPlaybackState.error));
    _session?.updateState(const SessionState.error());
    if (!_failureController.isClosed) {
      _failureController.add(failure);
    }
  }

  Future<bool> _trySwitchEngine(int generation) async {
    final candidates = kernel.registry.registrations
        .where((registration) => registration.enabled && registration.id != backendId)
        .map((registration) => registration.id)
        .toList();
    if (candidates.isEmpty) return false;

    _engineFallback.start(candidates, currentBackend: backendId);
    final next = _engineFallback.next();
    if (next == null) return false;

    final handle = _handle;
    if (handle == null) return false;

    try {
      final registration = kernel.registry.get(next);
      if (registration == null) return false;

      await handle.attachAdapter(registration);

      final url = _currentUrl;
      final request = _request;
      if (url == null || request == null) return false;

      final source = _toSource(url, request);
      _advanceSession(source);

      await handle.open(source);
      watchdogs.armSourceReady();
      _completeCurrentOperation();
      return true;
    } catch (_) {
      _engineFallback.markFailed();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  bool _isCurrent(int generation) => generation == _generation && _request != null;

  PlayerState _liveState(PlayerPlaybackState playback) {
    return PlayerState(lifecycle: PlayerLifecycleState.ready, playback: playback, hasSource: true);
  }

  void _setState(PlayerState next) {
    if (state == next) return;
    state = next;

    // Mirror into the session so the session's SessionSnapshot stream
    // carries the same lifecycle information the app already consumes.
    _session?.updateState(_toSessionState(next));

    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  SessionState _toSessionState(PlayerState playerState) {
    switch (playerState.playback) {
      case PlayerPlaybackState.idle:
        return const SessionState.idle();
      case PlayerPlaybackState.opening:
        return const SessionState.opening();
      case PlayerPlaybackState.playing:
        return const SessionState.playing();
      case PlayerPlaybackState.paused:
        return const SessionState.paused();
      case PlayerPlaybackState.buffering:
        return const SessionState.buffering();
      case PlayerPlaybackState.stopped:
      case PlayerPlaybackState.stopping:
        return const SessionState.stopped();
      case PlayerPlaybackState.completed:
        return const SessionState.completed();
      case PlayerPlaybackState.error:
        return const SessionState.error();
      case PlayerPlaybackState.seeking:
        // Live streams do not seek; treat as an in-flight transition.
        return const SessionState.buffering();
    }
  }

  void _cancelBackoff() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Watchdog wiring
  // ---------------------------------------------------------------------------

  void _wireWatchdogs() {
    watchdogs.onStall = (kind) {
      if (!_playbackRequested) return;
      _scheduleRecovery(_failureForStall(kind), _generation);
    };
    watchdogs.onReassertPlay = () async {
      final handle = _handle;
      if (handle == null) return false;
      try {
        await handle.play();
        return true;
      } catch (_) {
        return false;
      }
    };
  }

  /// Maps a watchdog-inferred [LiveStallKind] onto the shared error
  /// model. This is the only place where live-specific stall kinds
  /// enter the error pipeline.
  PlayerFailure _failureForStall(LiveStallKind kind) {
    final code = switch (kind) {
      LiveStallKind.sourceReadyTimeout => PlayerErrorCode.timeout,
      LiveStallKind.unexpectedPauseResumed => PlayerErrorCode.playbackFailed,
      LiveStallKind.unexpectedPauseResumeFailed => PlayerErrorCode.backendPlayFailed,
      LiveStallKind.unexpectedPauseTimeout => PlayerErrorCode.playbackFailed,
      LiveStallKind.bufferingStallTimeout => PlayerErrorCode.insufficientBandwidth,
      LiveStallKind.videoFrameStallTimeout => PlayerErrorCode.decoderError,
    };

    return PlayerFailure(
      code: code,
      message: 'live stall: ${kind.name}',
      cause: kind,
      context: _contextFor(_currentUrl),
    );
  }
}
