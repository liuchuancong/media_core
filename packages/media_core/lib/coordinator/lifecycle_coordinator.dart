import '../identity/player_id.dart';
import '../lifecycle/lifecycle_event.dart';
import '../lifecycle/player_lifecycle.dart';

/// Coordinates player lifecycle operations.
///
/// [LifecycleCoordinator] connects players
/// with lifecycle subsystem.
///
/// It does not:
///
/// - listen to Flutter lifecycle directly
/// - create players
/// - execute playback commands
///
/// Those belong to:
///
/// - Platform lifecycle layer
/// - PlayerFactory
/// - PlaybackController
final class LifecycleCoordinator {
  /// Creates lifecycle coordinator.
  LifecycleCoordinator();

  final Map<PlayerId, PlayerLifecycle> _lifecycles = {};

  /// Registers lifecycle handler.
  void register({required PlayerId playerId, required PlayerLifecycle lifecycle}) {
    _lifecycles[playerId] = lifecycle;
  }

  /// Removes lifecycle handler.
  bool unregister(PlayerId playerId) {
    return _lifecycles.remove(playerId) != null;
  }

  /// Gets lifecycle handler.
  PlayerLifecycle? lifecycleOf(PlayerId playerId) {
    return _lifecycles[playerId];
  }

  /// Dispatches lifecycle event.
  Future<void> dispatch({required PlayerId playerId, required LifecycleEvent event}) async {
    final lifecycle = _lifecycles[playerId];

    if (lifecycle == null) {
      return;
    }

    await lifecycle.handle(event);
  }

  /// Starts lifecycle.
  Future<void> start(PlayerId playerId) async {
    final lifecycle = _lifecycles[playerId];

    if (lifecycle == null) {
      return;
    }

    await lifecycle.start();
  }

  /// Stops lifecycle.
  Future<void> stop(PlayerId playerId) async {
    final lifecycle = _lifecycles[playerId];

    if (lifecycle == null) {
      return;
    }

    await lifecycle.stop();
  }

  /// Clears all bindings.
  void clear() {
    _lifecycles.clear();
  }

  /// Disposes coordinator.
  Future<void> dispose() async {
    clear();
  }
}
