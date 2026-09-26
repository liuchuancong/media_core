import 'package:flutter/painting.dart' show Rect;
import 'package:window_manager/window_manager.dart';

import 'fullscreen_window.dart';

/// [FullscreenWindow] backed by `window_manager`.
final class WindowManagerFullscreenWindow implements FullscreenWindow {
  @override
  Future<bool> get isFullscreen => windowManager.isFullScreen();

  @override
  Future<Rect> captureBounds() async {
    final position = await windowManager.getPosition();
    final bounds = await windowManager.getBounds();
    return Rect.fromLTWH(position.dx, position.dy, bounds.width, bounds.height);
  }

  @override
  Future<void> setFullscreen(bool value, {Rect? restoreBounds}) async {
    await windowManager.setFullScreen(value);
    if (!value && restoreBounds != null) {
      await windowManager.setBounds(restoreBounds);
    }
  }
}
