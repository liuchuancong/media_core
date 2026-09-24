import 'dart:async';
import 'live_watchdogs.dart';
import '../core/player_state.dart';
import 'live_playback_models.dart';
import '../identity/player_id.dart';
import '../error/error_context.dart';
import '../identity/session_id.dart';
import '../operation/operation.dart';
import '../error/player_failure.dart';
import '../kernel/player_handle.dart';
import '../kernel/player_kernel.dart';
import '../source/source_type.dart';
import '../source/source_format.dart';
import '../source/source_protocol.dart';
import '../source/player_source.dart';
import '../identity/operation_id.dart';
import '../session/session_state.dart';
import '../source/source_headers.dart';
import '../identity/generation_id.dart';
import '../session/player_session.dart';
import '../error/player_error_code.dart';
import '../session/session_context.dart';
import '../session/session_manager.dart';
import '../operation/operation_type.dart';
import '../session/session_snapshot.dart';
import '../operation/operation_tracker.dart';
import '../adapter/player_adapter_event.dart';
import '../adapter/player_adapter_capabilities.dart';
import '../diagnostics/log_category.dart';
import '../diagnostics/media_core_log.dart';
import '../operation/operation_registry.dart';
import '../recovery/recovery_failure.dart';
import '../operation/operation_cancel_token.dart';
import '../recovery/recovery_ladder_event.dart';
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
///   user-triggered high-level action (play / retry / switch line / close)
///   plus each recovery report. This is diagnostic metadata, not control
///   flow.
///
/// ## What this class is not
///
/// It is not a recovery engine. It used to be one — a second ladder with
/// its own same-engine retries, line cycling, engine switching and
/// backoff, racing the handle's retry loop and the kernel's fallback loop
/// — and the three of them invalidated each other's operations, so one
/// fault produced a burst of adapter create/dispose cycles.
///
/// Recovery now belongs to one place, the [PlayerHandle]'s recovery
/// ladder, and this controller has exactly two responsibilities towards
/// it:
///
/// 1. **Report what only it can see.** Watchdog stalls and failed
///    playback commands are evidence the handle cannot produce itself;
///    they are handed over through [PlayerHandle.reportFailure].
/// 2. **Observe the outcome.** Line switches and staged backend swaps
///    happen inside the handle, so the controller follows
///    [PlayerHandle.sourceChanges] to learn which URL is playing, and
///    [PlayerHandle.recoveryEvents] to learn when recovery gave up and
///    the failure is terminal for the application.
///
/// Everything else is UI state and plumbing.
///
/// ## Binding across backend swaps
///
/// The controller binds to [PlayerHandle.adapterEvents], not to
/// `handle.adapter.events`. The handle replaces its adapter during a
/// backend swap, and a subscription taken from the adapter instance would
/// silently go dead at that moment. Binding to the handle keeps the
/// watchdog capability snapshot and the event stream correct for whatever
/// backend is attached; [PlayerHandle.backendChanges] signals when that
/// happened so the capabilities can be re-read.
///
/// The audio-only preference is the one session mode the controller keeps
/// on behalf of the application. It forwards it to the handle, which
/// remembers it and re-applies it to every adapter it attaches — so a
/// backend swap inside the handle cannot silently restore video.
///
/// That preference is also why the frame watchdog is disabled at the
/// session level rather than by capability: an audio-only source has no
/// video track, and whether the adapter *could* report a frame heartbeat
/// says nothing about whether one will ever arrive.
final class LivePlaybackController {
  LivePlaybackController(this.kernel, {LiveWatchdogs? watchdogs})
    : watchdogs = watchdogs ?? LiveWatchdogs(),
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

  /// Events of whichever adapter the bound handle currently holds.
  StreamSubscription<PlayerAdapterEvent>? _adapterEventSub;

  /// Backend swaps performed by the handle's recovery ladder.
  StreamSubscription<PlayerBackendChange>? _backendChangeSub;

  /// Line switches performed by the handle's recovery ladder.
  StreamSubscription<PlayerSource?>? _sourceChangeSub;

  /// Recovery decisions, observed to detect a terminal failure.
  StreamSubscription<RecoveryLadderEvent>? _recoverySub;

  int _generation = 0;
  bool _playbackRequested = false;
  bool _audioOnly = false;
  bool _disposed = false;

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

