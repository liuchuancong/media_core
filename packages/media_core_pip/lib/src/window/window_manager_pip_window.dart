import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:media_core_pip/src/window/pip_window.dart';
import 'package:media_core_pip/src/window/win32_pip_window.dart' show Win32PipWindow;
import 'package:window_manager/window_manager.dart';

/// [PipWindow] for the window_manager backends: macOS and Linux.
///
/// The frameless fast path that makes plugin style APIs unreliable lives in
/// the plugin's *Windows* implementation only, so Windows hosts use
/// [Win32PipWindow] (direct user32 calls, see `defaultDesktopPipWindow`)
/// instead of this class. What remains here is the macOS/Linux sequence,
/// driven by the nativeapi `Window` (synchronous FFI, so every step applies
/// immediately):
///
/// - capture: bounds, always-on-top, resizability, taskbar visibility and
///   title through the window object;
/// - apply: hide the system title bar — with it, the resized window still
///   reads as "the whole app shrunk" instead of a picture-in-picture overlay
///   — then size, position, aspect-lock and taskbar state;
/// - restore: bring the normal chrome back before resizing, so the restored
///   window never flashes as a frameless rectangle.
final class WindowManagerPipWindow implements PipWindow {
  /// Stateless: every operation goes straight to the nativeapi `Window`, so
  /// one instance is as good as any other and the backend can be a const.
  const WindowManagerPipWindow();

  /// The current desktop window, or null outside a real desktop session
  /// (widget tests, mobile) — every operation then degrades to a no-op.
  Window? get _current => WindowManager.instance.getCurrent();

  @override
  Future<PipWindowSnapshot> capture() async {
    final window = _current;
    if (window == null) {
      return const PipWindowSnapshot(
        bounds: Rect.zero,
        alwaysOnTop: false,
        resizable: true,
        skipTaskbar: false,
        title: '',
      );
    }
    return PipWindowSnapshot(
      bounds: window.bounds.toRect(),
      alwaysOnTop: window.isAlwaysOnTop,
      resizable: window.isResizable,
      skipTaskbar: !window.isVisibleInTaskbar,
      title: window.title ?? '',
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
    final window = _current;
    if (window == null) {
      return;
    }
    window
      ..isAlwaysOnTop = alwaysOnTop
      ..isResizable = resizable
      // A null ratio means the host unlocked the shape. The OS aspect lock has
      // to be released explicitly (zero releases it), or a lock left by an
      // earlier locked session keeps fighting the viewer's resize.
      ..aspectRatio = aspectRatio ?? 0
      // Hide the system title bar before shrinking: the host's custom chrome
      // takes over visually the moment the window narrows.
      ..titleBarStyle = TitleBarStyle.hidden
      ..setSize(size.toNative(), false)
      ..position = position.toNative()
      ..isVisibleInTaskbar = !skipTaskbar;
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    final window = _current;
    if (window == null) {
      return;
    }
    window
      ..isAlwaysOnTop = snapshot.alwaysOnTop
      ..isResizable = snapshot.resizable
      ..isVisibleInTaskbar = !snapshot.skipTaskbar
      ..title = snapshot.title
      // Bring the normal chrome back before resizing, so the restored window
      // never flashes as a frameless rectangle.
      ..titleBarStyle = TitleBarStyle.normal
      ..bounds = snapshot.bounds.toNative();
  }

  @override
  Future<void> setAlwaysOnTop({required bool value}) async {
    final window = _current;
    if (window != null) {
      window.isAlwaysOnTop = value;
    }
  }

  @override
  Future<void> setMinimumSize(Size size) async {
    final window = _current;
    if (window != null) {
      window.minimumSize = size.toNative();
    }
  }

  @override
  Future<void> setAspectRatio(double aspectRatio) async {
    final window = _current;
    if (window != null) {
      window.aspectRatio = aspectRatio;
    }
  }

  @override
  Future<void> startDragging() async {
    final window = _current;
    if (window != null) {
      window.startDragging();
    }
  }
}
