import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../adapter/player_adapter.dart';
import '../adapter/player_adapter_event.dart';
import '../adapter/player_adapter_metrics.dart';
import '../adapter/player_adapter_registry.dart';
import '../adapter/player_adapter_context.dart';
import '../adapter/player_adapter_capabilities.dart';
import '../core/player.dart';
import '../core/player_config.dart';
import '../core/player_state.dart';
import '../event/event_context.dart';
import '../event/event_priority.dart';
import '../event/player_event.dart';
import '../event/player_event_bus.dart';
import '../event/player_event_type.dart';
import '../identity/generation_id.dart';
import '../identity/player_id.dart';
import '../identity/session_id.dart';
import '../lifecycle/lifecycle_controller.dart';
import '../lifecycle/lifecycle_snapshot.dart';
import '../playback/playback_command.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_state.dart';
import '../policy/player_policy.dart';
import '../platform/platform_capabilities.dart';
import '../recovery/recovery_context.dart';
import '../recovery/recovery_manager.dart';
import '../recovery/recovery_reason.dart';
import '../recovery/recovery_snapshot.dart';
import '../fallback/backend_fallback.dart';
import '../session/player_session.dart';
import '../session/session_context.dart';
import '../session/session_controller.dart';
import '../session/session_snapshot.dart';
import '../session/session_state.dart';
import '../source/player_source.dart';
import 'kernel_options.dart';

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
  /// Creates a handle. Prefer `PlayerKernel.create` over calling
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
    _adapterSubscription = _adapter.events.listen(_onAdapterEvent, onError: (_) {});
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
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the adapter and lifecycle.
  ///
  /// Called by the kernel after construction.
  Future<void> initialize() async {
    _ensureNotDisposed();
    await _adapter.initialize(_adapterContext);
    _lifecycle.create();
    _lifecycle.initialize();
    _publish(PlayerEventType.player, const <String, Object?>{'action': 'initialized'});
  }

  /// Opens [source] on the adapter.
  ///
  /// A new playback generation is created first so stale results
  /// from a previous open are ignored.
  Future<void> open(PlayerSource source, {bool? autoPlay}) async {
    _ensureNotDisposed();

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

    _recovery.reset();
    _currentSource = source;

    await _adapter.open(source);

    if (config.volume != 1.0) {
      await _adapter.setVolume(config.volume);
    }
    if (config.playbackRate != 1.0) {
      await _adapter.setRate(config.playbackRate);
    }

    _publish(PlayerEventType.source, <String, Object?>{
      'action': 'opened',
      'uri': source.uri.toString(),
      'backend': _registration.id,
    });

    if (autoPlay ?? config.autoPlay) {
      await play();
    }
  }

  /// Starts playback.
  Future<void> play() async {
    _ensureNotDisposed();
    await _adapter.play();
    await _playback.play();
    await _sessionController.play();
    _lifecycle.activate();
    _publish(PlayerEventType.playback, const <String, Object?>{'action': 'play'});
  }

  /// Pauses playback.
  Future<void> pause() async {
    _ensureNotDisposed();
    await _adapter.pause();
    await _playback.pause();
    await _sessionController.pause();
    _lifecycle.pause();
    _publish(PlayerEventType.playback, const <String, Object?>{'action': 'pause'});
  }

  /// Stops playback and clears the session state.
  Future<void> stop() async {
    _ensureNotDisposed();
    await _adapter.stop();
    await _playback.stop();
    await _sessionController.stop();
    _publish(PlayerEventType.playback, const <String, Object?>{'action': 'stop'});
  }

  /// Seeks to [position].
  Future<void> seek(Duration position) async {
    _ensureNotDisposed();
    await _adapter.seek(position);
    await _playback.seek(position);
    _publish(PlayerEventType.playback, <String, Object?>{'action': 'seek', 'positionMs': position.inMilliseconds});
  }

  /// Sets the volume in the 0.0–1.0 range.
  Future<void> setVolume(double volume) async {
    _ensureNotDisposed();
    final clamped = volume.clamp(0.0, 1.0);
    await _adapter.setVolume(clamped);
    _playback.apply(PlaybackCommand.volume(clamped));
    _publish(PlayerEventType.audio, <String, Object?>{'action': 'volume', 'volume': clamped});
  }

  /// Sets the playback rate.
  Future<void> setRate(double rate) async {
    _ensureNotDisposed();
    await _adapter.setRate(rate);
    _playback.apply(PlaybackCommand.rate(rate));
    _publish(PlayerEventType.playback, <String, Object?>{'action': 'rate', 'rate': rate});
  }

  /// Closes the current source without disposing the player.
  Future<void> close() async {
    _ensureNotDisposed();
    await _adapter.close();
    await _playback.stop();
    await _sessionController.stop();
    _currentSource = null;
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
  Future<void> deactivate() async {
    _ensureNotDisposed();
    if (_playback.current.isPlaying) {
      try {
        await _adapter.pause();
        await _playback.pause();
        await _sessionController.pause();
      } catch (_) {
        // Backend may already be releasing; deactivation continues.
      }
    }
    _lifecycle.pause();
    _publish(PlayerEventType.lifecycle, const <String, Object?>{'action': 'deactivated'});
  }

  /// Resets this handle for pool reuse.
  ///
  /// Closes the source, resets recovery and fallback state and
  /// rolls the session into a new generation.
  Future<void> recycle() async {
    _ensureNotDisposed();
    if (_currentSource != null) {
      try {
        await _adapter.close();
      } catch (_) {
        // Recycling must not fail on a broken backend.
      }
    }
    _currentSource = null;
    _recovery.reset();
    _backendFallback.reset();
    _sessionController.recreateGeneration();
    _session.updateState(const SessionState.idle());
    await _playback.stop();
  }

  /// Releases all resources owned by this handle.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _adapterSubscription?.cancel();
    _adapterSubscription = null;

    _lifecycle.detach();
    _lifecycle.dispose();

    try {
      await _adapter.dispose();
    } catch (_) {
      // Disposal continues even when the backend refuses.
    }

    await _recovery.dispose();
    await _backendFallback.dispose();
    await _playback.dispose();
    await _sessionController.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fallback
  // ---------------------------------------------------------------------------

  /// Swaps the backend adapter to [registration].
  ///
  /// Called by the kernel during fallback. Preserves the current
  /// source, position, volume, rate and play state.
  Future<void> attachAdapter(PlayerAdapterRegistration registration) async {
    _ensureNotDisposed();

    final previous = _adapter;
    final previousId = previous.id;
    final wasPlaying = _playback.current.isPlaying;
    final position = _playback.current.position;
    final volume = _playback.current.volume;
    final rate = _playback.current.rate;

    await _adapterSubscription?.cancel();
    _adapterSubscription = null;

    _registration = registration;
    _adapter = registration.factory.create(registration.id);
    _adapterSubscription = _adapter.events.listen(_onAdapterEvent, onError: (_) {});

    await _adapter.initialize(_adapterContext);

    final source = _currentSource;
    if (source != null) {
      await _adapter.open(source);
      if (position > Duration.zero) {
        await _adapter.seek(position);
      }
      if (volume != 1.0) {
        await _adapter.setVolume(volume);
      }
      if (rate != 1.0) {
        await _adapter.setRate(rate);
      }
      if (wasPlaying) {
        await _adapter.play();
        await _playback.play();
      }
    }

    await previous.dispose();

    _publish(PlayerEventType.fallback, <String, Object?>{
      'action': 'backendAttached',
      'from': previousId,
      'to': registration.id,
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
        _publish(
          PlayerEventType.buffering,
          <String, Object?>{'buffering': buffering, 'progress': ?progress},
        );
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
      case PlayerAdapterVolumeChanged(volume: final volume):
        _playback.apply(PlaybackCommand.volume(volume));
      case PlayerAdapterRateChanged(rate: final rate):
        _playback.apply(PlaybackCommand.rate(rate));
      case PlayerAdapterErrorEvent(message: final message, error: final error, stackTrace: final stackTrace):
        _handleAdapterError(message, error, stackTrace);
    }
  }

  Future<void> _handleCompletion() async {
    if (!config.loop || _currentSource == null || _disposed) {
      return;
    }
    try {
      await _adapter.seek(Duration.zero);
      await _adapter.play();
    } catch (_) {
      // Loop restart is best-effort.
    }
  }

  // ---------------------------------------------------------------------------
  // Recovery
  // ---------------------------------------------------------------------------

  Future<void> _handleAdapterError(String message, Object? error, StackTrace? stackTrace) async {
    if (_disposed) {
      return;
    }

    _sessionController.error(message);
    _recovery.cancel();

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
        _options.enableRecovery && config.enableRecovery && _currentSource != null && maxAttempts > 0;
    final canFallback = _options.enableFallback && config.enableFallback;

    if (!canRecover) {
      if (canFallback) {
        _onFallbackRequested?.call(this, message);
      }
      return;
    }

    final generation = _session.generation.id;
    final source = _currentSource!;
    final resumePosition = _playback.current.position;
    final wasPlaying = _playback.current.isPlaying;

    _recovery.start(
      RecoveryContext(
        reason: _reasonFor(message),
        sourceId: source.id,
        generationId: generation,
        message: message,
      ),
    );

    _publish(PlayerEventType.recovery, <String, Object?>{
      'action': 'started',
      'attempt': 0,
      'maxAttempts': maxAttempts,
    });

    _scheduleRecoveryRetry(
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

    _recovery.scheduleRetry(delay, () async {
      if (_disposed) {
        return;
      }
      if (!_session.isCurrentGeneration(generation)) {
        return;
      }

      _publish(PlayerEventType.recovery, <String, Object?>{
        'action': 'retry',
        'attempt': _recovery.state.attempt,
        'maxAttempts': maxAttempts,
      });

      try {
        await _adapter.close();
        await _adapter.open(source);
        if (resumePosition > Duration.zero) {
          await _adapter.seek(resumePosition);
        }
        if (config.volume != 1.0) {
          await _adapter.setVolume(config.volume);
        }
        if (wasPlaying) {
          await _adapter.play();
        }

        _recovery.complete();
        _session.updateState(const SessionState.ready());
        _publish(PlayerEventType.recovery, const <String, Object?>{'action': 'completed'});
      } catch (_) {
        if (_recovery.state.attempt >= maxAttempts) {
          _recovery.exhaust();
          _publish(
            PlayerEventType.recovery,
            <String, Object?>{'action': 'exhausted', 'attempts': _recovery.state.attempt},
          );
          if (_options.enableFallback && config.enableFallback) {
            _onFallbackRequested?.call(this, message);
          }
          return;
        }

        final nextDelay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(0, _options.retryMaxDelay.inMilliseconds),
        );
        _scheduleRecoveryRetry(
          generation: generation,
          source: source,
          resumePosition: resumePosition,
          wasPlaying: wasPlaying,
          message: message,
          maxAttempts: maxAttempts,
          delay: nextDelay,
        );
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
    if (!_options.enableEventBus) {
      return;
    }
    _eventBus.publish(
      GenericPlayerEvent(type: type, data: data, priority: priority, context: _buildContext()),
    );
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PlayerHandle for ${_player.id} has been disposed.');
    }
  }
}
