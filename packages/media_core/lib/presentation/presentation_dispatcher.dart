import 'pip_controller.dart';
import 'presentation_mode.dart';
import 'floating_controller.dart';
import 'presentation_request.dart';
import 'fullscreen_controller.dart';

/// Dispatches presentation requests to specialized controllers.
///
/// Responsibilities:
///
/// - route fullscreen requests
/// - route PiP requests
/// - route floating requests
///
/// Does not:
///
/// - manage presentation state
/// - call native APIs
/// - decide policies
///
/// Lifecycle state is owned by:
///
/// - PresentationController
///
/// Platform operations are owned by:
///
/// - platform adapters
final class PresentationDispatcher {
  const PresentationDispatcher({this.fullscreenController, this.pipController, this.floatingController});

  /// Fullscreen controller.
  final FullscreenController? fullscreenController;

  /// Picture-in-picture controller.
  final PipController? pipController;

  /// Floating window controller.
  final FloatingController? floatingController;

  /// Dispatches a presentation request.
  Future<void> dispatch(PresentationRequest request) async {
    switch (request.mode) {
      case PresentationMode.normal:
        await exit();
        break;

      case PresentationMode.fullscreen:
        await enterFullscreen();
        break;

      case PresentationMode.pip:
        await enterPip();
        break;

      case PresentationMode.floating:
        await enterFloating();
        break;
    }
  }

  /// Enters fullscreen.
  Future<void> enterFullscreen() async {
    final controller = fullscreenController;

    if (controller == null) {
      throw StateError('Fullscreen controller is not available.');
    }

    await controller.enter();
  }

  /// Exits fullscreen.
  Future<void> exitFullscreen() async {
    final controller = fullscreenController;

    if (controller == null) {
      return;
    }

    await controller.exit();
  }

  /// Enters PiP.
  Future<void> enterPip() async {
    final controller = pipController;

    if (controller == null) {
      throw StateError('PiP controller is not available.');
    }

    await controller.enter();
  }

  /// Exits PiP.
  Future<void> exitPip() async {
    final controller = pipController;

    if (controller == null) {
      return;
    }

    await controller.exit();
  }

  /// Enters floating mode.
  Future<void> enterFloating() async {
    final controller = floatingController;

    if (controller == null) {
      throw StateError('Floating controller is not available.');
    }

    await controller.enter();
  }

  /// Exits floating mode.
  Future<void> exitFloating() async {
    final controller = floatingController;

    if (controller == null) {
      return;
    }

    await controller.exit();
  }

  /// Exits all presentation modes.
  Future<void> exit() async {
    await Future.wait([exitFullscreen(), exitPip(), exitFloating()]);
  }

  /// Whether fullscreen controller exists.
  bool get supportsFullscreen => fullscreenController != null;

  /// Whether PiP controller exists.
  bool get supportsPip => pipController != null;

  /// Whether floating controller exists.
  bool get supportsFloating => floatingController != null;
}
