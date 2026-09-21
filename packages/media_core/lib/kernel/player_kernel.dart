import 'dart:async';

import '../adapter/player_adapter_config.dart';
import '../adapter/player_adapter_context.dart';
import '../adapter/player_adapter_registry.dart';
import '../coordinator/global_player_coordinator.dart';
import '../core/player.dart';
import '../core/player_config.dart';
import '../event/event_context.dart';
import '../event/event_priority.dart';
import '../event/event_subscription.dart';
import '../event/player_event.dart';
import '../event/player_event_bus.dart';
import '../event/player_event_type.dart';
import '../identity/player_id.dart';
import '../identity/session_id.dart';
import '../pool/player_pool.dart';
import '../preload/preload_manager.dart';
import '../preload/preload_priority.dart';
import '../preload/preload_request.dart';
import '../session/player_session.dart';
import '../source/player_source.dart';
import '../source/source_service.dart';
import 'adapter_selector.dart';
import 'kernel_options.dart';
import 'player_handle.dart';

/// The orchestration root of the media core.
///
/// [PlayerKernel] turns the individual modules into one working
/// player framework:
///
/// ```text
/// PlayerSource
///     │  SourceService (resolve)
///     ▼
/// PlayerAdapterSelector ──▶ PlayerAdapterRegistry
///     │  best backend
///     ▼
/// PlayerHandle ──▶ PlayerAdapter (media_kit / ijk / video_player / ...)
///     │
///     ├── PlayerSession + SessionController
///     ├── PlaybackController
///     ├── LifecycleController
///     ├── RecoveryManager (retry with backoff)
///     ├── BackendFallback (switch backend on exhaust)
///     ├── GlobalPlayerCoordinator (audio/page/resource/presentation)
///     ├── PlayerPool (instance reuse)
///     ├── PreloadManager (warm-up bookkeeping)
///     └── PlayerEventBus (normalized events)
/// ```
///
/// Responsibilities:
///
/// - create and release players
/// - select backends for sources
/// - drive fallback across backends
/// - expose a global event stream
///
/// It does not:
///
/// - decode media
/// - own per-player playback state
/// - render video
///
/// Those belong to:
///
/// - PlayerAdapter
/// - PlayerHandle / PlaybackController
/// - presentation widgets
///
/// Example:
///
/// ```dart
/// final kernel = PlayerKernel()
///   ..registerBackend(MediaKitPlayerAdapter.defaultRegistration());
///
/// final handle = await kernel.create(
///   config: PlayerConfig.defaults,
///   source: TestSourceFactory.httpMp4(),
/// );
/// await handle.play();
/// ```
final class PlayerKernel {
  /// Creates a kernel.
  ///
  /// Every dependency is optional and lazily constructed, so
  /// `PlayerKernel()` works out of the box once at least one
  /// backend is registered.
  PlayerKernel({
    PlayerAdapterRegistry? registry,
    PlayerAdapterSelector? selector,
    SourceService? sourceService,
    PlayerEventBus? eventBus,
    PlayerPool? pool,
    PreloadManager? preloadManager,
    GlobalPlayerCoordinator? coordinator,
    this.options = const KernelOptions(),
  }) : registry = registry ?? PlayerAdapterRegistry(),
       _selector = selector,
       _sourceService = sourceService,
       _eventBus = eventBus ?? PlayerEventBus(),
       _pool = pool ?? PlayerPool(),
       _preloadManager = preloadManager ?? PreloadManager(),
       _coordinator = coordinator ?? GlobalPlayerCoordinator();

  /// Registry of available backends.
  final PlayerAdapterRegistry registry;

  final PlayerAdapterSelector? _selector;
  final SourceService? _sourceService;
  final PlayerEventBus _eventBus;
  final PlayerPool _pool;
  final PreloadManager _preloadManager;
  final GlobalPlayerCoordinator _coordinator;

  /// Kernel-wide options.
  final KernelOptions options;

  final Map<PlayerId, PlayerHandle> _handles = {};

  /// Lazy selector bound to [registry].
  PlayerAdapterSelector get selector => _selector ?? PlayerAdapterSelector(registry);

  /// Global event bus.
  PlayerEventBus get eventBus => _eventBus;

