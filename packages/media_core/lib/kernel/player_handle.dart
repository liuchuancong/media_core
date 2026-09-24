import 'dart:async';
import '../core/player.dart';
import 'kernel_options.dart';
import '../core/player_state.dart';
import 'package:rxdart/rxdart.dart';
import '../core/player_config.dart';
import '../event/player_event.dart';
import '../identity/player_id.dart';
import '../event/event_context.dart';
import '../identity/source_id.dart';
import '../identity/session_id.dart';
import '../event/event_priority.dart';
import '../policy/player_policy.dart';
import '../source/player_source.dart';
import '../session/session_state.dart';
import '../runtime/player_runtime.dart';
import '../adapter/player_adapter.dart';
import '../event/player_event_bus.dart';
import '../identity/generation_id.dart';
import '../session/player_session.dart';
import '../event/player_event_type.dart';
import '../playback/playback_state.dart';
import '../session/session_context.dart';
import '../recovery/recovery_step.dart';
import '../session/session_snapshot.dart';
import '../playback/playback_command.dart';
import '../recovery/recovery_budget.dart';
import '../recovery/recovery_policy.dart';
import '../recovery/recovery_target.dart';
import '../recovery/recovery_failure.dart';
import '../recovery/recovery_ladder.dart';
import '../recovery/recovery_session.dart';
import '../recovery/recovery_snapshot.dart';
import '../session/session_controller.dart';
import '../geometry/geometry_controller.dart';
import '../adapter/player_adapter_event.dart';
import '../lifecycle/lifecycle_snapshot.dart';
import '../playback/playback_controller.dart';
import '../adapter/player_adapter_context.dart';
import '../adapter/player_adapter_metrics.dart';
import '../lifecycle/lifecycle_controller.dart';
import '../platform/platform_capabilities.dart';
import '../adapter/player_adapter_registry.dart';
import '../operation/operation_cancel_token.dart';
import '../diagnostics/log_level.dart';
import '../diagnostics/log_category.dart';
import '../diagnostics/media_core_log.dart';
import '../adapter/player_adapter_capabilities.dart';
import '../recovery/recovery_ladder_event.dart';
import '../recovery/recovery_candidate_provider.dart';
import '../adapter/player_adapter_selector.dart';
import 'package:media_core/kernel/player_handle_snapshot.dart';

/// Describes the backend a handle just switched to.
///
/// Emitted on [PlayerHandle.backendChanges] when the recovery ladder
/// attaches another backend. Consumers that keep per-adapter state
/// (watchdog capability snapshots, custom overlays) re-read it from
/// [adapter] instead of holding on to the previous adapter instance,
/// which is already disposed by the time the change is published.
final class PlayerBackendChange {
  /// Creates a backend change record.
  const PlayerBackendChange({required this.from, required this.to, required this.adapter});

  /// Backend that was attached before the change.
  final String from;

  /// Backend that is attached now.
  final String to;

  /// The newly attached adapter.
  final PlayerAdapter adapter;

  @override
  String toString() => 'PlayerBackendChange($from → $to)';
}

/// Runtime facade for one logical player.
///
/// [PlayerHandle] wires the per-player modules together:
///
/// ```text
/// PlayerRuntime ──adapter events──▶ PlaybackController
///       │                        ├──▶ SessionController
///       │                        ├──▶ GeometryController
///       │                        └──▶ (adapter-scoped bindings)
///       │
///       └── PlayerHandle ────────▶ LifecycleController
///                                  RecoveryLadder
///                                  PlayerEventBus
/// ```
///
/// Responsibilities:
///
/// - forward playback commands to the runtime's adapter
/// - execute the recovery ladder's steps
/// - publish normalized events
/// - serialize backend operations
/// - protect backend operations with lifecycle generations
///
/// It does not:
///
/// - own the adapter, session or per-runtime controllers
///   (those belong to [PlayerRuntime])
/// - decide when to reopen, switch source or switch backend
///   (that belongs to [RecoveryLadder] and [RecoveryLadderPolicy])
/// - select or create adapters
///
/// Those belong to:
///
/// - PlayerRuntime
/// - RecoveryLadder
/// - PlayerAdapterSelector
/// - PlayerKernel
///
/// ## Recovery boundary
///
/// The handle is the *execution* side of recovery: it implements
/// [RecoveryTarget] and owns the [RecoveryLadder] that decides. Nothing
/// else may start a recovery — consumers report a failure through
/// [reportFailure] and observe what the ladder decided through
/// [recoveryEvents].
///
/// This is deliberate. One failure used to be handled by the handle's
/// own retry loop, the kernel's fallback loop and the live controller's
/// ladder at the same time, and each of the three invalidated the
/// others' operations, so a single fault produced a storm of adapter
/// create/dispose cycles. One decision point, many reporters.
final class PlayerHandle implements RecoveryTarget {
  /// Creates a handle. Prefer [PlayerKernel.create] over calling
  /// this directly.
  PlayerHandle({
    required Player player,
    required PlayerAdapter adapter,
    required PlayerAdapterRegistration registration,
    required PlayerAdapterContext adapterContext,
    required PlayerEventBus eventBus,
    required KernelOptions options,
    this.config = PlayerConfig.defaults,
    this.policy = const PlayerPolicy(),
    PlayerAdapterRegistry? registry,
    PlayerAdapterSelector? selector,
    RecoveryLadderPolicy? recoveryPolicy,
    RecoveryBudget? recoveryBudget,
  }) : _player = player,
       _registration = registration,
       _adapterContext = adapterContext,
       _eventBus = eventBus,
       _options = options,
       _registry = registry,
       _selector = selector,
       _budget = recoveryBudget ?? _budgetFor(options, config),
       _runtime = PlayerRuntime(
         adapter: adapter,
         session: PlayerSession(
           context: SessionContext(
             playerId: player.id,
             sessionId: adapterContext.sessionId,
             generationId: GenerationId.generate(),
             sourceId: PlayerSource.unknown().id,
             source: PlayerSource.unknown(),
             policy: policy,
             platform: const PlatformCapabilities(),
           ),
         ),
       ) {
    _ladder = RecoveryLadder(
      target: this,
      candidates: _HandleRecoveryCandidates(this),
      policy: recoveryPolicy ?? const DefaultRecoveryLadderPolicy(),
      budget: _budget,
    );

    _ladderEvents = _ladder.events.listen(_onLadderEvent);

    _subscribeAdapter(_runtime.adapter);
  }

  final Player _player;
  final PlayerAdapterContext _adapterContext;
  final PlayerEventBus _eventBus;
  final KernelOptions _options;
  final PlayerAdapterRegistry? _registry;
  final PlayerAdapterSelector? _selector;
  final RecoveryBudget _budget;

  final PlayerRuntime _runtime;

  PlayerAdapterRegistration _registration;
  PlayerSource? _currentSource;

  final LifecycleController _lifecycle = LifecycleController();

  /// The single decision point for recovery on this player.
  late final RecoveryLadder _ladder;

  late final StreamSubscription<RecoveryLadderEvent> _ladderEvents;

  final StreamController<PlayerBackendChange> _backendChanges = StreamController<PlayerBackendChange>.broadcast();
  final StreamController<PlayerSource?> _sourceChanges = StreamController<PlayerSource?>.broadcast();

  /// Adapter events of whichever adapter is currently attached.
  ///
  /// Broadcast, so several consumers can listen, and — unlike
  /// `adapter.events` — stable across backend swaps: a listener stays
  /// bound to this handle and therefore keeps receiving events after
  /// recovery swapped the backend underneath it.
  final StreamController<PlayerAdapterEvent> _adapterEvents = StreamController<PlayerAdapterEvent>.broadcast();

