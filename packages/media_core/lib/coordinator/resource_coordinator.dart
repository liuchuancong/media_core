import '../identity/player_id.dart';
import '../resource/resource_manager.dart';
import '../resource/resource_pressure.dart';

/// Coordinates player resources.
///
/// [ResourceCoordinator] coordinates resource
/// related operations between players and
/// resource subsystem.
///
/// It does not:
///
/// - manage memory directly
/// - manage decoder directly
/// - control playback
///
/// Those belong to:
///
/// - ResourceManager
/// - MemoryManager
/// - DecoderManager
final class ResourceCoordinator {
  /// Creates resource coordinator.
  ResourceCoordinator();

  final Map<PlayerId, ResourceManager> _managers = {};

  /// Registers resource manager.
  void register({required PlayerId playerId, required ResourceManager manager}) {
    _managers[playerId] = manager;
  }

  /// Removes resource manager.
  bool unregister(PlayerId playerId) {
    return _managers.remove(playerId) != null;
  }

  /// Gets resource manager.
  ResourceManager? managerOf(PlayerId playerId) {
    return _managers[playerId];
  }

  /// Applies resource pressure.
  Future<void> applyPressure({required PlayerId playerId, required ResourcePressure pressure}) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.handlePressure(pressure);
  }

  /// Releases player resources.
  Future<void> release(PlayerId playerId) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.release();
  }

  /// Clears bindings.
  void clear() {
    _managers.clear();
  }

  /// Disposes coordinator.
  Future<void> dispose() async {
    clear();
  }
}