  /// Global player pool.
  PlayerPool get pool => _pool;

  /// Global preload manager.
  PreloadManager get preloadManager => _preloadManager;

  /// Cross-player coordination layer.
  GlobalPlayerCoordinator get coordinator => _coordinator;

  // ---------------------------------------------------------------------------
  // Backend registration
  // ---------------------------------------------------------------------------

  /// Registers a backend.
  void registerBackend(PlayerAdapterRegistration registration) {
    registry.register(registration);
  }

  /// Removes a backend registration.
  void unregisterBackend(String id) {
    registry.unregister(id);
  }

  // ---------------------------------------------------------------------------
  // Player lifecycle
  // ---------------------------------------------------------------------------

  /// Creates a new player.
  ///
  /// When [source] is given the kernel resolves it through the
  /// [SourceService] (when available), selects the best backend,
  /// initializes the adapter and opens the source. [preferredBackend]
  /// overrides automatic selection.
  Future<PlayerHandle> create({
    PlayerConfig config = PlayerConfig.defaults,
    PlayerSource? source,
    String? preferredBackend,
  }) async {
    var effectiveSource = source;
    if (effectiveSource != null) {
      effectiveSource = await _resolveSource(effectiveSource);
    }

    final registration = selector.require(
      effectiveSource ?? PlayerSource.unknown(),
      preferredId: preferredBackend,
    );

    final player = Player.create();
    final sessionId = SessionId.generate();
    final adapter = registration.factory.create(registration.id);
    final adapterContext = PlayerAdapterContext(
      playerId: player.id,
      sessionId: sessionId,
      config: PlayerAdapterConfig(
        volume: config.volume,
        playbackRate: config.playbackRate,
        hardwareAcceleration: config.preferHardwareDecoding,
        audioEnabled: config.enableAudio,
      ),
      playerConfig: config,
    );

    final handle = PlayerHandle(
      player: player,
      adapter: adapter,
      registration: registration,
      adapterContext: adapterContext,
      eventBus: _eventBus,
      options: options,
      config: config,
      onFallbackRequested: _onFallbackRequested,
    );

    await handle.initialize();

    _registerEverywhere(handle);

    if (effectiveSource != null) {
      await handle.open(effectiveSource, autoPlay: config.autoPlay);
    }

    return handle;
  }

  /// Acquires an idle player from the pool.
  ///
  /// Returns `null` when the pool has no reusable player. The
  /// returned handle is recycled: fresh generation, no source.
  Future<PlayerHandle?> acquire({Duration timeout = const Duration(seconds: 2)}) async {
    if (!options.enablePool) {
      return null;
    }

    final sessionId = SessionId.generate();
    final pooledId = _pool.allocate(sessionId: sessionId);
    if (pooledId == null) {
      return null;
    }

    final handle = _handles[pooledId];
    if (handle == null || handle.disposed) {
      _pool.release(pooledId);
      return null;
    }

    await handle.recycle();
    _coordinator.player.attachSession(playerId: pooledId, session: handle.session);
    return handle;
  }

  /// Looks up a player by identifier.
  PlayerHandle? get(PlayerId playerId) {
    return _handles[playerId];
  }

  /// Looks up a player by identifier.
  PlayerHandle? operator [](PlayerId playerId) {
    return _handles[playerId];
  }

  /// All live handles.
  List<PlayerHandle> get handles {
    return List.unmodifiable(_handles.values);
  }

  /// Session bound to a player, if any.
  PlayerSession? sessionOf(PlayerId playerId) {
    return _coordinator.player.sessionOf(playerId);
  }

  /// Releases a player completely.
  ///
  /// The handle is disposed, unregistered from every coordinator
  /// and removed from the pool. Use [PlayerHandle.recycle] plus
  /// [acquire] for soft reuse.
  Future<void> release(PlayerId playerId) async {
    final handle = _handles.remove(playerId);
    if (handle == null) {
      return;
    }

    _coordinator.player.detachSession(playerId);
    _coordinator.player.unregister(playerId);
    _coordinator.playback.unregister(playerId);
    _coordinator.lifecycle.unregister(playerId);
    _pool.remove(playerId);

    await handle.dispose();
  }

