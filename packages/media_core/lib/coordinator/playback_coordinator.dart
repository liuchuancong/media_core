import '../identity/player_id.dart';
import '../identity/session_id.dart';
import '../playback/playback_command.dart';
import '../playback/playback_controller.dart';

/// Coordinates playback operations.
///
/// [PlaybackCoordinator] bridges high-level
/// playback requests and playback controllers.
///
/// It does not:
///
/// - execute media commands
/// - manage backend
/// - store playback state
///
/// Those belong to:
///
/// - PlaybackController
/// - PlayerAdapter
/// - PlaybackState
final class PlaybackCoordinator {
  /// Creates playback coordinator.
  PlaybackCoordinator();

  final Map<PlayerId, PlaybackController> _controllers = {};

  /// Registers playback controller.
  void register({required PlayerId playerId, required PlaybackController controller}) {
    _controllers[playerId] = controller;
  }

  /// Removes playback controller.
  bool unregister(PlayerId playerId) {
    return _controllers.remove(playerId) != null;
  }

  /// Gets controller.
  PlaybackController? controllerOf(PlayerId playerId) {
    return _controllers[playerId];
  }

  /// Executes playback command.
  Future<void> execute({required PlayerId playerId, required PlaybackCommand command}) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.execute(command);
  }

  /// Opens player playback session.
  Future<void> open({required PlayerId playerId, required SessionId sessionId}) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.open(sessionId);
  }

  /// Releases controller.
  void clear() {
    _controllers.clear();
  }

  /// Disposes coordinator.
  Future<void> dispose() async {
    clear();
  }
}
