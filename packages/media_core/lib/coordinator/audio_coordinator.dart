import '../identity/player_id.dart';
import '../audio/audio_volume.dart';
import '../audio/audio_manager.dart';

/// Coordinates audio related operations.
///
/// [AudioCoordinator] connects players
/// with audio management.
///
/// It does not:
///
/// - manage platform audio APIs
/// - handle audio focus directly
/// - execute playback
///
/// Those belong to:
///
/// - AudioManager
/// - PlatformAudio
/// - PlaybackController
final class AudioCoordinator {
  /// Creates audio coordinator.
  AudioCoordinator();

  final Map<PlayerId, AudioManager> _managers = {};

  /// Registers audio manager.
  void register({required PlayerId playerId, required AudioManager manager}) {
    _managers[playerId] = manager;
  }

  /// Removes audio manager.
  bool unregister(PlayerId playerId) {
    return _managers.remove(playerId) != null;
  }

  /// Gets audio manager.
  AudioManager? managerOf(PlayerId playerId) {
    return _managers[playerId];
  }

  /// Sets player volume.
  Future<void> setVolume({required PlayerId playerId, required AudioVolume volume}) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.setVolume(volume);
  }

  /// Mutes player.
  Future<void> mute(PlayerId playerId) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.mute();
  }

  /// Unmutes player.
  Future<void> unmute(PlayerId playerId) async {
    final manager = _managers[playerId];

    if (manager == null) {
      return;
    }

    await manager.unmute();
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