  /// Backend pinned by the caller for this playback, if any.
  ///
  /// Survives line switches and retries: an engine setting is a user
  /// preference, not a per-attempt detail. Recovery ignores it — the
  /// ladder must be free to escalate past an engine that keeps failing.
  String? _preferredBackend;

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
  ///
  /// [preferredBackend] pins the engine for this playback: a user-visible
  /// engine setting must be able to say "use better_player", and it must
  /// do so through the normal create/bind path — which is also what
  /// refreshes the watchdog capability snapshot. Switching engines behind
  /// the controller (releasing its handle externally, creating another
  /// one) leaves the controller bound to a dead handle and the watchdogs
  /// holding the previous engine's declarations.
  ///
  /// When omitted, the backend is chosen by scoring the actual source:
  /// priority plus protocol, format and live support. See
  /// [PlayerAdapterSelector.score].
  ///
  /// The pin applies when a player is created, which is the first [play]
  /// after a [close]. An engine setting that changes mid-session must
  /// therefore call [close] first — the controller cannot swap the engine
  /// under a live stream without re-opening it.
  Future<void> play(LiveSourceRequest request, {String? preferredBackend}) {
    _request = request;
    _preferredBackend = preferredBackend;
    _playbackRequested = true;

    _watchdogRecoveryGeneration++;

    final generation = ++_generation;

    _beginOperation(OperationType.open);

    MediaCoreLog.info(
      LogCategory.player,
      'live play: ${request.urls.length} line(s) starting with ${request.urls.first}',
      fields: <String, Object?>{'title': request.title, 'headers': request.headers.keys.toList()},
    );

    return _open(generation, request.urls.first);
  }

  /// Switches to line [index] of the current request.
  ///
  /// A user action, not recovery: recovery picks its own lines through the
  /// handle's ladder and reports back on [PlayerHandle.sourceChanges].
  Future<void> switchLine(int index) {
    final urls = lines;

    if (index < 0 || index >= urls.length) {
      return Future<void>.value();
    }

    _watchdogRecoveryGeneration++;

    final generation = _generation;

    _beginOperation(OperationType.load);

    MediaCoreLog.info(
      LogCategory.source,
      'user switched to line $index: ${urls[index]}',
      fields: <String, Object?>{'lines': urls.length},
    );

    return _open(generation, urls[index]);
  }

  /// Replays the current source from scratch.
  Future<void> retry() {
    final url = _currentUrl;

    if (url == null || _request == null) {
      return Future<void>.value();
    }

    _playbackRequested = true;

    _watchdogRecoveryGeneration++;

    final generation = ++_generation;

    _beginOperation(OperationType.retry);

    return _open(generation, url);
  }

  /// Pauses playback (a user intent — watchdogs stand down).
  ///
  /// The handle suspends its recovery ladder; a user pause is a recovery
  /// boundary, and this controller does not have to say so explicitly.
  Future<void> pause() async {
    _playbackRequested = false;

    _watchdogRecoveryGeneration++;

    watchdogs.cancelAll();

    _handle?.declarePlayIntent(false);

    await _handle?.pause();

    _setState(_liveState(PlayerPlaybackState.paused));
  }

