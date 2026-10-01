import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:media_core_win32/media_core_win32.dart';

import 'package:media_core_pip/src/pip_window.dart';

/// [PipWindow] implemented with direct user32 calls — no plugin, no channel.
///
/// `window_manager`'s style APIs are unreliable for hosts that create their
/// window with a hidden title bar (a custom-drawn chrome): the plugin puts
/// such windows on a frameless fast path, after which its style and bounds
/// updates are silently skipped while still reporting success, so a PiP
/// transition through it leaves the window mis-sized with chrome it never
/// had. Every operation here therefore goes through [Win32WindowFfi], which
/// follows the sequence proven by the `fullscreen_window` plugin and the
/// `window_manager` sources themselves —
///
/// - skip taskbar: the `WS_EX_TOOLWINDOW` bit (what `set_skip_taskbar.cpp`
///   does), so the compact window leaves both the taskbar and Alt-Tab;
/// - resizable: the `WS_THICKFRAME` style bit, dropped while compact;
/// - top-most: `SetWindowPos` against `HWND_TOPMOST` (via `applyBounds`);
/// - move + resize: one atomic `SetWindowPos` that also carries
///   `SWP_FRAMECHANGED` so style and bounds land together;
/// - restore: a placement snapshot (style/ex-style/placement) captured at
///   [capture] time and replayed, followed by a forced re-layout.
///
/// The custom-drawn chrome is the host's widget, so nothing here touches
/// title-bar styles; the snapshot replays whatever the window had. There is
/// no minimum-size concept in this backend — dropping `WS_THICKFRAME` already
/// prevents user resizes — so [setMinimumSize] is a documented no-op.
final class Win32PipWindow implements PipWindow {
  static int? _hwnd;

  Win32WindowSnapshot? _nativeSnapshot;

  int get _windowHandle {
    if (_hwnd == null || _hwnd == 0) {
      _hwnd = Win32WindowFfi.mainWindowHandle();
    }
    return _hwnd ?? 0;
  }

  @override
  Future<PipWindowSnapshot> capture() async {
    final hwnd = _windowHandle;
    final native = Win32WindowFfi.capture(hwnd);
    _nativeSnapshot = native;
    final bounds = Win32WindowFfi.bounds(hwnd) ?? Rect.zero;

    // A snapshot is the authoritative restore source; the readable fields
    // double as the honest pre-PiP state for hosts that log or merge it.
    return PipWindowSnapshot(
      bounds: bounds,
      alwaysOnTop: Win32WindowFfi.isTopmost(hwnd),
      resizable: Win32WindowFfi.isResizable(hwnd),
      skipTaskbar: Win32WindowFfi.isSkipTaskbar(hwnd),
      title: Win32WindowFfi.windowTitle(hwnd),
      titleBarStyle: native,
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
    final hwnd = _windowHandle;
    // The driver already sizes the window from the video's shape; an
    // OS-level aspect lock would fight that resize on the next size report,
    // so [aspectRatio] is deliberately not applied here.
    Win32WindowFfi.setResizable(hwnd, resizable: resizable);
    Win32WindowFfi.setSkipTaskbar(hwnd, skip: skipTaskbar);
    Win32WindowFfi.applyBounds(
      hwnd,
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
      topmost: alwaysOnTop,
    );
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    final hwnd = _windowHandle;
    final native =
        _nativeSnapshot ??
        (snapshot.titleBarStyle is Win32WindowSnapshot
            ? snapshot.titleBarStyle as Win32WindowSnapshot
            : null);
    _nativeSnapshot = null;

    if (native != null) {
      // Replays placement and every style bit captured on entry — bounds,
      // resizable, skip-taskbar and top-most included — in one sequence.
      Win32WindowFfi.restoreSnapshot(native);
      return;
    }

    // PiP was entered before this window could capture a snapshot: fall back
    // to moving the window back bounds-only. Styles stay as they are rather
    // than being guessed.
    Win32WindowFfi.setSkipTaskbar(hwnd, skip: snapshot.skipTaskbar);
    Win32WindowFfi.setResizable(hwnd, resizable: snapshot.resizable);
    Win32WindowFfi.applyBounds(
      hwnd,
      snapshot.bounds,
      topmost: snapshot.alwaysOnTop,
    );
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    // Bounds stay untouched: only the z-order moves.
    Win32WindowFfi.setTopmost(_windowHandle, topmost: value);
  }

  @override
  Future<void> setMinimumSize(Size size) async {
    // No minimum-size concept: a compact window without WS_THICKFRAME cannot
    // be resized by the user in the first place.
  }
}
