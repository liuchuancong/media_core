import '../identity/player_id.dart';
import '../presentation/presentation_request.dart';
import '../presentation/presentation_controller.dart';

/// Coordinates player presentation.
///
/// [PresentationCoordinator] connects players
/// with presentation subsystem.
///
/// It does not:
///
/// - render widgets
/// - call platform presentation APIs
/// - manage windows
///
/// Those belong to:
///
/// - PlayerView
/// - PlatformPip
/// - PlatformSurface
final class PresentationCoordinator {
  /// Creates presentation coordinator.
  PresentationCoordinator();

  final Map<PlayerId, PresentationController> _controllers = {};

  /// Registers presentation controller.
  void register({required PlayerId playerId, required PresentationController controller}) {
    _controllers[playerId] = controller;
  }

  /// Removes presentation controller.
  bool unregister(PlayerId playerId) {
    return _controllers.remove(playerId) != null;
  }

  /// Gets presentation controller.
  PresentationController? controllerOf(PlayerId playerId) {
    return _controllers[playerId];
  }

  /// Applies presentation request.
  Future<void> present({required PlayerId playerId, required PresentationRequest request}) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.present(request);
  }

  /// Enters fullscreen.
  Future<void> fullscreen(PlayerId playerId) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.enterFullscreen();
  }

  /// Exits fullscreen.
  Future<void> exitFullscreen(PlayerId playerId) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.exitFullscreen();
  }

  /// Enters picture in picture.
  Future<void> enterPip(PlayerId playerId) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.enterPip();
  }

  /// Leaves picture in picture.
  Future<void> exitPip(PlayerId playerId) async {
    final controller = _controllers[playerId];

    if (controller == null) {
      return;
    }

    await controller.exitPip();
  }

  /// Clears bindings.
  void clear() {
    _controllers.clear();
  }

  /// Disposes coordinator.
  Future<void> dispose() async {
    clear();
  }
}