  /// Alternative sources the caller allows recovery to fall back to.
  ///
  /// Set through [setSourceCandidates]: the handle cannot know that a
  /// live stream carries several lines unless the caller says so.
  List<PlayerSource> _sourceCandidates = const <PlayerSource>[];

  StreamSubscription<PlayerAdapterEvent>? _adapterSubscription;

  bool _disposed = false;

  /// The caller's play intent, once it has declared one.
  ///
  /// Behaviour after a recovery step is decided by what the *caller* wants,
  /// not by what the adapter last reported. The two disagree in practice:
  /// an engine that autoplays (ExoPlayer on a live stream, mpv with a
  /// stream that starts on its own) never emits a `Playing` event until
  /// something asks it to play, so the playback mirror reads "paused"
  /// while video is on screen. Restoring from that mirror paused the
  /// stream after every recovery.
  ///
  /// `null` means the caller never declared an intent, in which case the
  /// playback mirror is the best available answer.
  bool? _playIntent;

  /// Track preference applied to whichever adapter is attached.
  ///
  /// Preserved by the handle for the same reason volume and rate are:
  /// recovery can replace the adapter without the owner of the
  /// preference being involved, and a freshly attached engine would
  /// otherwise come back with video enabled.
  bool _audioOnly = false;

  /// Whether the currently attached adapter has an opened source.
  ///
  /// This is deliberately maintained by [PlayerHandle] instead of
  /// relying only on `PlayerAdapter.initialized`. An initialized
  /// adapter may have already been closed and therefore must not
  /// receive playback commands.
  bool _backendReady = false;

  /// Monotonically increasing lifecycle generation owned by this handle.
  ///
  /// Every destructive lifecycle transition invalidates older
  /// operations. See the class comment for the full description.
  int _operationGeneration = 0;

  /// Serializes all backend operations owned by this handle.
  ///
  /// Cancellation of a Dart [Future] cannot forcibly interrupt a native
  /// player call. Serializing operations ensures backend mutations
  /// happen in a deterministic order, while [_operationGeneration]
  /// prevents stale operations from committing state after a newer
  /// lifecycle transition.
  Future<void> _operation = Future<void>.value();

  /// Cancellation token for the currently active recovery/playback
  /// continuation.
  ///
  /// Lifecycle operations such as open/close use the operation
  /// generation instead of sharing this token. This prevents
  /// pause/stop from accidentally cancelling a source-opening
  /// lifecycle operation.
  OperationCancelToken? _activeCancelToken;

  /// Player configuration applied to this handle.
  final PlayerConfig config;

  /// Player policy applied to this handle.
  final PlayerPolicy policy;

  /// Volume queued by a caller before the source was ready.
  ///
  /// `setVolume` used to require an open source and throw otherwise.
  /// That contract is wrong for callers that legitimately race the
  /// source-open (engine switches, autoplay paths): they would fail
  /// the whole switch with a `StateError` even though the adapter was
  /// still opening. The value is now remembered here and applied at
  /// the end of [open], after the adapter has accepted the source.
  double? _pendingVolume;

  /// Playback rate queued by a caller before the source was ready.
  ///
  /// See [_pendingVolume].
  double? _pendingRate;

  // ---------------------------------------------------------------------------
  // Identity and state
  // ---------------------------------------------------------------------------

  /// The logical player identity.
  Player get player => _player;

  /// Identifier of this player.
  PlayerId get id => _player.id;

  /// Current session identifier.
  SessionId get sessionId => _runtime.session.context.sessionId;

  /// Current playback generation identifier.
  GenerationId get generationId => _runtime.session.generation.id;

  /// Identifier of the backend currently attached.
  String get backendId => _registration.id;

  /// Capabilities of the attached backend.
  PlayerAdapterCapabilities get backendCapabilities => _registration.capabilities;

  /// The attached adapter.
  PlayerAdapter get adapter => _runtime.adapter;

  /// Semantic state reported by the adapter.
  PlayerState get state => _runtime.adapter.state;

  /// Metrics reported by the adapter.
  PlayerAdapterMetrics get metrics => _runtime.adapter.metrics;

  /// Currently open source, if any.
  PlayerSource? get source => _currentSource;

  /// Current playback state.
  PlaybackState get playback => _runtime.playback.current;

  /// Playback state stream.
  ValueStream<PlaybackState> get playbackStream => _runtime.playback.state;

  /// Session snapshots stream.
  Stream<SessionSnapshot> get snapshots => _runtime.session.snapshots;

  /// Latest session snapshot.
  SessionSnapshot get snapshot => _runtime.session.snapshot;

  /// A transient aggregate snapshot of this handle.
  ///
  /// Aggregates the handle's own modules (lifecycle, recovery) and the
  /// runtime's controllers (session, playback, geometry) into a single
  /// immutable view. Constructed on every access; nothing is cached.
  PlayerHandleSnapshot get combinedSnapshot => PlayerHandleSnapshot(
    playerId: _player.id,
    sessionId: _runtime.session.context.sessionId,
    generationId: _runtime.session.generation.id,
    backendId: _registration.id,
    source: _currentSource,
    session: _runtime.session.snapshot,
    playback: _runtime.playback.snapshot,
    geometry: _runtime.geometry.snapshot,
    lifecycle: _lifecycle.snapshot,
    recovery: _ladder.snapshot,
    disposed: _disposed,
  );

  /// Lifecycle snapshot.
  LifecycleSnapshot get lifecycle => _lifecycle.snapshot;

  /// Recovery snapshot.
  ///
  /// Diagnostic view of the ladder: what it is working on, how far it
  /// got, and whether it gave up. Decisions are not driven from here.
  RecoverySnapshot get recovery => _ladder.snapshot;

  /// Whether this handle has been disposed.
  bool get disposed => _disposed;

  /// The player session owned by the runtime.
  PlayerSession get session => _runtime.session;

  /// The session controller owned by the runtime.
  SessionController get sessionController => _runtime.sessionController;

  /// The playback controller owned by the runtime.
  PlaybackController get playbackController => _runtime.playback;

  /// The geometry controller owned by the runtime.
  GeometryController get geometryController => _runtime.geometry;

  /// The lifecycle controller owned by this handle.
  LifecycleController get lifecycleController => _lifecycle;

  /// The recovery ladder owned by this handle.
  ///
  /// Exposed for diagnostics and for tests that want to await
  /// [RecoveryLadder.settled]. Recovery is driven by reporting failures
  /// through [reportFailure], not by calling the ladder directly.
  RecoveryLadder get recoveryLadder => _ladder;

  /// The runtime composition root owned by this handle.
  PlayerRuntime get runtime => _runtime;

  // ---------------------------------------------------------------------------
  // Recovery boundary
  // ---------------------------------------------------------------------------

  /// Decision events of the recovery ladder.
  ///
  /// The observability contract of recovery: one event per rung the
  /// ladder climbs, plus a terminal event. A consumer that needs to know
  /// whether recovery gave up subscribes here.
  Stream<RecoveryLadderEvent> get recoveryEvents => _ladder.events;

  /// Adapter events of the currently attached adapter.
  ///
  /// Stays valid across backend swaps, unlike `adapter.events`.
  Stream<PlayerAdapterEvent> get adapterEvents => _adapterEvents.stream;

  /// Emitted whenever a different backend is attached.
  Stream<PlayerBackendChange> get backendChanges => _backendChanges.stream;

