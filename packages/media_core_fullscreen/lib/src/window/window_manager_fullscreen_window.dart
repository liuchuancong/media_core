import 'package:flutter/painting.dart' show Rect;
import 'package:media_core_fullscreen/src/window/fullscreen_window.dart';
import 'package:window_manager/window_manager.dart';

/// [FullscreenWindow] backed by `window_manager`'s nativeapi `Window`.
///
/// The nativeapi API is synchronous FFI, so every method resolves the window
/// once and applies the state directly; a missing desktop window (widget
/// tests, mobile) degrades to a no-op / default reading.
final class WindowManagerFullscreenWindow implements FullscreenWindow {
  Window? get _current => WindowManager.instance.getCurrent();

  @override
  Future<bool> get isFullscreen async => _current?.isFullScreen ?? false;

  @override
  Future<Rect> captureBounds() async {
    final window = _current;
    if (window == null) {
      return Rect.zero;
    }
    return window.bounds.toRect();
  }

  @override
  Future<void> setFullscreen({required bool value, Rect? restoreBounds}) async {
    final window = _current;
    if (window == null) {
      return;
    }
    window.isFullScreen = value;
    if (!value && restoreBounds != null) {
      window.bounds = restoreBounds.toNative();
    }
  }
}
