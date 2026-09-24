import 'dart:async';
import 'live_watchdogs.dart';
import '../core/player_state.dart';
import 'live_playback_models.dart';
import '../error/error_policy.dart';
import '../identity/player_id.dart';
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
import '../adapter/player_adapter.dart';
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
import 'package:media_core/identity/source_id.dart';

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
///
/// Capability handling: the controller never reads individual capability
/// flags except to decide whether a command can be attempted. It forwards
/// the active adapter's whole [PlayerAdapterCapabilities] snapshot to
/// [LiveWatchdogs] whenever the adapter instance changes — on first bind,
/// on engine switch, and on close (as null). The watchdog bundle reads the
/// fields it cares about directly from that snapshot.
///
/// The audio-only preference is the one session mode the controller keeps
/// on behalf of the application. [setAudioOnly] stores it, pushes it to
/// the active adapter (`supportsAudioOnly`) and tells the watchdogs that
/// no video frames are expected; [_bindHandle] pushes it onto every newly
/// bound adapter, so an engine fallback inside this class cannot silently
/// restore video.
///
/// That preference is also why the frame watchdog is disabled at the
/// session level rather than by capability: an audio-only source has no
/// video track, and whether the adapter *could* report a frame heartbeat
/// says nothing about whether one will ever arrive.
///
/// Recovery ownership:
///
/// * [LiveWatchdogs] detects stalls only.
/// * [LiveWatchdogs] emits [LiveWatchdogRecoveryAction].
/// * [LivePlaybackController] translates that action into a playback
///   command.
/// * [PlayerHandle] is the only lifecycle-safe backend operation boundary.
///
/// The controller never calls an adapter directly for recovery.
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
  bool _audioOnly = false;

  /// Generation of the watchdog recovery request currently being executed.
  ///
  /// This is separate from [_generation]:
  ///
  /// - [_generation] identifies the logical playback/source lifecycle.
  /// - [_watchdogRecoveryGeneration] identifies one watchdog recovery
  ///   command.
  ///
  /// A recovery result from an older request must never settle a newer
  /// watchdog recovery request.
  int _watchdogRecoveryGeneration = 0;

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

    _watchdogRecoveryGeneration++;

    final generation = ++_generation;

    _beginOperation(OperationType.open);

    // Seed the line fallback with this request's candidates. The ladder
    // relies on it to know which lines were already tried, so the candidate
    // set must be injected here and re-seeded on every fresh play().
    _lineFallback.start(request.urls, currentLine: request.urls.first);

    return _open(generation, request.urls.first);
  }

  /// Switches to line [index] of the current request.
  Future<void> switchLine(int index) {
    final urls = lines;

    if (index < 0 || index >= urls.length) {
      return Future<void>.value();
    }

    _watchdogRecoveryGeneration++;

    final generation = _generation;

    _beginOperation(OperationType.load);

    _lineFallback.start(urls, currentLine: urls[index]);

    return _open(generation, urls[index]);
  }

  /// Replays the current source from scratch.
  Future<void> retry() {
    final url = _currentUrl;

    if (url == null || _request == null) {
      return Future<void>.value();
    }

    _playbackRequested = true;
    _sameEngineAttempts = 0;
    _backoffAttempt = 0;

    _cancelBackoff();

    _watchdogRecoveryGeneration++;

    final generation = ++_generation;

    _beginOperation(OperationType.retry);

    // A manual retry restarts the whole line ladder from the current line.
    final urls = lines;
    if (urls.isNotEmpty) {
      _lineFallback.start(urls, currentLine: url);
    }

    return _open(generation, url);
  }

  /// Pauses playback (a user intent — watchdogs stand down).
  Future<void> pause() async {
    _playbackRequested = false;

    // A user pause is a lifecycle boundary for recovery.
    // Any recovery already waiting inside the controller becomes stale.
    _watchdogRecoveryGeneration++;

    watchdogs.cancelAll();
    _cancelBackoff();

    await _handle?.pause();

    _setState(_liveState(PlayerPlaybackState.paused));
  }

  /// Resumes playback.
  Future<void> resume() async {
    _playbackRequested = true;

    final handle = _handle;

    if (handle == null || handle.disposed) {
      return;
    }

    try {
      await handle.play();

      if (!_playbackRequested || _handle != handle || handle.disposed) {
        return;
      }

      _setState(_liveState(PlayerPlaybackState.playing));
    } catch (error) {
      if (!_playbackRequested || _handle != handle || handle.disposed) {
        return;
      }

      _scheduleRecovery(
        PlayerFailure(
          code: PlayerErrorCode.backendPlayFailed,
          message: 'resume failed: $error',
          cause: error,
          context: _contextFor(_currentUrl),
        ),
        _generation,
      );
    }
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
    await _handle?.setVolume(volume.clamp(0.0, 1.0).toDouble());
  }

  /// Whether playback is restricted to the audio track.
  bool get audioOnly => _audioOnly;

  /// Restricts playback to the audio track.
  ///
  /// The preference outlives the current source: it is remembered here and
  /// re-applied whenever an adapter is bound, because recovery, line
  /// cycling and engine fallback all replay sources inside the kernel
  /// without the application being involved.
  ///
  /// Adapters that do not declare
  /// [PlayerAdapterCapabilities.supportsAudioOnly] are left untouched —
  /// their video track cannot be switched off — but the watchdog side is
  /// updated either way, so a session that expects no video never reports
  /// a frame stall.
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_audioOnly == audioOnly) {
      return;
    }

    _audioOnly = audioOnly;

    watchdogs.setVideoExpected(!audioOnly);

    final adapter = _handle?.adapter;

    if (adapter != null) {
      await _applyAudioOnly(adapter);
    }
  }

  /// Applies [audioOnly] to [adapter] when it declares the capability.
  Future<void> _applyAudioOnly(PlayerAdapter adapter) async {
    if (!adapter.capabilities.supportsAudioOnly) {
      return;
    }

    try {
      await adapter.setAudioOnly(_audioOnly);
    } catch (_) {
      // A track switch is best effort: playback itself is unaffected, and
      // the next bind re-applies the preference.
    }
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
    _watchdogRecoveryGeneration++;

    watchdogs.cancelAll();
    _cancelBackoff();

    await _eventSub?.cancel();
    _eventSub = null;

    final handle = _handle;

    _handle = null;
    _currentUrl = null;

    // Drop the capability snapshot with the handle so the next source
    // cannot inherit the previous adapter's declarations.
    watchdogs.updateCapabilities(null);

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

    if (existing != null) {
      return existing;
    }

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

    if (session == null) {
      return;
    }

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

    if (operation == null || operation.isTerminal) {
      return;
    }

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

    if (operation == null || operation.isTerminal) {
      return;
    }

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
    if (!_isCurrent(generation)) {
      return;
    }

    final request = _request;

    if (request == null) {
      return;
    }

    _currentUrl = url;

    _setState(_liveState(PlayerPlaybackState.opening));

    watchdogs.cancelAll();

    try {
      var handle = _handle;

      if (handle == null || handle.disposed) {
        handle = await kernel.create();

        if (!_isCurrent(generation)) {
          await _releaseStaleHandle(handle);
          return;
        }

        await _bindHandle(handle);
      }

      if (!_isCurrent(generation)) {
        return;
      }

      final source = _toSource(url, request);

      _ensureSession(source);
      _advanceSession(source);

      await handle.open(source);

      if (!_isCurrent(generation)) {
        return;
      }

      watchdogs.armSourceReady();

      _setState(_liveState(PlayerPlaybackState.buffering));

      _completeCurrentOperation();
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

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

  Future<void> _releaseStaleHandle(PlayerHandle handle) async {
    if (_handle == handle) {
      _handle = null;
    }

    try {
      await kernel.release(handle.id);
    } catch (_) {
      // Best-effort cleanup of a handle created for an already-retired
      // controller generation.
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

  /// Rebinds the controller to the current adapter of [handle].
  ///
  /// Three things must always move together here, because they all belong
  /// to the adapter *instance* the handle currently holds:
  ///
  /// - the watchdog capability snapshot, read from
  ///   `handle.adapter.capabilities`
  /// - the adapter event subscription, taken from
  ///   `handle.adapter.events`
  /// - the session preferences the adapter accepts as commands, today the
  ///   audio-only track switch
  ///
  /// `PlayerHandle.attachAdapter` replaces the adapter instance, so a
  /// caller that performs one without the others leaves the controller
  /// either watching a closed event stream, feeding the watchdog a stale
  /// capability set, or running a fresh engine with video on. Keep them
  /// coupled; do not lift any of them out.
  Future<void> _bindHandle(PlayerHandle handle) async {
    _handle = handle;

    await _eventSub?.cancel();

    _eventSub = null;

    watchdogs.updateCapabilities(handle.adapter.capabilities);

    watchdogs.setVideoExpected(!_audioOnly);

    _eventSub = handle.adapter.events.listen(_onAdapterEvent, onError: _onAdapterEventError);

    // A freshly created adapter starts with its video track enabled, so
    // only the audio-only preference has to be pushed onto it.
    if (_audioOnly) {
      await _applyAudioOnly(handle.adapter);
    }
  }

  void _onAdapterEvent(PlayerAdapterEvent adapterEvent) {
    final generation = _generation;

    switch (adapterEvent) {
      case PlayerAdapterPlaying():
        _setState(_liveState(PlayerPlaybackState.playing));

        watchdogs.onPlayingChanged(true, fromUserIntent: false);

        // Playback is successfully running again.
        // Reset recovery counters so a previous failure
        // streak does not affect future recovery attempts.
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

      case PlayerAdapterVideoFrameProgress():
        // Only a real decoded-frame heartbeat feeds the
        // video-frame stall watchdog.
        watchdogs.onFrameProgress();

      case PlayerAdapterVideoSizeChanged():
        // Video geometry is not decoded-frame progress.
        //
        // A size change only tells us that the video dimensions
        // changed. It does not prove that a new frame was decoded.
        break;

      case PlayerAdapterPositionChanged():
        // Position changes are playback progress only.
        // They are not proof that a video frame was decoded.
        break;

      case PlayerAdapterErrorEvent(message: final message):
        _scheduleRecovery(
          PlayerFailure(code: PlayerErrorCode.playbackFailed, message: message, context: _contextFor(_currentUrl)),
          generation,
        );

      case PlayerAdapterOpened():
        // PlayerHandle already translates the opened event
        // into the core/session event pipeline.
        break;

      case PlayerAdapterStopped():
        // Stop is controlled by the live controller itself.
        break;

      case PlayerAdapterCompleted():
        // Live playback normally does not complete naturally.
        // Recovery is driven by watchdog/error events instead.
        break;

      case PlayerAdapterDurationChanged():
        // Duration is not used by live playback recovery.
        break;

      case PlayerAdapterVideoReconfigured():
        // Video output reconfiguration does not prove frame progress.
        break;

      case PlayerAdapterHwdecChanged():
        // Decoder information is diagnostic/runtime information.
        // It does not directly trigger recovery.
        break;

      case PlayerAdapterAudioReconfigured():
        // Audio output reconfiguration does not affect the
        // video-frame watchdog.
        break;

      case PlayerAdapterAudioDeviceChanged():
        // Audio device changes do not affect live video recovery.
        break;

      case PlayerAdapterSubtitleChanged():
        // Subtitle changes are presentation information only.
        break;

      case PlayerAdapterCacheChanged():
        // Cache state is informational here.
        // Buffering recovery is driven by PlayerAdapterBuffering
        // and the buffering watchdog.
        break;

      case PlayerAdapterMetadataChanged():
        // Metadata is not part of live recovery control flow.
        break;

      case PlayerAdapterPlaylistChanged():
        // Playlist changes are not used by this live controller.
        break;

      case PlayerAdapterClientMessage():
        // Backend client messages are diagnostic information.
        break;

      case PlayerAdapterLogMessage():
        // Backend log messages are diagnostic information.
        break;

      case PlayerAdapterVolumeChanged():
        // Volume changes do not affect live recovery.
        break;

      case PlayerAdapterRateChanged():
        // Playback rate changes do not affect live recovery.
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
    if (!_isCurrent(generation) || !_playbackRequested) {
      return;
    }

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
    //
    // _sameEngineAttempts counts replays of the same source under the
    // current engine. It must NOT be reset when switching lines: a reset
    // turns the ladder into a ring (line 1 → 2 → … → N → line 1 → …) and
    // the engine-switch step below is never reached.
    if ((action == ErrorPolicyAction.retry || action == ErrorPolicyAction.recover) &&
        _currentUrl != null &&
        _sameEngineAttempts < maxSameEngineRecoveryAttempts) {
      _sameEngineAttempts++;

      await _open(generation, _currentUrl!);

      return;
    }

    // 2. Next line, driven by LineFallback.
    //
    // The previous implementation derived the next line with
    // (lineIndex + 1) % urls.length, a ring: after the last line failed,
    // it wrapped back to the first, the `urls[nextIndex] != _currentUrl`
    // guard still held, and the method returned before ever reaching the
    // engine switch. LineFallback is itself a finite-line traversal state
    // machine; let it own that state instead of computing a second one.
    if (action == ErrorPolicyAction.fallback ||
        action == ErrorPolicyAction.retry ||
        action == ErrorPolicyAction.recover) {
      _lineFallback.markFailed();

      final nextLine = _lineFallback.next();

      if (nextLine != null) {
        await _open(generation, nextLine);
        return;
      }
    }

    // 3. Engine switch.
    //
    // Reached only once LineFallback has exhausted every candidate line.
    // A new engine gets a fresh same-engine retry budget, so
    // _sameEngineAttempts is reset here (and only here on success).
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

        if (!_isCurrent(generation) || !_playbackRequested) {
          return;
        }

        _sameEngineAttempts = 0;
        _backoffAttempt = 0;

        // Backoff is the last pass: rescan the whole candidate set from
        // the first line.
        final urls = lines;

        if (urls.isEmpty) {
          return;
        }

        _lineFallback.start(urls, currentLine: urls.first);

        unawaited(_open(generation, urls.first));
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

    _watchdogRecoveryGeneration++;

    watchdogs.cancelAll();

    _setState(_liveState(PlayerPlaybackState.error));

    _session?.updateState(const SessionState.error());

    if (!_failureController.isClosed) {
      _failureController.add(failure);
    }
  }

  Future<bool> _trySwitchEngine(int generation) async {
    if (!_isCurrent(generation) || !_playbackRequested) {
      return false;
    }

    final currentBackend = backendId;

    final candidates = kernel.registry.registrations
        .where((registration) => registration.enabled && registration.id != currentBackend)
        .map((registration) => registration.id)
        .toList();

    if (candidates.isEmpty) {
      return false;
    }

    _engineFallback.start(candidates, currentBackend: currentBackend);

    while (_isCurrent(generation) && _playbackRequested) {
      final nextBackend = _engineFallback.next();

      if (nextBackend == null) {
        return false;
      }

      final registration = kernel.registry.get(nextBackend);

      if (registration == null) {
        _engineFallback.markFailed();
        continue;
      }

      final handle = _handle;

      if (handle == null || handle.disposed) {
        return false;
      }

      try {
        _watchdogRecoveryGeneration++;

        // Replace the adapter owned by the existing handle.
        await handle.attachAdapter(registration);

        if (!_isCurrent(generation) || !_playbackRequested || _handle != handle || handle.disposed) {
          return false;
        }

        // attachAdapter() replaces the adapter instance.
        //
        // The watchdog capabilities, adapter event subscription and
        // session preferences must all be rebound to the new instance.
        await _bindHandle(handle);

        if (!_isCurrent(generation) || !_playbackRequested || _handle != handle || handle.disposed) {
          return false;
        }

        final url = _currentUrl;
        final request = _request;

        if (url == null || request == null) {
          return false;
        }

        // A new engine gets its own line-fallback lifecycle.
        //
        // The current line is tried first on the new engine, followed by
        // the remaining candidates when this engine fails.
        final switchUrls = lines;

        if (switchUrls.isNotEmpty) {
          _lineFallback.start(switchUrls, currentLine: url);
        }

        final source = _toSource(url, request);

        _advanceSession(source);

        await handle.open(source);

        if (!_isCurrent(generation) || !_playbackRequested || _handle != handle || handle.disposed) {
          return false;
        }

        watchdogs.armSourceReady();

        return true;
      } catch (_) {
        if (!_isCurrent(generation) || !_playbackRequested || _handle != handle || handle.disposed) {
          return false;
        }

        // This engine failed to attach/open.
        // Let BackendFallback move to the next engine.
        _engineFallback.markFailed();
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  bool _isCurrent(int generation) {
    return generation == _generation && _request != null && _playbackRequested;
  }

  bool _isWatchdogRecoveryCurrent(int generation) {
    final handle = _handle;

    return generation == _watchdogRecoveryGeneration && _playbackRequested && handle != null && !handle.disposed;
  }

  PlayerState _liveState(PlayerPlaybackState playback) {
    return PlayerState(lifecycle: PlayerLifecycleState.ready, playback: playback, hasSource: true);
  }

  void _setState(PlayerState next) {
    if (state == next) {
      return;
    }

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
    /// Watchdogs only report inferred stalls.
    ///
    /// The controller decides which recovery ladder to enter.
    watchdogs.onStall = (kind) {
      if (!_playbackRequested) {
        return;
      }

      final generation = _generation;

      _scheduleRecovery(_failureForStall(kind), generation);
    };

    /// Watchdogs never call PlayerHandle directly.
    ///
    /// They only request a recovery action. The controller owns the
    /// asynchronous boundary and reports the result back after the
    /// PlayerHandle operation completes.
    watchdogs.onRecoveryRequested = (action) {
      if (!_playbackRequested) {
        watchdogs.reportRecoveryResult(false);
        return;
      }

      final recoveryGeneration = ++_watchdogRecoveryGeneration;
      final playbackGeneration = _generation;
      final handle = _handle;

      if (handle == null || handle.disposed) {
        watchdogs.reportRecoveryResult(false);
        return;
      }

      unawaited(_handleWatchdogRecovery(action, recoveryGeneration, playbackGeneration, handle));
    };
  }

  /// Executes a watchdog recovery action through [PlayerHandle].
  ///
  /// This is deliberately the only bridge between watchdog recovery
  /// requests and actual player operations.
  ///
  /// [PlayerHandle] performs the lifecycle/generation checks. If the
  /// source was closed, replaced, or the handle was disposed while the
  /// operation was waiting, the handle prevents the stale command from
  /// reaching the backend or committing stale playback state.
  ///
  /// The controller additionally checks its own playback generation and
  /// watchdog recovery generation after the asynchronous operation returns.
  /// This protects the watchdog result itself from becoming stale.
  Future<void> _handleWatchdogRecovery(
    LiveWatchdogRecoveryAction action,
    int recoveryGeneration,
    int playbackGeneration,
    PlayerHandle handle,
  ) async {
    try {
      if (!_isCurrent(playbackGeneration) ||
          !_isWatchdogRecoveryCurrent(recoveryGeneration) ||
          !_playbackRequested ||
          _handle != handle ||
          handle.disposed) {
        return;
      }

      switch (action) {
        case LiveWatchdogRecoveryAction.reassertPlay:
          try {
            await handle.play();
          } catch (_) {
            if (_isWatchdogRecoveryCurrent(recoveryGeneration)) {
              watchdogs.reportRecoveryResult(false);
            }

            return;
          }

          if (!_isWatchdogRecoveryCurrent(recoveryGeneration)) {
            return;
          }

          if (!_isCurrent(playbackGeneration) || !_playbackRequested || _handle != handle || handle.disposed) {
            watchdogs.reportRecoveryResult(false);
            return;
          }

          // Successful completion means PlayerHandle accepted the play
          // operation. The adapter's Playing event remains the authoritative
          // observation of actual playback state.
          watchdogs.reportRecoveryResult(true);
      }
    } catch (_) {
      if (_isWatchdogRecoveryCurrent(recoveryGeneration)) {
        watchdogs.reportRecoveryResult(false);
      }
    }
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