  /// Emitted whenever the open source changes.
  ///
  /// A recovery step that switches to another line changes the source
  /// without the caller asking, so callers that display or reference the
  /// current source must follow this stream instead of remembering what
  /// they passed to [open].
  Stream<PlayerSource?> get sourceChanges => _sourceChanges.stream;

  /// Failure the ladder is currently working on, if any.
  RecoveryFailure? get recoveryFailure => _ladder.failure;

  /// Decision context of the current recovery, if any.
  RecoverySession? get recoverySession => _ladder.session;

  /// Budget the ladder runs with.
  RecoveryBudget get recoveryBudget => _budget;

  /// Whether playback is restricted to the audio track.
  bool get audioOnly => _audioOnly;

  /// Declares the alternative sources recovery may fall back to.
  ///
  /// The caller owns this list — for live playback it is the line list of
  /// the current request. Passing an empty list disables the next-line
  /// rung, which is the correct behaviour for a single-URL source.
  void setSourceCandidates(List<PlayerSource> candidates) {
    _sourceCandidates = List<PlayerSource>.unmodifiable(candidates);
  }

  /// Declares whether the caller wants playback running.
  ///
  /// Recovery honours this value when it restores the session after a
  /// step: `true` resumes playback, `false` leaves it paused. Declaring
  /// an intent is not the same as commanding playback — [play] and
  /// [pause] both declare their intent as a side effect, but a caller
  /// whose engine autoplays (a live stream that starts as soon as it is
  /// opened) must declare it explicitly, because nothing else in the
  /// framework knows the stream is meant to be running.
  ///
  /// Pass `null` to stop declaring, falling back to the observed
  /// playback state.
  void declarePlayIntent(bool? playing) {
    _playIntent = playing;
  }

  /// The declared play intent, if any.
  bool? get playIntent => _playIntent;

  /// Restricts playback to the audio track on whichever adapter is
  /// attached.
  ///
  /// Remembered by the handle, not by the caller: the ladder can attach
  /// another adapter without the caller being involved, and a fresh
  /// engine must not silently restore video. Applied again by [open] and
  /// after every backend swap.
  Future<void> setAudioOnly(bool audioOnly) {
    _ensureNotDisposed();

    _audioOnly = audioOnly;

    return _applyAudioOnly(_runtime.adapter);
  }

  /// Reports a failure for recovery.
  ///
  /// This is the only entry point into recovery. Returns `true` when the
  /// ladder accepted the report — a run started, or it was already
  /// escalating and the report was folded into it. Returns `false` when
  /// the ladder refused it (already running, suspended, or out of
  /// budget), which is not an error: a second recovery for a failure
  /// that is already being recovered is exactly the duplicate work this
  /// design removes.
  bool reportFailure(RecoveryFailure failure, {RecoveryFailureSource source = RecoveryFailureSource.unknown}) {
    _ensureNotDisposed();

    final report = failure
        .copyWith(source: failure.source == RecoveryFailureSource.unknown ? source : failure.source)
        .enriched(
          sourceId: _currentSource?.id,
          backendId: _registration.id,
          generationId: _runtime.session.generation.id,
          uri: _currentSource?.uri.toString(),
        );

    final accepted = _ladder.report(report);

    MediaCoreLog.log(
      accepted ? LogLevel.info : LogLevel.debug,
      LogCategory.recovery,
      'failure reported by ${report.source.name}: ${report.code.value} '
          '(${report.effectiveReason})${accepted ? ' -> recovery started' : ' -> no recovery (see preceding reason)'}',
      fields: <String, Object?>{
        'message': report.message,
        'backend': report.backendId,
        'uri': report.uri,
        'stableKey': report.stableKey,
        'accepted': accepted,
      },
    );

    _publish(PlayerEventType.recovery, <String, Object?>{
      'action': accepted ? 'reported' : 'ignored',
      'code': report.code.value,
      'reason': report.effectiveReason.toString(),
      'reporter': report.source.name,
      'stableKey': report.stableKey,
    });

    return accepted;
  }

  // ---------------------------------------------------------------------------
  // Operation lifecycle
  // ---------------------------------------------------------------------------

  /// Invalidates all currently running and queued lifecycle operations.
  ///
  /// This does not attempt to cancel an already running native Future.
  /// Instead, it makes the operation stale so it cannot commit any
  /// state or continue with a follow-up backend command after it
  /// returns.
  int _invalidateOperations() {
    final generation = ++_operationGeneration;

    _cancelActiveOperation(StateError('Player operation superseded by lifecycle generation $generation.'));

    return generation;
  }

  /// Cancels the currently active playback/recovery continuation.
  void _cancelActiveOperation([Object? reason]) {
    final token = _activeCancelToken;

    if (token == null) {
      return;
    }

    _activeCancelToken = null;

    token.cancel(reason ?? StateError('Player operation was cancelled.'));
    token.dispose();
  }

  /// Creates a new cancellation token for a playback/recovery operation.
  OperationCancelToken _createOperationToken() {
    _cancelActiveOperation(StateError('Previous player continuation was superseded.'));

    final token = OperationCancelToken();
    _activeCancelToken = token;

    return token;
  }

  /// Releases an operation token if it is still active.
  void _releaseOperationToken(OperationCancelToken token) {
    if (identical(_activeCancelToken, token)) {
      _activeCancelToken = null;
    }

    token.dispose();
  }

  /// Returns whether [generation] is still the current lifecycle generation.
  bool _isOperationCurrent(int generation) {
    return !_disposed && generation == _operationGeneration;
  }

  /// Returns whether an operation still owns [source].
  bool _isSourceCurrent(PlayerSource source) {
    return !_disposed && _currentSource?.id == source.id;
  }

  /// Returns whether an operation still owns [sourceId].
  bool _isSourceIdCurrent(Object sourceId) {
    return !_disposed && _currentSource?.id == sourceId;
  }

  /// Captures the current operation generation.
  int _captureOperationGeneration() {
    _ensureNotDisposed();
    return _operationGeneration;
  }

