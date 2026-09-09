import '../identity/player_id.dart';
import '../preload/preload_manager.dart';
import '../preload/preload_request.dart';

/// Coordinates preload operations.
///
/// [PreloadCoordinator] connects players
/// with preload subsystem.
///
/// It does not:
///
/// - create players
/// - resolve media sources
/// - execute playback
///
/// Those belong to:
///
/// - PlayerFactory
/// - SourceResolver
/// - PlaybackController
final class PreloadCoordinator {
  /// Creates preload coordinator.
  PreloadCoordinator();

  final Map<PlayerId, PreloadManager> _managers = {};

  /// Registers preload manager.
  void register({required PlayerId playerId, required PreloadManager manager}) {
    _managers[playerId] = manager;
  }

  /// Removes preload manager.
  bool unregister(PlayerId playerId) {
    return _managers.remove(playerId) != null;
  }

  /// Gets preload manager.
  PreloadManager? managerOf(PlayerId playerId) {
    return _managers[playerId];
  }

  /// Starts preload.
  Future<void> preload({required PlayerId playerId, required PreloadRequest request}) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.preload(request);
  }

  /// Cancels preload.
  Future<void> cancel({required PlayerId playerId}) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.cancel();
  }

  /// Clears all bindings.
  void clear() {
    _managers.clear();
  }

  /// Disposes coordinator.
  Future<void> dispose() async {
    clear();
  }
}