  // ---------------------------------------------------------------------------
  // Preload
  // ---------------------------------------------------------------------------

  /// Registers [source] for preloading.
  ///
  /// The preload manager orders requests by [priority]. Callers
  /// observe ordering through `preloadManager.next()`.
  void preload(PlayerSource source, {PreloadPriority priority = PreloadPriority.normal}) {
    _preloadManager.add(PreloadRequest(sourceId: source.id, priority: priority));

    if (options.enableEventBus) {
      _eventBus.publish(
        GenericPlayerEvent(
          type: PlayerEventType.cache,
          data: <String, Object?>{'action': 'preloadQueued', 'uri': source.uri.toString()},
          context: EventContext(sourceId: source.id),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Global normalized event stream.
  Stream<PlayerEvent> get events => _eventBus.stream;

  /// Subscribes to the global event stream.
  EventSubscription subscribe(
    void Function(PlayerEvent event) listener, {
    EventPriority? minimumPriority,
  }) {
    return _eventBus.subscribe(listener, minimumPriority: minimumPriority);
  }

  // ---------------------------------------------------------------------------
  // Fallback
  // ---------------------------------------------------------------------------

  Future<void> _onFallbackRequested(PlayerHandle handle, String message) async {
    final config = handle.config;
    final maxAttempts = config.maxFallbackAttempts;

    if (!options.enableFallback || !config.enableFallback || maxAttempts <= 0) {
      _publishFatal(handle, message);
      return;
    }

    final candidates = registry.registrations
        .where((registration) => registration.enabled && registration.id != handle.backendId)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (candidates.isEmpty) {
      _publishFatal(handle, message);
      return;
    }

    handle.backendFallback.start(
      candidates.map((registration) => registration.id).toList(),
      currentBackend: handle.backendId,
    );

    var attempts = 0;
    while (handle.backendFallback.canFallback && attempts < maxAttempts) {
      final nextId = handle.backendFallback.next();
      if (nextId == null) {
        break;
      }

      final registration = registry.get(nextId);
      if (registration == null) {
        handle.markBackendFailed();
        continue;
      }

      attempts++;
      try {
        await handle.attachAdapter(registration);
        handle.backendFallback.complete();
        return;
      } catch (_) {
        handle.markBackendFailed();
      }
    }

    _publishFatal(handle, message);
  }

  void _publishFatal(PlayerHandle handle, String message) {
    _eventBus.publish(
      PlayerErrorEvent(
        error: message,
        priority: EventPriority.critical,
        context: EventContext(playerId: handle.id, sessionId: handle.sessionId),
      ),
    );
    _eventBus.publish(
      GenericPlayerEvent(
        type: PlayerEventType.fallback,
        data: const <String, Object?>{'action': 'exhausted'},
        priority: EventPriority.critical,
        context: EventContext(playerId: handle.id, sessionId: handle.sessionId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<PlayerSource> _resolveSource(PlayerSource source) async {
    final service = _sourceService;
    if (service == null || !service.canResolve(source)) {
      return source;
    }

    try {
      final resolved = await service.resolve(source);
      final carried = resolved.source;
      if (carried != null) {
        return carried;
      }
      if (resolved.uri != source.uri) {
        return source.copyWith(uri: resolved.uri);
      }
      return source;
    } catch (_) {
      // Resolution is an enhancement; the original source still opens.
      return source;
    }
  }

  void _registerEverywhere(PlayerHandle handle) {
    _handles[handle.id] = handle;

    if (options.enablePool) {
      _pool.add(handle.id);
    }

    _coordinator.player.register(handle.player);
    _coordinator.player.attachSession(playerId: handle.id, session: handle.session);
    _coordinator.playback.register(playerId: handle.id, controller: handle.playbackController);
    _coordinator.lifecycle.register(playerId: handle.id, lifecycle: handle.lifecycleController);
  }

  /// Disposes the kernel and every live player.
  Future<void> dispose() async {
    final ids = List<PlayerId>.from(_handles.keys);
    for (final id in ids) {
      await release(id);
    }

    await _preloadManager.dispose();
    await _coordinator.dispose();
    await _pool.dispose();
    await _eventBus.dispose();
  }
}