  /// Runs [action] after all previously queued operations complete.
  ///
  /// Errors are preserved for the caller while the internal queue
  /// remains usable for subsequent operations.
  Future<T> _enqueue<T>(Future<T> Function() action, {bool allowDisposed = false}) {
    final next = _operation.then<T>((_) async {
      if (!allowDisposed) {
        _ensureNotDisposed();
      }

      return action();
    });

    _operation = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});

    return next;
  }

  /// Waits until all currently queued backend operations have settled.
  Future<void> _drainOperations() async {
    try {
      await _operation;
    } catch (_) {
      // The queue itself already preserves later operations.
    }
  }

  /// Ensures the handle is still alive.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PlayerHandle for ${_player.id} has been disposed.');
    }
  }

  /// Ensures a source is currently open.
  void _ensureSource() {
    if (_currentSource == null || !_backendReady) {
      throw StateError('PlayerHandle for ${_player.id} has no open source.');
    }
  }

  /// Ensures the backend is currently ready for playback commands.
  bool _canUseBackend({required int operationGeneration, PlayerSource? source}) {
    if (!_isOperationCurrent(operationGeneration)) {
      return false;
    }

    if (!_backendReady) {
      return false;
    }

    if (source != null && !_isSourceCurrent(source)) {
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Adapter subscription
  // ---------------------------------------------------------------------------

  /// Subscribes to one adapter and rejects events from an adapter that
  /// is no longer active.
  ///
  /// This subscription coexists with the two bindings inside
  /// [PlayerRuntime]: the adapter's event stream is broadcast, so all
  /// three consumers receive events independently. This subscription
  /// handles only handle-level concerns — session transitions,
  /// recovery, event bus publication and completion. The bindings
  /// handle playback and geometry state.
  ///
  /// It also feeds [adapterEvents], which is how consumers survive a
  /// backend swap: they listen to the handle once, and the handle is the
  /// only place that re-subscribes when the adapter instance is
  /// replaced.
  void _subscribeAdapter(PlayerAdapter adapter) {
    _adapterSubscription = adapter.events.listen((event) {
      if (_disposed || !identical(adapter, _runtime.adapter)) {
        return;
      }

      if (!_adapterEvents.isClosed) {
        _adapterEvents.add(event);
      }

      _onAdapterEvent(event);
    }, onError: (_) {});
  }

  /// Replaces the active adapter and moves the handle's own subscription
  /// to it.
  ///
  /// The runtime swaps its bindings; this covers the handle's
  /// subscription, the registration record and the consumers of
  /// [adapterEvents] and [backendChanges].
  Future<void> _installAdapter(PlayerAdapter next, PlayerAdapterRegistration registration) async {
    final previous = _runtime.adapter;
    final previousSubscription = _adapterSubscription;

    _adapterSubscription = null;
    _registration = registration;

    // Detach the handle's listener before the runtime drops its
    // bindings, so no event from the outgoing adapter reaches a
    // half-swapped runtime.
    await previousSubscription?.cancel();

    await _runtime.replaceAdapter(next);

    _subscribeAdapter(next);

    if (!_backendChanges.isClosed) {
      _backendChanges.add(PlayerBackendChange(from: previous.id, to: registration.id, adapter: next));
    }
  }

  /// Applies the audio-only preference to [adapter] when it declares
  /// the capability.
  ///
  /// Best effort: a track switch that fails does not invalidate the
  /// playback that is already running, and the next open or swap applies
  /// the preference again.
  Future<void> _applyAudioOnly(PlayerAdapter adapter) async {
    if (!adapter.capabilities.supportsAudioOnly) {
      return;
    }

    try {
      await adapter.setAudioOnly(_audioOnly);
    } catch (_) {
      // See above: the preference is re-applied on the next open/swap.
    }
  }

  /// Publishes the source the handle is now playing.
  void _announceSource(PlayerSource? source) {
    if (_sourceChanges.isClosed) {
      return;
    }

    _sourceChanges.add(source);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the adapter and lifecycle.
  ///
  /// Called by the kernel after construction.
  Future<void> initialize() {
    return _enqueue(() async {
      await _runtime.adapter.initialize(_adapterContext);

      if (_disposed) {
        return;
      }

      _lifecycle.create();
      _lifecycle.initialize();

      _publish(PlayerEventType.player, const <String, Object?>{'action': 'initialized'});
    });
  }

  /// Opens [source] on the adapter.
  Future<void> open(PlayerSource source, {bool? autoPlay}) {
    _ensureNotDisposed();

    final operationGeneration = _invalidateOperations();

    final sourceChanged = _currentSource?.id != source.id;

    _currentSource = source;
    _backendReady = false;

    if (sourceChanged) {
      _announceSource(source);
    }

    return _enqueue(() async {
      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        return;
      }

      // A new source is a new recovery story: whatever the ladder was
      // doing for the previous one is stale. This is also what makes the
      // ladder safe to leave running — every lifecycle boundary resets it
      // instead of racing it.
      _ladder.reset();

      final generationId = _runtime.sessionController.recreateGeneration();

      _runtime.session.updateContext(
        SessionContext(
          playerId: _player.id,
          sessionId: _runtime.session.context.sessionId,
          generationId: generationId,
          sourceId: source.id,
          source: source,
          policy: policy,
          platform: _runtime.session.context.platform,
        ),
      );

      await _runtime.sessionController.open();

      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        return;
      }

      // The ladder was already reset before the session generation was
      // recreated, so it cannot be mid-step here.
      _ladder.resume();

      try {
        await _runtime.adapter.open(source);
      } catch (_) {
        if (_isOperationCurrent(operationGeneration) && _isSourceCurrent(source)) {
          _backendReady = false;
        }

        rethrow;
      }

      if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
        try {
          await _runtime.adapter.close();
        } catch (_) {
          // Best-effort cleanup of the stale open.
        }

        _backendReady = false;
        return;
      }

      _backendReady = true;

      if (config.volume != 1.0) {
        await _runtime.adapter.setVolume(config.volume);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _runtime.adapter.close();
          } catch (_) {}

          return;
        }
      }

      if (config.playbackRate != 1.0) {
        await _runtime.adapter.setRate(config.playbackRate);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _runtime.adapter.close();
          } catch (_) {}

          return;
        }
      }

      // ---------------------------------------------------------------------
      // Apply any volume / rate the caller queued while this source was
      // still opening. The queued value is an explicit user choice and
      // therefore wins over the config defaults applied above.
      //
      // This is what lets `setVolume` be safely called right after
      // `play()` returned, before the adapter had actually accepted the
      // source. Previously that path threw a `StateError` and tore down
      // the whole engine switch.
      // ---------------------------------------------------------------------
      final queuedVolume = _pendingVolume;
      if (queuedVolume != null && queuedVolume != config.volume) {
        await _runtime.adapter.setVolume(queuedVolume);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _runtime.adapter.close();
          } catch (_) {}

          return;
        }
      }
      _pendingVolume = null;

      final queuedRate = _pendingRate;
      if (queuedRate != null && queuedRate != config.playbackRate) {
        await _runtime.adapter.setRate(queuedRate);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _runtime.adapter.close();
          } catch (_) {}

          return;
        }
      }
      _pendingRate = null;

      // A fresh adapter starts with video enabled; re-assert the track
      // preference so a recovering engine cannot turn video back on.
      await _applyAudioOnly(_runtime.adapter);

      if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
        _backendReady = false;
        return;
      }

      MediaCoreLog.info(
        LogCategory.source,
        'opened ${source.uri} on ${_registration.id}',
        fields: <String, Object?>{
          'player': _player.id.value,
          'protocol': source.protocol.name,
          'format': source.format.name,
          'live': source.isLive,
          'volume': config.volume,
          'rate': config.playbackRate,
        },
      );

      _publish(PlayerEventType.source, <String, Object?>{
        'action': 'opened',
        'uri': source.uri.toString(),
        'backend': _registration.id,
      });

      if (autoPlay ?? config.autoPlay) {
        final token = _createOperationToken();

        try {
          await _playInternal(operationGeneration, token: token, source: source);
        } finally {
          _releaseOperationToken(token);
        }
      }
    });
  }

  /// Starts playback.
  Future<void> play() {
    _ensureNotDisposed();
    _ensureSource();

    _playIntent = true;

    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
        // An explicit play is a fresh recovery opportunity: it cancels a
        // previous suspend (see [pause]).
        _ladder.resume();

        await _playInternal(operationGeneration, token: token, source: source);
      } finally {
        _releaseOperationToken(token);
      }
    });
  }

  Future<void> _playInternal(
    int operationGeneration, {
    required OperationCancelToken token,
    PlayerSource? source,
  }) async {
    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _runtime.adapter.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _runtime.playback.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _runtime.sessionController.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    _lifecycle.activate();

    _publish(PlayerEventType.playback, const <String, Object?>{'action': 'play'});
  }

  /// Pauses playback.
  Future<void> pause() {
    _ensureNotDisposed();
    _ensureSource();

    final source = _currentSource!;

    _playIntent = false;

    // A user pause is a recovery boundary: recovery for playback the user
    // just stopped is stale by definition.
    _ladder.suspend();
    _cancelActiveOperation(StateError('Playback pause requested.'));

    return _enqueue(() async {
      if (_disposed) return;
      if (!_isSourceCurrent(source)) return;
      if (!_backendReady) return;

      await _runtime.adapter.pause();

      if (_disposed || !_isSourceCurrent(source)) return;

      await _runtime.playback.pause();

      if (_disposed || !_isSourceCurrent(source)) return;

      await _runtime.sessionController.pause();

      if (_disposed || !_isSourceCurrent(source)) return;

      _lifecycle.pause();

      _publish(PlayerEventType.playback, const <String, Object?>{'action': 'pause'});
    });
  }

  /// Stops playback and clears the session state.
  Future<void> stop() {
    _ensureNotDisposed();

    if (_currentSource == null) {
      return Future<void>.value();
    }

    final source = _currentSource;

    _playIntent = false;

    _ladder.suspend();
    _cancelActiveOperation(StateError('Playback stop requested.'));

    return _enqueue(() async {
      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;
      if (!_backendReady) return;

      await _runtime.adapter.stop();

      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;

      await _runtime.playback.stop();

      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;

      await _runtime.sessionController.stop();

      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;

      _publish(PlayerEventType.playback, const <String, Object?>{'action': 'stop'});
    });
  }

  /// Seeks to [position].
  Future<void> seek(Duration position) {
    _ensureNotDisposed();
    _ensureSource();

    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _runtime.adapter.seek(position));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _runtime.playback.seek(position));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _publish(PlayerEventType.playback, <String, Object?>{'action': 'seek', 'positionMs': position.inMilliseconds});
      } finally {
        _releaseOperationToken(token);
      }
    });
  }

  /// Sets the volume in the 0.0–1.0 range.
  ///
  /// This method may be called before the source has finished opening
  /// (for example by an engine switch that calls it right after
  /// `play()` returned). In that case the value is queued and applied
  /// by [open] once the adapter has accepted the source. It never
  /// throws merely because the source is not yet ready.
  Future<void> setVolume(double volume) {
    _ensureNotDisposed();

    final clamped = volume.clamp(0.0, 1.0);

    // No source open yet: remember the value and let [open] apply it.
    // The playback controller is updated immediately so consumers that
    // read `playback.volume` (fallback re-attachment, snapshots) see the
    // correct value even before the adapter accepts it.
    if (_currentSource == null || !_backendReady) {
      _pendingVolume = clamped;
      _runtime.playback.apply(PlaybackCommand.volume(clamped));
      return Future<void>.value();
    }

    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _runtime.adapter.setVolume(clamped));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _runtime.playback.apply(PlaybackCommand.volume(clamped));
        _pendingVolume = null;

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _publish(PlayerEventType.audio, <String, Object?>{'action': 'volume', 'volume': clamped});
      } finally {
        _releaseOperationToken(token);
      }
    });
  }

  /// Sets the playback rate.
  ///
  /// Mirrors [setVolume]: a rate set before the source is open is
  /// queued and applied by [open].
  Future<void> setRate(double rate) {
    _ensureNotDisposed();

    if (_currentSource == null || !_backendReady) {
      _pendingRate = rate;
      _runtime.playback.apply(PlaybackCommand.rate(rate));
      return Future<void>.value();
    }

    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _runtime.adapter.setRate(rate));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _runtime.playback.apply(PlaybackCommand.rate(rate));
        _pendingRate = null;

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _publish(PlayerEventType.playback, <String, Object?>{'action': 'rate', 'rate': rate});
      } finally {
        _releaseOperationToken(token);
      }
    });
  }

  /// Closes the current source without disposing the player.
  Future<void> close() {
    _ensureNotDisposed();

    _invalidateOperations();

    _currentSource = null;
    _backendReady = false;
    _playIntent = false;
    _ladder.reset();
    _announceSource(null);

    _cancelActiveOperation(StateError('Player close requested.'));

    return _enqueue(() async {
      if (_disposed) return;

      try {
        await _runtime.adapter.close();
      } catch (_) {
        // Closing an already released backend is harmless here.
      }

      _backendReady = false;

      if (_disposed) return;

      await _runtime.playback.stop();

      if (_disposed) return;

      await _runtime.sessionController.stop();

      if (_disposed) return;

      _publish(PlayerEventType.playback, const <String, Object?>{'action': 'stop'});
    });
  }

  /// Marks the player active. Paired with [deactivate].
  void activate() {
    _ensureNotDisposed();
    _lifecycle.activate();
  }

  /// Deactivates the player and pauses playback when active.
  Future<void> deactivate() {
    _ensureNotDisposed();

    if (!_runtime.playback.current.isPlaying) {
      _lifecycle.pause();

      _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});

      return Future<void>.value();
    }

    final source = _currentSource;

    _playIntent = false;

    _ladder.suspend();
    _cancelActiveOperation(StateError('Player deactivation requested.'));

    return _enqueue(() async {
      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;

      if (!_backendReady) {
        _lifecycle.pause();

        _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});

        return;
      }

      try {
        await _runtime.adapter.pause();

        if (_disposed) return;
        if (source != null && !_isSourceCurrent(source)) return;

        await _runtime.playback.pause();

        if (_disposed) return;
        if (source != null && !_isSourceCurrent(source)) return;

        await _runtime.sessionController.pause();
      } catch (_) {
        // Backend may already be releasing; deactivation continues.
      }

      if (_disposed) return;
      if (source != null && !_isSourceCurrent(source)) return;

      _lifecycle.pause();

      _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});
    });
  }

  /// Resets this handle for pool reuse.
  Future<void> recycle() {
    _ensureNotDisposed();

    _invalidateOperations();

    _currentSource = null;
    _backendReady = false;
    _playIntent = false;
    _ladder.reset();
    _announceSource(null);

    return _enqueue(() async {
      if (_disposed) return;

      try {
        await _runtime.adapter.close();
      } catch (_) {
        // Recycling must not fail on a broken backend.
      }

      _backendReady = false;

      if (_disposed) return;

      _runtime.sessionController.recreateGeneration();
      _runtime.session.updateState(const SessionState.idle());

      await _runtime.playback.stop();

      if (_disposed) return;

      _lifecycle.pause();
    });
  }

  /// Releases all resources owned by this handle.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _operationGeneration++;

    _currentSource = null;
    _backendReady = false;
    _playIntent = null;

    MediaCoreLog.debug(
      LogCategory.player,
      'disposing player ${_player.id.value} (backend ${_registration.id})',
    );

    _cancelActiveOperation(StateError('PlayerHandle for ${_player.id} is being disposed.'));

    _ladder.suspend();

    // Stop handle-level adapter events first, then tear down the
    // runtime (which detaches its own bindings).
    await _adapterSubscription?.cancel();
    _adapterSubscription = null;

    _lifecycle.detach();

    await _enqueue(() async {
      // Runtime owns the adapter, session controller, playback
      // controller, geometry controller and both bindings.
      try {
        await _runtime.dispose();
      } catch (_) {
        // Disposal continues even when the backend refuses.
      }

      // Handle-scoped modules.
      await _ladderEvents.cancel();
      await _ladder.dispose();
      await _backendChanges.close();
      await _sourceChanges.close();
      await _adapterEvents.close();

      _lifecycle.dispose();
    }, allowDisposed: true);

    await _drainOperations();
  }

  // ---------------------------------------------------------------------------
  // Recovery execution (RecoveryTarget)
  //
  // The ladder decides; this section performs. Every physical recovery
  // operation in the framework goes through one of these two methods, so
  // there is exactly one place where a backend is reopened or replaced.
  // ---------------------------------------------------------------------------

  @override
  bool get isRecoveryAvailable {
    return !_disposed && _currentSource != null;
  }

  @override
  Stream<RecoveryTargetEvent> get executionEvents => _targetEvents.stream;

  final StreamController<RecoveryTargetEvent> _targetEvents = StreamController<RecoveryTargetEvent>.broadcast();

  @override
  RecoverySession buildRecoverySession(RecoveryFailure failure, RecoveryCandidates candidates) {
    final current = _runtime.playback.current;

    return RecoverySession(
      failure: failure,
      source: _currentSource,
      sourceCandidates: candidates.sources,
      backendCandidates: candidates.backends,
      position: current.position,
      // The caller's intent wins over the adapter mirror. See [_playIntent].
      wasPlaying: _playIntent ?? current.isPlaying,
      volume: current.volume,
      rate: current.rate,
      backendId: _registration.id,
      generationId: _runtime.session.generation.id,
      attempt: _ladder.attempt,
    );
  }

  @override
  Future<void> reopenForRecovery(RecoveryStep step, RecoverySession session) {
    _ensureNotDisposed();

    final source = step.source ?? session.source ?? _currentSource;

    if (source == null) {
      throw StateError('Recovery step ${step.label} has no source to open.');
    }

    return _reopenOnCurrentBackend(step, source, session);
  }

  @override
  Future<void> swapToForRecovery(RecoveryStep step, RecoverySession session) {
    _ensureNotDisposed();

    final backendId = step.backendId;

    if (backendId == null) {
      throw StateError('Recovery step ${step.label} names no backend.');
    }

    final registration = _registry?.get(backendId);

    if (registration == null) {
      throw StateError('Backend "$backendId" is no longer registered.');
    }

    return _swapTo(step, registration, session);
  }

  /// Reopens a source on the currently attached backend.
  ///
  /// Serves both [RecoveryStepKind.sameBackendReopen] and
  /// [RecoveryStepKind.nextLine]: the only difference is which source is
  /// opened. A different source advances the session generation, because
  /// a generation identifies one source lifecycle.
  Future<void> _reopenOnCurrentBackend(RecoveryStep step, PlayerSource source, RecoverySession session) {
    final operationGeneration = _invalidateOperations();
    final changedSource = _currentSource?.id != source.id;

    _currentSource = source;
    _backendReady = false;

    if (changedSource) {
      final generationId = _runtime.sessionController.recreateGeneration();

      _runtime.session.updateContext(
        SessionContext(
          playerId: _player.id,
          sessionId: _runtime.session.context.sessionId,
          generationId: generationId,
          sourceId: source.id,
          source: source,
          policy: policy,
          platform: _runtime.session.context.platform,
        ),
      );

      _announceSource(source);
    }

    return _enqueue(() async {
      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        throw StateError('Recovery reopen of ${source.uri} was superseded.');
      }

      _emitTargetEvent(RecoveryTargetEventKind.stepStarted, step, sourceId: source.id);

      MediaCoreLog.info(
        LogCategory.recovery,
        'reopen on ${_registration.id}: ${source.uri}'
            '${changedSource ? ' (new source)' : ' (same source)'}',
        fields: <String, Object?>{
          'step': step.label,
          'wasPlaying': session.wasPlaying,
          'positionMs': session.position.inMilliseconds,
        },
      );

      try {
        // A reopen starts from a clean backend: closing first is what
        // makes this a recovery rather than a second open on a backend
        // that is still holding the broken stream.
        try {
          await _runtime.adapter.close();
        } catch (_) {
          // Releasing an already released backend is not a reason to abort.
        }

        _backendReady = false;

        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          throw StateError('Recovery reopen of ${source.uri} was superseded.');
        }

        await _runtime.sessionController.open();
        await _runtime.adapter.open(source);

        _backendReady = true;

        await _restoreSession(session, source: source);
        await _applyAudioOnly(_runtime.adapter);

        _emitTargetEvent(
          RecoveryTargetEventKind.stepSucceeded,
          step,
          sourceId: source.id,
          position: session.position,
        );

        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'reopened',
          'step': step.label,
          'uri': source.uri.toString(),
          'backend': _registration.id,
        });
      } catch (error, stackTrace) {
        _backendReady = false;

        _emitTargetEvent(
          RecoveryTargetEventKind.stepFailed,
          step,
          sourceId: source.id,
          message: '$error',
          error: error,
          stackTrace: stackTrace,
        );

        rethrow;
      }
    });
  }

  /// Attaches [registration] and opens the session's source on it.
  ///
  /// The previous backend is left untouched until the replacement has
  /// proven itself: it is initialized, opened, positioned and playing
  /// before the runtime is told to swap. A backend that fails to attach
  /// therefore costs one adapter, not the playback.
  Future<void> _swapTo(RecoveryStep step, PlayerAdapterRegistration registration, RecoverySession session) {
    final operationGeneration = _invalidateOperations();
    final source = step.source ?? session.source ?? _currentSource;
    final previousId = _registration.id;

    return _enqueue(() async {
      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        throw StateError('Recovery backend swap to ${registration.id} was superseded.');
      }

      if (registration.id == previousId) {
        throw StateError('Backend ${registration.id} is already attached.');
      }

      _emitTargetEvent(RecoveryTargetEventKind.stepStarted, step, backendId: registration.id, sourceId: source?.id);

      MediaCoreLog.warning(
        LogCategory.fallback,
        'switching backend: $previousId -> ${registration.id}'
            '${source == null ? ' (no source open)' : ' for ${source.uri}'}',
        fields: <String, Object?>{
          'step': step.label,
          'reason': session.failure.code.value,
          'reasonDetail': session.failure.message,
          'reportedBy': session.failure.source.name,
          'wasPlaying': session.wasPlaying,
          'positionMs': session.position.inMilliseconds,
        },
      );

      final nextAdapter = registration.factory.create(registration.id);

      bool committed = false;

      try {
        await nextAdapter.initialize(_adapterContext);

        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          throw StateError('Recovery backend swap to ${registration.id} was superseded.');
        }

        if (source != null) {
          await nextAdapter.open(source);
          await _prepareStagedAdapter(nextAdapter, session);
        }

        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          throw StateError('Recovery backend swap to ${registration.id} was superseded.');
        }

        // The replacement is fully prepared: hand it to the runtime,
        // which detaches the old bindings, swaps the adapter and rebuilds
        // the bindings against the new backend.
        await _installAdapter(nextAdapter, registration);

        committed = true;

        _currentSource = source;
        _backendReady = source != null;

        await _applyAudioOnly(nextAdapter);

        _emitTargetEvent(
          RecoveryTargetEventKind.stepSucceeded,
          step,
          backendId: registration.id,
          sourceId: source?.id,
          position: session.position,
        );

        _publish(PlayerEventType.fallback, <String, Object?>{
          'action': 'backendAttached',
          'step': step.label,
          'from': previousId,
          'to': registration.id,
        });
      } catch (error, stackTrace) {
        if (!committed) {
          // The previous backend is still attached and still owns its
          // subscription: there is nothing to roll back.
          try {
            await nextAdapter.dispose();
          } catch (_) {
            // Best-effort cleanup of the failed replacement adapter.
          }
        }

        _emitTargetEvent(
          RecoveryTargetEventKind.stepFailed,
          step,
          backendId: registration.id,
          sourceId: source?.id,
          message: '$error',
          error: error,
          stackTrace: stackTrace,
        );

        rethrow;
      }
    });
  }

  /// Sends the session state to a staged adapter before it goes live.
  Future<void> _prepareStagedAdapter(PlayerAdapter adapter, RecoverySession session) async {
    await _applyAudioOnly(adapter);

    if (session.volume != 1.0) {
      await adapter.setVolume(session.volume);
    }

    if (session.rate != 1.0) {
      await adapter.setRate(session.rate);
    }

    if (session.position > Duration.zero) {
      await adapter.seek(session.position);
    }

    if (session.wasPlaying) {
      await adapter.play();
    }
  }

  /// Restores the session state on the currently attached adapter.
  ///
  /// The runtime's own bindings mirror adapter events into the playback
  /// and session controllers, but they never re-issue commands: after a
  /// reopen the playback controller still reports whatever the user last
  /// asked for, and it must be told to seek and resume again.
  Future<void> _restoreSession(RecoverySession session, {required PlayerSource? source}) async {
    final adapter = _runtime.adapter;

    if (session.volume != 1.0) {
      await adapter.setVolume(session.volume);
    }

    if (session.rate != 1.0) {
      await adapter.setRate(session.rate);
    }

    if (session.position > Duration.zero) {
      await adapter.seek(session.position);

      await _runtime.playback.seek(session.position);
    }

    if (session.wasPlaying) {
      await adapter.play();

      await _runtime.playback.play();
      await _runtime.sessionController.play();
    } else {
      await adapter.pause();

      await _runtime.playback.pause();
      await _runtime.sessionController.pause();
    }
  }

  void _emitTargetEvent(
    RecoveryTargetEventKind kind,
    RecoveryStep step, {
    SourceId? sourceId,
    String? backendId,
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Duration position = Duration.zero,
  }) {
    if (_targetEvents.isClosed) {
      return;
    }

    _targetEvents.add(
      RecoveryTargetEvent(
        kind: kind,
        step: step,
        message: message,
        error: error,
        stackTrace: stackTrace,
        sourceId: sourceId,
        backendId: backendId,
        position: position,
      ),
    );
  }

  /// Projects a ladder decision onto the event bus.
  ///
  /// The ladder stream is recovery's own diagnostic surface; the event
  /// bus is the framework-wide one. Both are fed, because a consumer that
  /// already tracks player events should not have to subscribe twice.
  void _onLadderEvent(RecoveryLadderEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case RecoveryLadderStarted(failure: final failure, plan: final plan):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'started',
          'code': failure?.code.value,
          'reason': failure?.effectiveReason.toString(),
          'reporter': failure?.source.name,
          'plan': plan.map((kind) => kind.name).toList(),
          'budget': _budget.toMap(),
        });

      case RecoveryLadderStepStarted(step: final step, attempt: final attempt):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'step',
          'step': step?.label,
          'kind': step?.kind.name,
          'attempt': attempt,
        });

      case RecoveryLadderStepFailed(step: final step, failure: final failure, attempt: final attempt):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'stepFailed',
          'step': step?.label,
          'attempt': attempt,
          'code': failure?.code.value,
          'message': failure?.message,
        });

      case RecoveryLadderCompleted(step: final step, attempt: final attempt):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'completed',
          'step': step?.label,
          'attempt': attempt,
        });

      case RecoveryLadderExhausted(failure: final failure, attempt: final attempt, message: final message):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'exhausted',
          'attempts': attempt,
          'reason': message,
        });

        _publishFatal(failure);

      case RecoveryLadderCancelled(attempt: final attempt, message: final message):
        _publish(PlayerEventType.recovery, <String, Object?>{
          'action': 'cancelled',
          'attempt': attempt,
          'reason': message,
        });
    }
  }

  /// Publishes the terminal error of a player whose recovery gave up.
  ///
  /// This used to live in the kernel, which meant the kernel had to know
  /// per-player recovery outcomes. The ladder reports it where it
  /// happens; the kernel only aggregates the event bus.
  void _publishFatal(RecoveryFailure? failure) {
    MediaCoreLog.error(
      LogCategory.recovery,
      'recovery exhausted: playback is terminal'
          '${failure == null ? '' : ' (${failure.code.value}: ${failure.message})'}',
      fields: <String, Object?>{'backend': _registration.id, 'uri': _currentSource?.uri.toString()},
    );

    if (!_options.enableEventBus) {
      return;
    }

    final message = failure?.message ?? 'Playback failed and recovery was exhausted.';

    _eventBus.publish(
      PlayerErrorEvent(
        error: failure?.cause ?? message,
        stackTrace: failure?.stackTrace,
        priority: EventPriority.critical,
        context: _buildContext(),
      ),
    );

    _eventBus.publish(
      GenericPlayerEvent(
        type: PlayerEventType.fallback,
        data: <String, Object?>{'action': 'exhausted', 'code': failure?.code.value, 'backend': _registration.id},
        priority: EventPriority.critical,
        context: _buildContext(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Adapter event bridge
  //
  // Only handles what the runtime does not:
  //
  // - session transitions
  // - recovery / fallback triggers
  // - lifecycle transitions
  // - event bus publication
  // - completion restarts (config.loop)
  //
  // Playback state is updated by PlayerPlaybackBinding.
  // Geometry state is updated by PlayerGeometryBinding.
  // ---------------------------------------------------------------------------

  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case PlayerAdapterOpened():
        _publish(PlayerEventType.source, const <String, Object?>{'action': 'adapterOpened'});

      case PlayerAdapterPlaying():
        // PlaybackController updated by PlayerPlaybackBinding.
        _runtime.sessionController.play();

      case PlayerAdapterPaused():
        _runtime.sessionController.pause();

      case PlayerAdapterStopped():
        _runtime.sessionController.stop();

      case PlayerAdapterBuffering(buffering: final buffering, progress: final progress):
        // PlaybackController updated by PlayerPlaybackBinding.
        _runtime.sessionController.buffering();

        _publish(PlayerEventType.buffering, <String, Object?>{'buffering': buffering, 'progress': progress});

      case PlayerAdapterCompleted():
        _runtime.sessionController.complete();

        _publish(PlayerEventType.playback, const <String, Object?>{'action': 'completed'});

        _handleCompletion();

      case PlayerAdapterPositionChanged():
      case PlayerAdapterDurationChanged():
      case PlayerAdapterVolumeChanged():
      case PlayerAdapterRateChanged():
        // Handled by PlayerPlaybackBinding.
        break;

      case PlayerAdapterVideoSizeChanged(width: final width, height: final height):
        // GeometryController updated by PlayerGeometryBinding.
        _publish(PlayerEventType.renderer, <String, Object?>{'width': width, 'height': height});

      case PlayerAdapterVideoFrameProgress():
        // Frame heartbeat is consumed by adapter-level watchdogs.
        break;

      case PlayerAdapterVideoReconfigured():
        _publish(PlayerEventType.renderer, const <String, Object?>{'action': 'videoReconfigured'});

      case PlayerAdapterHwdecChanged(decoder: final decoder):
        _publish(PlayerEventType.renderer, <String, Object?>{'action': 'hwdecChanged', 'decoder': decoder});

      case PlayerAdapterAudioReconfigured():
        _publish(PlayerEventType.audio, const <String, Object?>{'action': 'audioReconfigured'});

      case PlayerAdapterAudioDeviceChanged(device: final device):
        _publish(PlayerEventType.audio, <String, Object?>{'action': 'audioDeviceChanged', 'device': device});

      case PlayerAdapterSubtitleChanged(text: final text):
        _publish(PlayerEventType.renderer, <String, Object?>{'action': 'subtitleChanged', 'text': text});

      case PlayerAdapterCacheChanged(buffering: final buffering, duration: final duration, progress: final progress):
        _publish(PlayerEventType.buffering, <String, Object?>{
          'action': 'cacheChanged',
          'buffering': buffering,
          'durationMs': duration?.inMilliseconds,
          'progress': progress,
        });

      case PlayerAdapterMetadataChanged(metadata: final metadata):
        _publish(PlayerEventType.player, <String, Object?>{'action': 'metadataChanged', 'metadata': metadata});

      case PlayerAdapterPlaylistChanged(items: final items, index: final index):
        _publish(PlayerEventType.player, <String, Object?>{
          'action': 'playlistChanged',
          'items': items,
          'index': index,
        });

      case PlayerAdapterClientMessage(message: final message, args: final args):
        _publish(PlayerEventType.player, <String, Object?>{
          'action': 'clientMessage',
          'message': message,
          'args': args,
        });

      case PlayerAdapterLogMessage(level: final level, prefix: final prefix, text: final text):
        _publish(PlayerEventType.player, <String, Object?>{
          'action': 'logMessage',
          'level': level,
          'prefix': prefix,
          'text': text,
        });

      case PlayerAdapterErrorEvent(message: final message, error: final error, stackTrace: final stackTrace):
        _handleAdapterError(message, error, stackTrace);
    }
  }

  /// Restarts a looping source after completion.
  Future<void> _handleCompletion() async {
    if (!_isCurrentPlaybackContext()) {
      return;
    }

    final source = _currentSource;

    if (!config.loop || source == null || _disposed || !_backendReady) {
      return;
    }

    final operationGeneration = _operationGeneration;
    final sourceId = source.id;
    final token = _createOperationToken();

    await _enqueue(() async {
      try {
        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _runtime.adapter.seek(Duration.zero));

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _runtime.adapter.play());

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _runtime.playback.play());

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _runtime.sessionController.play());
      } finally {
        _releaseOperationToken(token);
      }
    });
  }

  bool _isCurrentPlaybackContext() {
    return !_disposed && _currentSource != null && _backendReady;
  }

  // ---------------------------------------------------------------------------
  // Recovery reporting
  // ---------------------------------------------------------------------------

  /// Normalizes an adapter error into a recovery report.
  ///
  /// The handle does not decide anything here. It classifies the message
  /// (recovery owns that normalization), publishes the error for the
  /// event bus, and hands the failure to the ladder. Whether the player
  /// reopens, switches line, switches backend or gives up is the ladder's
  /// decision and nobody else's.
  void _handleAdapterError(String message, Object? error, StackTrace? stackTrace) {
    if (_disposed) {
      return;
    }

    _runtime.sessionController.error(message);

    _eventBus.publish(
      PlayerErrorEvent(
        error: error ?? message,
        stackTrace: stackTrace,
        priority: EventPriority.high,
        context: _buildContext(),
      ),
    );

    MediaCoreLog.warning(
      LogCategory.error,
      'adapter error on ${_registration.id}: $message',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'recoveryEnabled': _options.enableRecovery && config.enableRecovery},
    );

    if (!_options.enableRecovery || !config.enableRecovery) {
      return;
    }

    reportFailure(
      RecoveryFailure.fromMessage(
        message,
        error: error,
        stackTrace: stackTrace,
        source: RecoveryFailureSource.adapter,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  EventContext _buildContext() {
    return EventContext(
      playerId: _player.id,
      sessionId: _runtime.session.context.sessionId,
      sourceId: _currentSource?.id,
      generationId: _runtime.session.generation.id,
    );
  }

  void _publish(PlayerEventType type, Map<String, Object?> data, {EventPriority priority = EventPriority.normal}) {
    if (!_options.enableEventBus || _disposed) {
      return;
    }

    _eventBus.publish(GenericPlayerEvent(type: type, data: data, priority: priority, context: _buildContext()));
  }
}

/// Supplies the ladder with the alternatives this handle may fall back to.
///
/// Two very different sources feed one candidate set: the caller owns the
/// list of playable sources (a live request knows its lines, the handle
/// does not), and the adapter registry owns the list of backends. Both
/// are filtered against what is currently in use, because the ladder must
/// never be offered the failing source or backend as its own alternative.
final class _HandleRecoveryCandidates implements RecoveryCandidateProvider {
  _HandleRecoveryCandidates(this._handle);

  final PlayerHandle _handle;

  @override
  RecoveryCandidates candidatesFor(RecoveryFailure failure) {
    final currentSourceId = _handle._currentSource?.id;
    final currentBackendId = _handle._registration.id;
    final source = _handle._currentSource;

    final sources = _handle._sourceCandidates
        .where((candidate) => candidate.id != currentSourceId)
        .toList(growable: false);

    final registry = _handle._registry;

    if (registry == null) {
      return RecoveryCandidates(sources: sources);
    }

    final selector = _handle._selector ?? PlayerAdapterSelector(registry);

    // Ordering is the selector's job: it already scores protocol, format
    // and live support, so recovery does not re-implement "which backend
    // is most likely to play this".
    final backends = selector
        .candidatesFor(source ?? PlayerSource.unknown())
        .where((registration) => registration.id != currentBackendId)
        .where((registration) => registration.enabled)
        .toList(growable: false);

    return RecoveryCandidates(sources: sources, backends: backends);
  }
}

/// Resolves the ladder budget for one player.
///
/// Three layers express limits, and the narrowest one wins:
///
/// - [KernelOptions.recoveryBudget] — the kernel-wide base;
/// - [KernelOptions.maxRecoveryAttempts] / `maxFallbackAttempts` — the
///   kernel-wide defaults those two dimensions used to be driven by;
/// - [PlayerConfig] — the per-player cap, which may ask for less
///   recovery than the kernel allows but never for more.
///
/// A player that disables recovery or fallback gets a budget that cannot
/// spend the corresponding rung, which is what makes the config flags
/// effective without the ladder having to know about them.
RecoveryBudget _budgetFor(KernelOptions options, PlayerConfig config) {
  var budget = options.recoveryBudget;

  if (!options.enableRecovery || !config.enableRecovery) {
    budget = budget.withoutSameBackend();
  }

  if (!options.enableFallback || !config.enableFallback) {
    budget = budget.withoutLines().withoutBackends();
  }

  return budget.copyWith(
    maxSameBackendAttempts: _narrowest(<int>[
      budget.maxSameBackendAttempts,
      options.maxRecoveryAttempts,
      config.maxRecoveryAttempts,
    ]),
    maxBackendAttempts: _narrowest(<int>[
      budget.maxBackendAttempts,
      options.maxFallbackAttempts,
      config.maxFallbackAttempts,
    ]),
    initialBackoff: options.retryBaseDelay,
    maxBackoff: options.retryMaxDelay,
  );
}

/// Returns the smallest positive limit, or `0` when any limit is zero.
///
/// Zero is a deliberate "never do this" rather than a small number, so it
/// short-circuits instead of losing the comparison.
int _narrowest(List<int> limits) {
  var result = 0;

  for (final limit in limits) {
    if (limit <= 0) {
      return 0;
    }

    if (result == 0 || limit < result) {
      result = limit;
    }
  }

  return result;
}