  /// Resumes playback.
  Future<void> resume() async {
    _playbackRequested = true;

    final handle = _handle;

    handle?.declarePlayIntent(true);

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

      // A failed resume is evidence the stream is gone, and only this
      // controller has it. Report it; the handle's ladder decides what to
      // do — replay, switch line, switch backend or give up.
      handle.reportFailure(
        RecoveryFailure.fromMessage(
          'resume failed: $error',
          error: error,
          code: PlayerErrorCode.backendPlayFailed,
          source: RecoveryFailureSource.playback,
          uri: _currentUrl,
        ),
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
  /// The preference outlives the current source: the handle remembers it
  /// and re-applies it to whichever adapter it attaches, because recovery
  /// can replace the adapter without the application being involved. The
  /// controller keeps its own copy only to drive the watchdog side.
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

    final handle = _handle;

    if (handle != null && !handle.disposed) {
      await handle.setAudioOnly(audioOnly);
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

    await _unbindHandle();

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

    _disposed = true;

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
      final source = _sourceFor(url, request);
      var handle = _handle;

      if (handle == null || handle.disposed) {
        // Select the backend for the source we are about to open, not for
        // an unknown one. `kernel.create()` without a source asks the
        // selector to rank backends against "nothing", where every
        // capability bonus is zero and priority alone decides.
        //
        // An explicitly pinned backend wins over scoring: the caller owns
        // that choice, and recovery remains free to escalate away from it.
        final pinned = _preferredBackend;
        final selected = pinned ?? kernel.selector.select(source)?.id;

        MediaCoreLog.info(
          LogCategory.fallback,
          'live open: using backend ${selected ?? '<none>'}'
              '${pinned == null ? ' (selected by score)' : ' (pinned by the caller)'} for '
              '${source.protocol.name}/${source.format.name} '
              '${source.isLive ? 'live' : 'vod'} source',
          fields: <String, Object?>{'uri': source.uri.toString(), 'line': _lineIndexOf(request, url)},
        );

        handle = await kernel.create(preferredBackend: selected);

        if (!_isCurrent(generation)) {
          await _releaseStaleHandle(handle);
          return;
        }

        await _bindHandle(handle);
      }

      if (!_isCurrent(generation)) {
        return;
      }

      // Live playback is requested, not commanded: the engine starts as
      // soon as the source is accepted, so the handle has no play command
      // to mirror. Declaring the intent is what lets recovery resume a
      // stream instead of pausing the one it just reopened.
      handle.declarePlayIntent(_playbackRequested);

      // Hand the whole line list to the handle before opening: the
      // recovery ladder can only fall back to another line if it was told
      // which ones exist, and it must know before the first line fails.
      handle.setSourceCandidates(_sourcesFor(request));

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

      // The open failed. Report it rather than recovering here: the
      // handle's ladder reopens this URL, tries the next line, attaches
      // another backend, or decides the failure is terminal — and this
      // controller hears about the outcome through [handle.recoveryEvents].
      final failed = handle;

      if (failed != null) {
        failed.reportFailure(
          RecoveryFailure.fromMessage(
            'open failed: $error',
            error: error,
            code: PlayerErrorCode.backendOpenFailed,
            source: RecoveryFailureSource.playback,
            uri: url,
          ),
        );
      }
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

  /// Index of [url] within [request]'s line list.
  int _lineIndexOf(LiveSourceRequest request, String url) {
    final index = request.urls.indexOf(url);

    return index < 0 ? 0 : index;
  }

  /// Builds the source for [url], identifying it by its line index.
  ///
  /// The identifier is derived from the line index rather than the current
  /// playback state: recovery switches lines inside the handle, so every
  /// candidate has to be identified before it is opened, not when it
  /// becomes current.
  ///
  /// The type, protocol and format are declared here because they are what
  /// backend selection scores against. Leaving them unknown does not make
  /// selection "neutral": it makes every capability bonus worth zero, so
  /// the highest-priority backend wins even when it cannot play the
  /// stream — which is how a `.flv` stream ends up on a backend whose
  /// declared formats do not include `flv`.
  PlayerSource _sourceFor(String url, LiveSourceRequest request) {
    final headers = request.headers;
    final uri = Uri.parse(url);

    return PlayerSource(
      id: SourceId('live_${_generation}_${_lineIndexOf(request, url)}'),
      uri: uri,
      type: SourceType.live,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      headers: headers.isEmpty ? null : SourceHeaders(headers),
      title: request.title,
    );
  }

  /// Builds the recovery candidate list of [request], best line first.
  List<PlayerSource> _sourcesFor(LiveSourceRequest request) {
    return request.urls.map((url) => _sourceFor(url, request)).toList(growable: false);
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

  /// Binds the controller to [handle].
  ///
  /// Every subscription is taken from the *handle*, never from
  /// `handle.adapter`. The handle replaces its adapter instance when
  /// recovery attaches another backend, and a subscription taken from the
  /// adapter would go silently dead at that moment — the controller would
  /// keep watching a closed stream while a new backend played. Binding to
  /// the handle means the handle owns re-subscription, which is the one
  /// place that knows a swap happened.
  ///
  /// Four things move together here:
  ///
  /// - the watchdog capability snapshot, re-read on
  ///   [PlayerHandle.backendChanges]
  /// - the adapter event stream
  /// - the source stream, because recovery can switch lines
  /// - the recovery event stream, because recovery can give up
  Future<void> _bindHandle(PlayerHandle handle) async {
    _handle = handle;

    await _unbindHandle();

    _announceWatchdogCapabilities(handle.backendId, handle.adapter.capabilities);

    watchdogs.setVideoExpected(!_audioOnly);
    watchdogs.resetPositionSignal();

    _adapterEventSub = handle.adapterEvents.listen(_onAdapterEvent, onError: _onAdapterEventError);

    _backendChangeSub = handle.backendChanges.listen(_onBackendChanged);

    _sourceChangeSub = handle.sourceChanges.listen(_onSourceChanged);

    _recoverySub = handle.recoveryEvents.listen(_onRecoveryEvent);

    // A freshly created adapter starts with its video track enabled, so
    // only the audio-only preference has to be pushed onto it.
    if (_audioOnly) {
      await handle.setAudioOnly(true);
    }
  }

  /// Releases every subscription taken by [_bindHandle].
  Future<void> _unbindHandle() async {
    await _adapterEventSub?.cancel();
    _adapterEventSub = null;

    await _backendChangeSub?.cancel();
    _backendChangeSub = null;

    await _sourceChangeSub?.cancel();
    _sourceChangeSub = null;

    await _recoverySub?.cancel();
    _recoverySub = null;
  }

  /// Re-reads the watchdog capabilities after a backend swap.
  ///
  /// The capabilities belong to the adapter *instance*, so a swap makes
  /// the snapshot the watchdog bundle holds stale. Without this the frame
  /// watchdog would keep arming itself from the old engine's declarations.
  void _onBackendChanged(PlayerBackendChange change) {
    if (_disposed) {
      return;
    }

    MediaCoreLog.warning(
      LogCategory.fallback,
      'live controller observed a backend swap: ${change.from} -> ${change.to}',
      fields: <String, Object?>{'currentLine': _currentUrl},
    );

    _announceWatchdogCapabilities(change.to, change.adapter.capabilities);

    watchdogs.setVideoExpected(!_audioOnly);
    watchdogs.resetPositionSignal();
  }

  /// Hands the watchdog bundle the capabilities of [backendId]'s adapter.
  ///
  /// There is exactly one watchdog bundle per controller and it holds one
  /// capability snapshot at a time, so this call *is* the answer to "whose
  /// watchdog is running?". It happens on binding and on a backend swap,
  /// and nowhere else — if a backend changes without one of those two
  /// events, the bundle keeps the previous backend's declaration.
  void _announceWatchdogCapabilities(String backendId, PlayerAdapterCapabilities capabilities) {
    MediaCoreLog.info(
      LogCategory.recovery,
      'watchdog capabilities <- $backendId '
          '(frameProgress: ${capabilities.supportsVideoFrameProgress}, live: ${capabilities.supportsLive})',
      fields: <String, Object?>{'backend': backendId, 'audioOnly': _audioOnly},
    );

    watchdogs.updateCapabilities(capabilities);
  }

  /// Follows the source the handle is actually playing.
  ///
  /// Recovery can switch to another line on its own, so the controller
  /// cannot assume the URL it passed to `_open` is still the one playing.
  void _onSourceChanged(PlayerSource? source) {
    if (_disposed) {
      return;
    }

    final uri = source?.uri.toString();

    if (uri != _currentUrl) {
      MediaCoreLog.info(
        LogCategory.source,
        'live controller observed a source change: ${_currentUrl ?? '<none>'} -> ${uri ?? '<none>'}',
      );
    }

    _currentUrl = uri;
  }

  /// Observes recovery decisions, and reacts to the terminal one.
  ///
  /// This is the whole of the controller's recovery involvement: it does
  /// not decide, it learns. Only two events matter to it — a run starting,
  /// which is playback the application should see as buffering, and a run
  /// exhausting, which turns into a terminal [PlayerFailure] on [onError].
  void _onRecoveryEvent(RecoveryLadderEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case RecoveryLadderStarted():
        _setState(_liveState(PlayerPlaybackState.buffering));

      case RecoveryLadderCompleted():
        // The adapter's own Playing event is the authoritative signal that
        // playback resumed; nothing to do here.
        break;

      case RecoveryLadderExhausted(failure: final failure, message: final message):
        unawaited(_terminate(_failureFrom(failure, message)));

      case RecoveryLadderCancelled():
      case RecoveryLadderStepStarted():
      case RecoveryLadderStepFailed():
        break;
    }
  }

  /// Converts a ladder failure into the error model the application reads.
  PlayerFailure _failureFrom(RecoveryFailure? failure, String? message) {
    if (failure == null) {
      return PlayerFailure(
        code: PlayerErrorCode.playbackFailed,
        message: message ?? 'Live playback failed.',
        context: _contextFor(_currentUrl),
      );
    }

    return PlayerFailure(
      code: failure.code,
      message: failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
      context: _contextFor(_currentUrl),
    );
  }

  void _onAdapterEvent(PlayerAdapterEvent adapterEvent) {
    switch (adapterEvent) {
      case PlayerAdapterPlaying():
        _setState(_liveState(PlayerPlaybackState.playing));

        watchdogs.onPlayingChanged(true, fromUserIntent: false);

        // Playback is running: the handle's ladder has already reset its
        // own counters on the recovered step, so there is nothing to
        // rewind here.
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

      case PlayerAdapterPositionChanged(position: final position):
        // Position is progress, not proof of a decoded frame, so it must
        // not feed the frame watchdog. It does feed the stall detector of
        // last resort: an engine with no frame heartbeat can freeze with no
        // buffering event and no error, and a position that stops
        // advancing is the only remaining evidence.
        watchdogs.onPositionProgress(position);

      case PlayerAdapterErrorEvent():
        // The handle reports adapter errors itself, so this branch is
        // informational: the failure is already on its way to the ladder.
        // Re-reporting it here would create the second recovery path this
        // refactor removed.
        break;

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
    // A stream error is not a playback failure: the adapter's own error
    // events carry the recoverable evidence, and the handle reports those.
    // Surface it for diagnostics only.
    if (_disposed) {
      return;
    }

    _setState(_liveState(PlayerPlaybackState.error));
  }

  /// Marks playback as terminally failed and publishes the failure.
  ///
  /// Reached from two places only: the ladder reporting that it ran out of
  /// steps, and a watchdog declaring the stream unrecoverable. Both mean
  /// the same thing to the application.
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

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Whether [generation] still identifies the logical playback the
  /// controller is running.
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

  // ---------------------------------------------------------------------------
  // Watchdog wiring
  // ---------------------------------------------------------------------------

  void _wireWatchdogs() {
    /// Watchdogs only infer stalls; they do not act on them.
    ///
    /// A stall is evidence the controller has and the handle does not, so
    /// it is reported to the handle's ladder — which owns the decision of
    /// what to reopen, switch or give up on. This controller used to keep
    /// a ladder of its own here, in parallel with the handle's and the
    /// kernel's; that is what the recovery refactor removed.
    watchdogs.onStall = (kind) {
      if (!_playbackRequested || _disposed) {
        return;
      }

      final handle = _handle;

      if (handle == null || handle.disposed) {
        return;
      }

      _setState(_liveState(PlayerPlaybackState.buffering));

      MediaCoreLog.warning(
        LogCategory.recovery,
        'watchdog stall reported: ${kind.name}',
        fields: <String, Object?>{'line': _currentUrl, 'backend': handle.backendId},
      );

      handle.reportFailure(
        RecoveryFailure.fromMessage(
          'live stall: ${kind.name}',
          error: kind,
          code: _codeForStall(kind),
          source: RecoveryFailureSource.watchdog,
          uri: _currentUrl,
        ),
      );
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
  /// model. This is the only place where live-specific stall kinds enter
  /// the error pipeline.
  PlayerErrorCode _codeForStall(LiveStallKind kind) {
    return switch (kind) {
      LiveStallKind.sourceReadyTimeout => PlayerErrorCode.timeout,

      LiveStallKind.unexpectedPauseResumed => PlayerErrorCode.playbackFailed,

      LiveStallKind.unexpectedPauseResumeFailed => PlayerErrorCode.backendPlayFailed,

      LiveStallKind.unexpectedPauseTimeout => PlayerErrorCode.playbackFailed,

      LiveStallKind.bufferingStallTimeout => PlayerErrorCode.insufficientBandwidth,

      LiveStallKind.videoFrameStallTimeout => PlayerErrorCode.decoderError,

      // Not a decode failure: the engine kept decoding nothing at all, or
      // stopped pulling segments. Reported as a playback failure so the
      // ladder reopens the current line before escalating.
      LiveStallKind.positionStallTimeout => PlayerErrorCode.playbackFailed,
    };
  }
}
