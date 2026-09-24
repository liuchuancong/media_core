import 'dart:async';
import '../core/player.dart';
import 'kernel_options.dart';
import '../core/player_state.dart';
import 'package:rxdart/rxdart.dart';
import '../core/player_config.dart';
import '../event/player_event.dart';
import '../identity/player_id.dart';
import '../event/event_context.dart';
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
import '../recovery/recovery_reason.dart';
import '../session/session_snapshot.dart';
import '../fallback/backend_fallback.dart';
import '../playback/playback_command.dart';
import '../recovery/recovery_context.dart';
import '../recovery/recovery_manager.dart';
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
import '../adapter/player_adapter_capabilities.dart';
import 'package:media_core/kernel/player_handle_snapshot.dart';

/// Callback invoked when a handle exhausted recovery and wants
/// the kernel to attempt a backend fallback.
typedef PlayerFallbackRequest = void Function(PlayerHandle handle, String message);

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
///                                  RecoveryManager
///                                  BackendFallback
///                                  PlayerEventBus
/// ```
///
/// Responsibilities:
///
/// - forward playback commands to the runtime's adapter
/// - own the per-player recovery / fallback lifecycle
/// - publish normalized events
/// - serialize backend operations
/// - protect backend operations with lifecycle generations
///
/// It does not:
///
/// - own the adapter, session or per-runtime controllers
///   (those belong to [PlayerRuntime])
/// - select or create adapters
/// - choose fallback candidates
///
/// Those belong to:
///
/// - PlayerRuntime
/// - PlayerAdapterSelector
/// - PlayerKernel
final class PlayerHandle {
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
    PlayerFallbackRequest? onFallbackRequested,
  }) : _player = player,
       _registration = registration,
       _adapterContext = adapterContext,
       _eventBus = eventBus,
       _options = options,
       _onFallbackRequested = onFallbackRequested,
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
    _subscribeAdapter(_runtime.adapter);
  }

  final Player _player;
  final PlayerAdapterContext _adapterContext;
  final PlayerEventBus _eventBus;
  final KernelOptions _options;
  final PlayerFallbackRequest? _onFallbackRequested;

  final PlayerRuntime _runtime;

  PlayerAdapterRegistration _registration;
  PlayerSource? _currentSource;

  final LifecycleController _lifecycle = LifecycleController();
  final RecoveryManager _recovery = RecoveryManager();
  final BackendFallback _backendFallback = BackendFallback();

  StreamSubscription<PlayerAdapterEvent>? _adapterSubscription;

  bool _disposed = false;

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
    recovery: _recovery.snapshot,
    disposed: _disposed,
  );

  /// Lifecycle snapshot.
  LifecycleSnapshot get lifecycle => _lifecycle.snapshot;

  /// Recovery snapshot.
  RecoverySnapshot get recovery => _recovery.snapshot;

  /// Backend fallback coordinator owned by this handle.
  BackendFallback get backendFallback => _backendFallback;

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

  /// The recovery manager owned by this handle.
  RecoveryManager get recoveryManager => _recovery;

  /// The runtime composition root owned by this handle.
  PlayerRuntime get runtime => _runtime;

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
  /// recovery, fallback, event bus publication and completion. The
  /// bindings handle playback and geometry state.
  void _subscribeAdapter(PlayerAdapter adapter) {
    _adapterSubscription = adapter.events.listen((event) {
      if (_disposed || !identical(adapter, _runtime.adapter)) {
        return;
      }

      _onAdapterEvent(event);
    }, onError: (_) {});
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

    _currentSource = source;
    _backendReady = false;

    return _enqueue(() async {
      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        return;
      }

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

      _recovery.reset();

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

    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
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

    _recovery.cancel();
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

    _recovery.cancel();
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
    _recovery.cancel();

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

    _recovery.cancel();
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
    _recovery.cancel();
    _backendFallback.reset();

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

    _cancelActiveOperation(StateError('PlayerHandle for ${_player.id} is being disposed.'));

    _recovery.cancel();

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
      await _recovery.dispose();
      await _backendFallback.dispose();

      _lifecycle.dispose();
    }, allowDisposed: true);

    await _drainOperations();
  }

  // ---------------------------------------------------------------------------
  // Fallback
  // ---------------------------------------------------------------------------

  /// Swaps the backend adapter to [registration].
  ///
  /// Called by the kernel during fallback. Preserves the current
  /// source, position, volume, rate and play state.
  Future<void> attachAdapter(PlayerAdapterRegistration registration) {
    _ensureNotDisposed();

    final operationGeneration = _invalidateOperations();

    _recovery.cancel();

    final previous = _runtime.adapter;
    final previousId = previous.id;
    final wasPlaying = _runtime.playback.current.isPlaying;
    final position = _runtime.playback.current.position;
    final volume = _runtime.playback.current.volume;
    final rate = _runtime.playback.current.rate;
    final source = _currentSource;

    return _enqueue(() async {
      final nextAdapter = registration.factory.create(registration.id);

      bool committed = false;

      try {
        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          await nextAdapter.dispose();
          return;
        }

        await nextAdapter.initialize(_adapterContext);

        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          await nextAdapter.dispose();
          return;
        }

        if (source != null) {
          await nextAdapter.open(source);

          if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
            await nextAdapter.dispose();
            return;
          }

          if (position > Duration.zero) {
            await nextAdapter.seek(position);

            if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
              await nextAdapter.dispose();
              return;
            }
          }

          if (volume != 1.0) {
            await nextAdapter.setVolume(volume);

            if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
              await nextAdapter.dispose();
              return;
            }
          }

          if (rate != 1.0) {
            await nextAdapter.setRate(rate);

            if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
              await nextAdapter.dispose();
              return;
            }
          }

          if (wasPlaying) {
            await nextAdapter.play();

            if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
              await nextAdapter.dispose();
              return;
            }
          }
        }

        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          await nextAdapter.dispose();
          return;
        }

        if (source != null && !_isSourceCurrent(source)) {
          await nextAdapter.dispose();
          return;
        }

        // The replacement is fully prepared. Hand it to the runtime,
        // which detaches the old bindings, swaps the adapter, and
        // rebuilds the bindings against the new backend.
        final previousSubscription = _adapterSubscription;

        _registration = registration;

        await _runtime.replaceAdapter(nextAdapter);

        _backendReady = source != null;

        // The handle's own adapter subscription also needs to move to
        // the new adapter.
        _adapterSubscription = null;

        await previousSubscription?.cancel();

        _subscribeAdapter(_runtime.adapter);

        committed = true;

        try {
          await previous.dispose();
        } catch (_) {
          // The new backend is already active. A failure while
          // releasing the previous backend must not invalidate the
          // replacement.
        }

        if (_disposed) return;
        if (!_isOperationCurrent(operationGeneration)) return;

        _publish(PlayerEventType.fallback, <String, Object?>{
          'action': 'backendAttached',
          'from': previousId,
          'to': registration.id,
        });
      } catch (_) {
        if (!committed) {
          try {
            await nextAdapter.dispose();
          } catch (_) {
            // Best-effort cleanup of the failed replacement adapter.
          }
        }

        rethrow;
      }
    });
  }

  /// Records that the current fallback target failed.
  void markBackendFailed() {
    _backendFallback.markFailed();
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
  // Recovery
  // ---------------------------------------------------------------------------

  Future<void> _handleAdapterError(String message, Object? error, StackTrace? stackTrace) async {
    if (_disposed) {
      return;
    }

    final operationGeneration = _operationGeneration;
    final source = _currentSource;

    _runtime.sessionController.error(message);
    _recovery.cancel();

    _cancelActiveOperation(StateError('Backend error: $message'));

    _eventBus.publish(
      PlayerErrorEvent(
        error: error ?? message,
        stackTrace: stackTrace,
        priority: EventPriority.high,
        context: _buildContext(),
      ),
    );

    final maxAttempts = config.maxRecoveryAttempts;

    final canRecover =
        _options.enableRecovery && config.enableRecovery && source != null && _backendReady && maxAttempts > 0;

    final canFallback = _options.enableFallback && config.enableFallback;

    if (!canRecover) {
      if (canFallback && _isOperationCurrent(operationGeneration)) {
        _onFallbackRequested?.call(this, message);
      }

      return;
    }

    final generation = _runtime.session.generation.id;
    final resumePosition = _runtime.playback.current.position;
    final wasPlaying = _runtime.playback.current.isPlaying;

    _recovery.start(
      RecoveryContext(reason: _reasonFor(message), sourceId: source.id, generationId: generation, message: message),
    );

    _publish(PlayerEventType.recovery, <String, Object?>{
      'action': 'started',
      'attempt': 0,
      'maxAttempts': maxAttempts,
    });

    _scheduleRecoveryRetry(
      operationGeneration: operationGeneration,
      generation: generation,
      source: source,
      resumePosition: resumePosition,
      wasPlaying: wasPlaying,
      message: message,
      maxAttempts: maxAttempts,
      delay: _options.retryBaseDelay,
    );
  }

  void _scheduleRecoveryRetry({
    required int operationGeneration,
    required GenerationId generation,
    required PlayerSource source,
    required Duration resumePosition,
    required bool wasPlaying,
    required String message,
    required int maxAttempts,
    required Duration delay,
  }) {
    if (_disposed) {
      return;
    }

    final retryToken = _createOperationToken();

    _recovery.scheduleRetry(delay, () async {
      try {
        if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
          return;
        }

        if (!_runtime.session.isCurrentGeneration(generation)) {
          return;
        }

        if (!_isSourceCurrent(source)) {
          return;
        }

        if (!_backendReady) {
          return;
        }

        await _enqueue(() async {
          try {
            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              return;
            }

            if (!_runtime.session.isCurrentGeneration(generation)) {
              return;
            }

            if (!_isSourceCurrent(source)) {
              return;
            }

            if (!_backendReady) {
              return;
            }

            _publish(PlayerEventType.recovery, <String, Object?>{
              'action': 'retry',
              'attempt': _recovery.state.attempt,
              'maxAttempts': maxAttempts,
            });

            _backendReady = false;

            await retryToken.runChecked(() => _runtime.adapter.close());

            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              return;
            }

            if (!_runtime.session.isCurrentGeneration(generation)) {
              return;
            }

            if (!_isSourceCurrent(source)) {
              return;
            }

            await retryToken.runChecked(() => _runtime.adapter.open(source));

            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              _backendReady = false;
              return;
            }

            if (!_runtime.session.isCurrentGeneration(generation)) {
              _backendReady = false;
              return;
            }

            if (!_isSourceCurrent(source)) {
              _backendReady = false;
              return;
            }

            _backendReady = true;

            if (resumePosition > Duration.zero) {
              await retryToken.runChecked(() => _runtime.adapter.seek(resumePosition));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_runtime.session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (config.volume != 1.0) {
              await retryToken.runChecked(() => _runtime.adapter.setVolume(config.volume));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_runtime.session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (config.playbackRate != 1.0) {
              await retryToken.runChecked(() => _runtime.adapter.setRate(config.playbackRate));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_runtime.session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (wasPlaying) {
              await retryToken.runChecked(() => _runtime.adapter.play());

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_runtime.session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              _backendReady = false;
              return;
            }

            if (!_runtime.session.isCurrentGeneration(generation)) {
              _backendReady = false;
              return;
            }

            if (!_isSourceCurrent(source)) {
              _backendReady = false;
              return;
            }

            _recovery.complete();
            _runtime.session.updateState(const SessionState.ready());

            _publish(PlayerEventType.recovery, const <String, Object?>{'action': 'completed'});
          } finally {
            _releaseOperationToken(retryToken);
          }
        });
      } catch (_) {
        if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
          return;
        }

        if (!_runtime.session.isCurrentGeneration(generation)) {
          return;
        }

        if (!_isSourceCurrent(source)) {
          return;
        }

        _backendReady = false;

        if (_recovery.state.attempt >= maxAttempts) {
          _recovery.exhaust();

          _publish(PlayerEventType.recovery, <String, Object?>{
            'action': 'exhausted',
            'attempts': _recovery.state.attempt,
          });

          if (_options.enableFallback && config.enableFallback) {
            _onFallbackRequested?.call(this, message);
          }

          return;
        }

        final nextDelay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(0, _options.retryMaxDelay.inMilliseconds),
        );

        _scheduleRecoveryRetry(
          operationGeneration: operationGeneration,
          generation: generation,
          source: source,
          resumePosition: resumePosition,
          wasPlaying: wasPlaying,
          message: message,
          maxAttempts: maxAttempts,
          delay: nextDelay,
        );
      } finally {
        if (identical(_activeCancelToken, retryToken)) {
          _activeCancelToken = null;
        }

        retryToken.dispose();
      }
    });
  }

  RecoveryReason _reasonFor(String message) {
    final text = message.toLowerCase();

    if (text.contains('network') || text.contains('socket') || text.contains('connection')) {
      return RecoveryReason.network();
    }

    if (text.contains('timeout') || text.contains('timed out')) {
      return RecoveryReason.timeout();
    }

    if (text.contains('decode') || text.contains('decoder') || text.contains('codec')) {
      return RecoveryReason.decoder();
    }

    if (text.contains('render') || text.contains('surface') || text.contains('texture')) {
      return RecoveryReason.renderer();
    }

    if (text.contains('source') || text.contains('format') || text.contains('404')) {
      return RecoveryReason.source();
    }

    return RecoveryReason.unknown();
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
