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

/// Callback invoked when a handle exhausted recovery and wants
/// the kernel to attempt a backend fallback.
typedef PlayerFallbackRequest = void Function(PlayerHandle handle, String message);

/// Runtime facade for one logical player.
///
/// [PlayerHandle] wires the per-player modules together:
///
/// ```text
/// PlayerAdapter ──events──▶ PlayerHandle ──▶ PlaybackController
///                                   ├──▶ SessionController / PlayerSession
///                                   ├──▶ LifecycleController
///                                   ├──▶ RecoveryManager ──▶ BackendFallback
///                                   └──▶ PlayerEventBus
/// ```
///
/// Responsibilities:
///
/// - translate adapter events into core state
/// - forward playback commands to the adapter
/// - own the per-player recovery lifecycle
/// - publish normalized events
/// - serialize backend operations
/// - protect backend operations with lifecycle generations
///
/// It does not:
///
/// - select or create adapters
/// - choose fallback candidates
/// - coordinate multiple players
///
/// Those belong to:
///
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
       _adapter = adapter,
       _registration = registration,
       _adapterContext = adapterContext,
       _eventBus = eventBus,
       _options = options,
       _onFallbackRequested = onFallbackRequested,
       _session = PlayerSession(
         context: SessionContext(
           playerId: player.id,
           sessionId: adapterContext.sessionId,
           generationId: GenerationId.generate(),
           sourceId: PlayerSource.unknown().id,
           source: PlayerSource.unknown(),
           policy: policy,
           platform: const PlatformCapabilities(),
         ),
       ) {
    _sessionController = SessionController(_session);
    _subscribeAdapter(_adapter);
  }

  final Player _player;
  final PlayerAdapterContext _adapterContext;
  final PlayerEventBus _eventBus;
  final KernelOptions _options;
  final PlayerFallbackRequest? _onFallbackRequested;

  PlayerAdapter _adapter;
  PlayerAdapterRegistration _registration;
  PlayerSource? _currentSource;

  late final PlayerSession _session;
  late final SessionController _sessionController;
  final PlaybackController _playback = PlaybackController();
  final LifecycleController _lifecycle = LifecycleController();
  final RecoveryManager _recovery = RecoveryManager();
  final BackendFallback _backendFallback = BackendFallback();

  StreamSubscription<PlayerAdapterEvent>? _adapterSubscription;

  bool _disposed = false;

  /// Whether the currently attached adapter has an opened source.
  ///
  /// This is deliberately maintained by [PlayerHandle] instead of relying
  /// only on [PlayerAdapter.initialized]. An initialized adapter may have
  /// already been closed and therefore must not receive playback commands.
  bool _backendReady = false;

  /// Monotonically increasing lifecycle generation owned by this handle.
  ///
  /// Every destructive lifecycle transition invalidates older operations:
  ///
  /// ```text
  /// open A
  ///   generation = 1
  ///
  /// close
  ///   generation = 2
  ///
  /// old open/play/recovery
  ///   generation = 1
  ///   => stale, cannot commit
  /// ```
  ///
  /// This is intentionally separate from [PlayerSession]'s
  /// [GenerationId]. The session generation describes playback
  /// identity, while this integer protects asynchronous backend
  /// operations crossing lifecycle boundaries.
  int _operationGeneration = 0;

  /// Serializes all backend operations owned by this handle.
  ///
  /// Cancellation of a Dart [Future] cannot forcibly interrupt a
  /// native player call. Serializing operations ensures that backend
  /// mutations happen in a deterministic order, while
  /// [_operationGeneration] prevents stale operations from committing
  /// state after a newer lifecycle transition.
  Future<void> _operation = Future<void>.value();

  /// Cancellation token for the currently active recovery/playback
  /// continuation.
  ///
  /// Lifecycle operations such as open/close use the operation generation
  /// instead of sharing this token. This prevents pause/stop from
  /// accidentally cancelling a source-opening lifecycle operation.
  OperationCancelToken? _activeCancelToken;

  /// Player configuration applied to this handle.
  final PlayerConfig config;

  /// Player policy applied to this handle.
  final PlayerPolicy policy;

  // ---------------------------------------------------------------------------
  // Identity and state
  // ---------------------------------------------------------------------------

  /// The logical player identity.
  Player get player => _player;

  /// Identifier of this player.
  PlayerId get id => _player.id;

  /// Current session identifier.
  SessionId get sessionId => _session.context.sessionId;

  /// Current playback generation identifier.
  GenerationId get generationId => _session.generation.id;

  /// Identifier of the backend currently attached.
  String get backendId => _registration.id;

  /// Capabilities of the attached backend.
  PlayerAdapterCapabilities get backendCapabilities => _registration.capabilities;

  /// The attached adapter.
  PlayerAdapter get adapter => _adapter;

  /// Semantic state reported by the adapter.
  PlayerState get state => _adapter.state;

  /// Metrics reported by the adapter.
  PlayerAdapterMetrics get metrics => _adapter.metrics;

  /// Currently open source, if any.
  PlayerSource? get source => _currentSource;

  /// Current playback state.
  PlaybackState get playback => _playback.current;

  /// Playback state stream.
  ValueStream<PlaybackState> get playbackStream => _playback.state;

  /// Session snapshots stream.
  Stream<SessionSnapshot> get snapshots => _session.snapshots;

  /// Latest session snapshot.
  SessionSnapshot get snapshot => _session.snapshot;

  /// Lifecycle snapshot.
  LifecycleSnapshot get lifecycle => _lifecycle.snapshot;

  /// Recovery snapshot.
  RecoverySnapshot get recovery => _recovery.snapshot;

  /// Backend fallback coordinator owned by this handle.
  BackendFallback get backendFallback => _backendFallback;

  /// Whether this handle has been disposed.
  bool get disposed => _disposed;

  /// The player session owned by this handle.
  PlayerSession get session => _session;

  /// The session controller owned by this handle.
  SessionController get sessionController => _sessionController;

  /// The playback controller owned by this handle.
  PlaybackController get playbackController => _playback;

  /// The lifecycle controller owned by this handle.
  LifecycleController get lifecycleController => _lifecycle;

  /// The recovery manager owned by this handle.
  RecoveryManager get recoveryManager => _recovery;

  // ---------------------------------------------------------------------------
  // Operation lifecycle
  // ---------------------------------------------------------------------------

  /// Invalidates all currently running and queued lifecycle operations.
  ///
  /// This does not attempt to cancel an already running native Future.
  /// Instead, it makes the operation stale so it cannot commit any state
  /// or continue with a follow-up backend command after it returns.
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
  ///
  /// This token is deliberately not used by lifecycle barriers such as
  /// open/close/recycle. Those operations are protected by
  /// [_operationGeneration].
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
  /// Errors are preserved for the caller while the internal queue remains
  /// usable for subsequent operations.
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
  ///
  /// This is mainly useful for disposal and lifecycle barriers.
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
  void _subscribeAdapter(PlayerAdapter adapter) {
    _adapterSubscription = adapter.events.listen((event) {
      if (_disposed || !identical(adapter, _adapter)) {
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
      await _adapter.initialize(_adapterContext);

      if (_disposed) {
        return;
      }

      _lifecycle.create();
      _lifecycle.initialize();

      _publish(PlayerEventType.player, const <String, Object?>{'action': 'initialized'});
    });
  }

  /// Opens [source] on the adapter.
  ///
  /// A new playback generation is created first so stale results
  /// from a previous open are ignored.
  Future<void> open(PlayerSource source, {bool? autoPlay}) {
    _ensureNotDisposed();

    // Opening a new source invalidates every previous backend operation
    // immediately, before the new operation enters the queue.
    final operationGeneration = _invalidateOperations();

    // Make the requested source visible immediately so commands queued
    // after open() can target the new source.
    _currentSource = source;

    // The adapter is not considered ready until open() completes.
    _backendReady = false;

    return _enqueue(() async {
      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        return;
      }

      final generationId = _sessionController.recreateGeneration();

      _session.updateContext(
        SessionContext(
          playerId: _player.id,
          sessionId: _session.context.sessionId,
          generationId: generationId,
          sourceId: source.id,
          source: source,
          policy: policy,
          platform: _session.context.platform,
        ),
      );

      await _sessionController.open();

      if (!_isOperationCurrent(operationGeneration) || _disposed) {
        return;
      }

      _recovery.reset();

      try {
        await _adapter.open(source);
      } catch (_) {
        if (_isOperationCurrent(operationGeneration) && _isSourceCurrent(source)) {
          _backendReady = false;
        }

        rethrow;
      }

      if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
        // A newer lifecycle operation took ownership while open() was
        // executing. Close the source that was just opened so the next
        // queued lifecycle operation starts from a clean backend state.
        try {
          await _adapter.close();
        } catch (_) {
          // Best-effort cleanup of the stale open.
        }

        _backendReady = false;
        return;
      }

      _backendReady = true;

      if (config.volume != 1.0) {
        await _adapter.setVolume(config.volume);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _adapter.close();
          } catch (_) {
            // Best-effort cleanup of a stale open.
          }

          return;
        }
      }

      if (config.playbackRate != 1.0) {
        await _adapter.setRate(config.playbackRate);

        if (!_isOperationCurrent(operationGeneration) || _disposed || !_isSourceCurrent(source)) {
          _backendReady = false;

          try {
            await _adapter.close();
          } catch (_) {
            // Best-effort cleanup of a stale open.
          }

          return;
        }
      }

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

  /// Performs the actual play operation inside the serialized queue.
  ///
  /// This private method is required because calling the public [play]
  /// method from another queued operation would enqueue behind itself
  /// and create a deadlock.
  Future<void> _playInternal(
    int operationGeneration, {
    required OperationCancelToken token,
    PlayerSource? source,
  }) async {
    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _adapter.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _playback.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    await token.runChecked(() => _sessionController.play());

    if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
      return;
    }

    _lifecycle.activate();

    _publish(PlayerEventType.playback, const <String, Object?>{'action': 'play'});
  }

  /// Pauses playback.
  ///
  /// Pause is a lifecycle intent. It cancels older recovery/play
  /// continuations, then executes itself as a queue barrier.
  ///
  /// It intentionally does not invalidate the lifecycle generation.
  /// This means:
  ///
  /// ```text
  /// open()
  /// pause()
  ///
  /// open -> pause
  /// ```
  ///
  /// remains correctly serialized instead of pause cancelling open().
  Future<void> pause() {
    _ensureNotDisposed();
    _ensureSource();

    final source = _currentSource!;

    // A user pause should cancel pending recovery/play continuations.
    _recovery.cancel();
    _cancelActiveOperation(StateError('Playback pause requested.'));

    return _enqueue(() async {
      if (_disposed) {
        return;
      }

      if (!_isSourceCurrent(source)) {
        return;
      }

      if (!_backendReady) {
        return;
      }

      await _adapter.pause();

      if (_disposed || !_isSourceCurrent(source)) {
        return;
      }

      await _playback.pause();

      if (_disposed || !_isSourceCurrent(source)) {
        return;
      }

      await _sessionController.pause();

      if (_disposed || !_isSourceCurrent(source)) {
        return;
      }

      _lifecycle.pause();

      _publish(PlayerEventType.playback, const <String, Object?>{'action': 'pause'});
    });
  }

  /// Stops playback and clears the session state.
  ///
  /// Stop is a lifecycle barrier. Older recovery/play operations are
  /// cancelled, while this stop operation itself remains serialized
  /// behind any already running backend call.
  Future<void> stop() {
    _ensureNotDisposed();

    if (_currentSource == null) {
      return Future<void>.value();
    }

    final source = _currentSource;

    _recovery.cancel();
    _cancelActiveOperation(StateError('Playback stop requested.'));

    return _enqueue(() async {
      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

      if (!_backendReady) {
        return;
      }

      await _adapter.stop();

      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

      await _playback.stop();

      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

      await _sessionController.stop();

      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

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

        await token.runChecked(() => _adapter.seek(position));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _playback.seek(position));

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
  Future<void> setVolume(double volume) {
    _ensureNotDisposed();
    _ensureSource();

    final clamped = volume.clamp(0.0, 1.0);
    final operationGeneration = _captureOperationGeneration();
    final source = _currentSource!;

    final token = _createOperationToken();

    return _enqueue(() async {
      try {
        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        await token.runChecked(() => _adapter.setVolume(clamped));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _playback.apply(PlaybackCommand.volume(clamped));

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
  Future<void> setRate(double rate) {
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

        await token.runChecked(() => _adapter.setRate(rate));

        if (!_canUseBackend(operationGeneration: operationGeneration, source: source) || token.isCancelled) {
          return;
        }

        _playback.apply(PlaybackCommand.rate(rate));

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
  ///
  /// Close is a lifecycle barrier:
  ///
  /// 1. invalidate old operations immediately
  /// 2. remove the current source immediately
  /// 3. cancel pending recovery/play continuations
  /// 4. wait for currently running backend work
  /// 5. close the backend
  /// 6. clear playback/session state
  ///
  /// The close operation itself is never cancelled merely because a
  /// newer operation generation appears. Queue ordering guarantees
  /// that a following open runs after close.
  Future<void> close() {
    _ensureNotDisposed();

    // Close is a lifecycle barrier. Invalidate first so every old
    // play/open/recovery operation immediately becomes stale.
    _invalidateOperations();

    _currentSource = null;
    _backendReady = false;
    _recovery.cancel();

    // Close must cancel recovery/play continuations, but the close
    // operation itself is protected by the lifecycle generation.
    _cancelActiveOperation(StateError('Player close requested.'));

    return _enqueue(() async {
      if (_disposed) {
        return;
      }

      // Close is intentionally not guarded by operationGeneration.
      // A later open() may already have incremented the generation,
      // but queue ordering requires this close to finish first.
      try {
        await _adapter.close();
      } catch (_) {
        // Closing an already released backend is harmless here.
      }

      _backendReady = false;

      if (_disposed) {
        return;
      }

      await _playback.stop();

      if (_disposed) {
        return;
      }

      await _sessionController.stop();

      if (_disposed) {
        return;
      }

      _publish(PlayerEventType.playback, const <String, Object?>{'action': 'stop'});
    });
  }

  /// Marks the player active. Paired with [deactivate].
  void activate() {
    _ensureNotDisposed();
    _lifecycle.activate();
  }

  /// Deactivates the player and pauses playback when active.
  ///
  /// This is the hook used by visibility and page lifecycle
  /// coordination: background players stop consuming resources.
  Future<void> deactivate() {
    _ensureNotDisposed();

    if (!_playback.current.isPlaying) {
      _lifecycle.pause();

      _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});

      return Future<void>.value();
    }

    final source = _currentSource;

    // Deactivation cancels recovery/play continuations but does not
    // invalidate the source-opening lifecycle itself.
    _recovery.cancel();
    _cancelActiveOperation(StateError('Player deactivation requested.'));

    return _enqueue(() async {
      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

      if (!_backendReady) {
        _lifecycle.pause();

        _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});

        return;
      }

      try {
        await _adapter.pause();

        if (_disposed) {
          return;
        }

        if (source != null && !_isSourceCurrent(source)) {
          return;
        }

        await _playback.pause();

        if (_disposed) {
          return;
        }

        if (source != null && !_isSourceCurrent(source)) {
          return;
        }

        await _sessionController.pause();
      } catch (_) {
        // Backend may already be releasing; deactivation continues.
      }

      if (_disposed) {
        return;
      }

      if (source != null && !_isSourceCurrent(source)) {
        return;
      }

      _lifecycle.pause();

      _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});
    });
  }

  /// Resets this handle for pool reuse.
  ///
  /// Closes the source, resets recovery and fallback state and
  /// rolls the session into a new generation.
  Future<void> recycle() {
    _ensureNotDisposed();

    _invalidateOperations();

    _currentSource = null;
    _backendReady = false;
    _recovery.cancel();
    _backendFallback.reset();

    return _enqueue(() async {
      if (_disposed) {
        return;
      }

      try {
        // Recycling is a lifecycle barrier. This close must not be
        // skipped because another operation changed the generation.
        await _adapter.close();
      } catch (_) {
        // Recycling must not fail on a broken backend.
      }

      _backendReady = false;

      if (_disposed) {
        return;
      }

      _sessionController.recreateGeneration();
      _session.updateState(const SessionState.idle());

      await _playback.stop();

      if (_disposed) {
        return;
      }

      _lifecycle.pause();
    });
  }

  /// Releases all resources owned by this handle.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    // Invalidate old operations before marking the handle disposed.
    // Any running operation will be unable to commit state when it returns.
    _disposed = true;
    _operationGeneration++;

    _currentSource = null;
    _backendReady = false;

    _cancelActiveOperation(StateError('PlayerHandle for ${_player.id} is being disposed.'));

    _recovery.cancel();

    // Prevent any further adapter events from entering the handle while
    // the final lifecycle barrier waits for currently running operations.
    await _adapterSubscription?.cancel();
    _adapterSubscription = null;

    _lifecycle.detach();

    // Dispose must be allowed through the operation queue even though
    // the handle is already marked disposed.
    await _enqueue(() async {
      try {
        await _adapter.dispose();
      } catch (_) {
        // Disposal continues even when the backend refuses.
      }

      await _recovery.dispose();
      await _backendFallback.dispose();
      await _playback.dispose();
      await _sessionController.dispose();

      _lifecycle.dispose();
    }, allowDisposed: true);

    // Drain anything that was already queued before dispose.
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

    // Backend replacement is a lifecycle boundary. Every operation
    // targeting the previous adapter becomes stale immediately.
    final operationGeneration = _invalidateOperations();

    _recovery.cancel();

    final previous = _adapter;
    final previousId = previous.id;
    final wasPlaying = _playback.current.isPlaying;
    final position = _playback.current.position;
    final volume = _playback.current.volume;
    final rate = _playback.current.rate;
    final source = _currentSource;

    return _enqueue(() async {
      final nextAdapter = registration.factory.create(registration.id);

      bool committed = false;

      try {
        if (!_isOperationCurrent(operationGeneration) || _disposed) {
          await nextAdapter.dispose();
          return;
        }

        // Keep the existing adapter as the active adapter until the new
        // adapter has been completely initialized and opened successfully.
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

        // The replacement is now fully prepared. Only at this point
        // does it become the active adapter.
        final previousSubscription = _adapterSubscription;

        _registration = registration;
        _adapter = nextAdapter;
        _backendReady = source != null;

        _adapterSubscription = null;

        await previousSubscription?.cancel();

        _subscribeAdapter(nextAdapter);

        committed = true;

        try {
          await previous.dispose();
        } catch (_) {
          // The new backend is already active. A failure while releasing
          // the previous backend must not invalidate the replacement.
        }

        if (_disposed) {
          return;
        }

        if (!_isOperationCurrent(operationGeneration)) {
          return;
        }

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
  // ---------------------------------------------------------------------------

  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case PlayerAdapterOpened():
        _publish(PlayerEventType.source, const <String, Object?>{'action': 'adapterOpened'});

      case PlayerAdapterPlaying():
        _playback.apply(const PlaybackCommand.play());
        _sessionController.play();

      case PlayerAdapterPaused():
        _playback.apply(const PlaybackCommand.pause());
        _sessionController.pause();

      case PlayerAdapterStopped():
        _playback.apply(const PlaybackCommand.stop());
        _sessionController.stop();

      case PlayerAdapterBuffering(buffering: final buffering, progress: final progress):
        _playback.setBuffering(buffering);
        _sessionController.buffering();

        _publish(PlayerEventType.buffering, <String, Object?>{'buffering': buffering, 'progress': progress});

      case PlayerAdapterCompleted():
        _sessionController.complete();

        _publish(PlayerEventType.playback, const <String, Object?>{'action': 'completed'});

        _handleCompletion();

      case PlayerAdapterPositionChanged(position: final position):
        _playback.updatePosition(position);

      case PlayerAdapterDurationChanged(duration: final duration):
        _playback.updateDuration(duration);

      case PlayerAdapterVideoSizeChanged(width: final width, height: final height):
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

      case PlayerAdapterVolumeChanged(volume: final volume):
        _playback.apply(PlaybackCommand.volume(volume));

      case PlayerAdapterRateChanged(rate: final rate):
        _playback.apply(PlaybackCommand.rate(rate));

      case PlayerAdapterErrorEvent(message: final message, error: final error, stackTrace: final stackTrace):
        _handleAdapterError(message, error, stackTrace);
    }
  }

  /// Restarts a looping source after completion.
  ///
  /// Completion recovery is treated as a normal serialized backend
  /// operation so close/open/dispose cannot race it.
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

        await token.runChecked(() => _adapter.seek(Duration.zero));

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _adapter.play());

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _playback.play());

        if (!_isOperationCurrent(operationGeneration) ||
            token.isCancelled ||
            !_isSourceIdCurrent(sourceId) ||
            !_backendReady) {
          return;
        }

        await token.runChecked(() => _sessionController.play());
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

    _sessionController.error(message);
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

    final generation = _session.generation.id;
    final resumePosition = _playback.current.position;
    final wasPlaying = _playback.current.isPlaying;

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

    // The retry owns the generation from the moment it is scheduled.
    // Never read _operationGeneration again as a replacement for this value.
    final retryToken = _createOperationToken();

    _recovery.scheduleRetry(delay, () async {
      try {
        if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
          return;
        }

        // The retry belongs to the lifecycle generation that created it.
        // Any pause/stop/close/open/backend-switch invalidates it.
        if (!_session.isCurrentGeneration(generation)) {
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

            if (!_session.isCurrentGeneration(generation)) {
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

            // Recovery owns the backend while this retry is running.
            // The backend remains logically attached to the same source.
            _backendReady = false;

            await retryToken.runChecked(() => _adapter.close());

            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              return;
            }

            if (!_session.isCurrentGeneration(generation)) {
              return;
            }

            if (!_isSourceCurrent(source)) {
              return;
            }

            await retryToken.runChecked(() => _adapter.open(source));

            if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
              _backendReady = false;
              return;
            }

            if (!_session.isCurrentGeneration(generation)) {
              _backendReady = false;
              return;
            }

            if (!_isSourceCurrent(source)) {
              _backendReady = false;
              return;
            }

            _backendReady = true;

            if (resumePosition > Duration.zero) {
              await retryToken.runChecked(() => _adapter.seek(resumePosition));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (config.volume != 1.0) {
              await retryToken.runChecked(() => _adapter.setVolume(config.volume));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (config.playbackRate != 1.0) {
              await retryToken.runChecked(() => _adapter.setRate(config.playbackRate));

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_session.isCurrentGeneration(generation)) {
                _backendReady = false;
                return;
              }

              if (!_isSourceCurrent(source)) {
                _backendReady = false;
                return;
              }
            }

            if (wasPlaying) {
              await retryToken.runChecked(() => _adapter.play());

              if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
                _backendReady = false;
                return;
              }

              if (!_session.isCurrentGeneration(generation)) {
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

            if (!_session.isCurrentGeneration(generation)) {
              _backendReady = false;
              return;
            }

            if (!_isSourceCurrent(source)) {
              _backendReady = false;
              return;
            }

            _recovery.complete();
            _session.updateState(const SessionState.ready());

            _publish(PlayerEventType.recovery, const <String, Object?>{'action': 'completed'});
          } finally {
            _releaseOperationToken(retryToken);
          }
        });
      } catch (_) {
        if (_disposed || retryToken.isCancelled || !_isOperationCurrent(operationGeneration)) {
          return;
        }

        if (!_session.isCurrentGeneration(generation)) {
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
      sessionId: _session.context.sessionId,
      sourceId: _currentSource?.id,
      generationId: _session.generation.id,
    );
  }

  void _publish(PlayerEventType type, Map<String, Object?> data, {EventPriority priority = EventPriority.normal}) {
    if (!_options.enableEventBus || _disposed) {
      return;
    }

    _eventBus.publish(GenericPlayerEvent(type: type, data: data, priority: priority, context: _buildContext()));
  }
}
