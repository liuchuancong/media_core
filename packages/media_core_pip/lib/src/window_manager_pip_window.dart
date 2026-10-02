import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:window_manager/window_manager.dart';

import 'package:media_core_pip/src/pip_window.dart';

/// [PipWindow] for the window_manager backends: macOS and Linux.
///
/// The frameless fast path that makes plugin style APIs unreliable lives in
/// the plugin's *Windows* implementation only, so Windows hosts use
/// [Win32PipWindow] (direct user32 calls, see `defaultDesktopPipWindow`)
/// instead of this class. What remains here is the macOS/Linux sequence:
///
/// - capture: bounds, always-on-top, resizability, taskbar visibility and
///   title through the plugin;
/// - apply: release the minimum size first (macOS `contentMinSize` clamps
///   programmatic resizes too), hide the system title bar — with it, the
///   resized window still reads as "the whole app shrunk" instead of a
///   picture-in-picture overlay — then size, position, aspect-lock and
///   taskbar state;
/// - restore: bring the normal chrome back before resizing, so the restored
///   window never flashes as a frameless rectangle.
final class WindowManagerPipWindow implements PipWindow {
  const WindowManagerPipWindow();

  @override
  Future<PipWindowSnapshot> capture() async {
    final position = await windowManager.getPosition();
    final bounds = await windowManager.getBounds();
    return PipWindowSnapshot(
      bounds: Rect.fromLTWH(
        position.dx,
        position.dy,
        bounds.width,
        bounds.height,
      ),
      alwaysOnTop: await windowManager.isAlwaysOnTop(),
      resizable: await windowManager.isResizable(),
      skipTaskbar: await windowManager.isSkipTaskbar(),
      title: await windowManager.getTitle(),
    );
  }

  @override
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  }) async {
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    await windowManager.setResizable(resizable);
    if (aspectRatio != null) {
      await windowManager.setAspectRatio(aspectRatio);
    }
    // Hide the system title bar before shrinking: the host's custom chrome
    // takes over visually the moment the window narrows.
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(size);
    await windowManager.setPosition(position);
    await windowManager.setSkipTaskbar(skipTaskbar);
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    await windowManager.setAlwaysOnTop(snapshot.alwaysOnTop);
    await windowManager.setResizable(snapshot.resizable);
    await windowManager.setSkipTaskbar(snapshot.skipTaskbar);
    await windowManager.setTitle(snapshot.title);
    // Bring the normal chrome back before resizing, so the restored window
    // never flashes as a frameless rectangle.
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBounds(snapshot.bounds);
  }

  @override
  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);

  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  @override
  Future<void> startDragging() => windowManager.startDragging();
}
