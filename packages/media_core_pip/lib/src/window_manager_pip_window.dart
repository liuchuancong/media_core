import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:media_core_win32/media_core_win32.dart';
import 'package:window_manager/window_manager.dart';

import 'package:media_core_pip/src/pip_window.dart';

/// [PipWindow] for desktop hosts.
///
/// On Windows every window-state change goes through direct user32 calls
/// ([Win32WindowFfi]) instead of `window_manager`'s style APIs: hosts that
/// create their window with a hidden title bar (a custom-drawn chrome) put
/// the plugin on a frameless fast path, after which its style and bounds
/// updates are silently skipped — a PiP transition through that path leaves
/// the window mis-sized with system chrome it never had. The custom-drawn
/// title bar is the host's own widget, so the native side never touches
/// title-bar styles at all; the window is moved with one atomic
/// `SetWindowPos` and restored from a placement snapshot taken at
/// [capture] time.
///
/// macOS and Linux keep the `window_manager` path: the frameless fast path
/// is a Windows-only behaviour. The seam (the [PipWindow] interface) stays
/// so the driver above can be tested without a window.
final class WindowManagerPipWindow implements PipWindow {
  static int? _hwnd;

  /// The native placement snapshot taken when PiP was entered; replayed on
  /// restore so any style the plugin changed while PiP was active is rewound.
  Win32WindowSnapshot? _nativeSnapshot;

  int get _windowHandle {
    if (_hwnd == null || _hwnd == 0) {
      _hwnd = Win32WindowFfi.mainWindowHandle();
    }
    return _hwnd ?? 0;
  }

  @override
  Future<PipWindowSnapshot> capture() async {
    Win32WindowSnapshot? native;
    var bounds = Rect.zero;
    var alwaysOnTop = false;

    if (Win32WindowFfi.isSupported) {
      final hwnd = _windowHandle;
      native = Win32WindowFfi.capture(hwnd);
      _nativeSnapshot = native;
      bounds = Win32WindowFfi.bounds(hwnd) ?? bounds;
      alwaysOnTop = Win32WindowFfi.isTopmost(hwnd);
    }

    if (bounds == Rect.zero) {
      final position = await windowManager.getPosition();
      final windowBounds = await windowManager.getBounds();
      bounds = Rect.fromLTWH(position.dx, position.dy, windowBounds.width, windowBounds.height);
    }

    return PipWindowSnapshot(
      bounds: bounds,
      alwaysOnTop: alwaysOnTop || await windowManager.isAlwaysOnTop(),
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
    // The pip driver already computes the small-window size from the video's
    // aspect ratio; a plugin-level aspect lock would route the resize back
    // through window_manager, so it is deliberately not applied on Windows.
    if (Win32WindowFfi.isSupported) {
      await windowManager.setSkipTaskbar(skipTaskbar);
      Win32WindowFfi.applyBounds(
        _windowHandle,
        Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
        topmost: alwaysOnTop,
      );
      return;
    }

    await windowManager.setTitle(title);
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    await windowManager.setResizable(resizable);
    if (aspectRatio != null) {
      await windowManager.setAspectRatio(aspectRatio);
    }
    // Hide the system title bar: with it, the resized window still reads as
    // "the whole app shrunk" instead of a picture-in-picture overlay. Hosts
    // that draw their own chrome never reach this line (see the class docs).
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(size);
    await windowManager.setPosition(position);
    await windowManager.setSkipTaskbar(skipTaskbar);
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    if (Win32WindowFfi.isSupported) {
      await windowManager.setSkipTaskbar(snapshot.skipTaskbar);
      await windowManager.setTitle(snapshot.title);
      await windowManager.setAlwaysOnTop(snapshot.alwaysOnTop);
      // Replay the placement (and any style bits) captured on entry. When no
      // native snapshot exists — PiP was entered before this window could be
      // captured — fall back to moving the window back bounds-only; styles
      // stay as they are rather than being guessed.
      final native = _nativeSnapshot ?? (Win32WindowFfi.isSupported ? Win32WindowFfi.capture(_windowHandle) : null);
      _nativeSnapshot = null;
      if (native != null) {
        Win32WindowFfi.restoreSnapshot(native);
      } else {
        Win32WindowFfi.applyBounds(_windowHandle, snapshot.bounds, topmost: snapshot.alwaysOnTop);
      }
      return;
    }

    await windowManager.setAlwaysOnTop(snapshot.alwaysOnTop);
    await windowManager.setResizable(snapshot.resizable);
    await windowManager.setSkipTaskbar(snapshot.skipTaskbar);
    await windowManager.setTitle(snapshot.title);
    // Bring the normal chrome back before resizing, so the restored window
    // never flashes as a frameless rectangle.
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBounds(snapshot.bounds);
  }
}
