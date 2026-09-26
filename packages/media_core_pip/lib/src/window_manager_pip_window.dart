import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:window_manager/window_manager.dart';

import 'pip_window.dart';

/// [PipWindow] backed by `window_manager`.
///
/// Desktop only. Every call goes through the plugin's global instance because
/// that is the only handle it exposes; the seam exists so the driver above it
/// can be tested without a window.
final class WindowManagerPipWindow implements PipWindow {
  @override
  Future<PipWindowSnapshot> capture() async {
    final position = await windowManager.getPosition();
    final bounds = await windowManager.getBounds();
    return PipWindowSnapshot(
      bounds: Rect.fromLTWH(position.dx, position.dy, bounds.width, bounds.height),
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
    await windowManager.setTitle(title);
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    await windowManager.setResizable(resizable);
    if (aspectRatio != null) {
      await windowManager.setAspectRatio(aspectRatio);
    }
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
    await windowManager.setBounds(snapshot.bounds);
  }
}
