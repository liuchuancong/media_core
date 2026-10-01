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
    final bounds = Win32WindowFfi.bounds(hwnd) ?? Rect.zero;

    // Purely read-only: the native snapshot travels inside the returned
    // PipWindowSnapshot, so the caller that captured the *normal* state is
    // the one whose snapshot a later restore() replays. Caching the latest
    // capture here instead made the exit path's own capture (taken to enable
    // rollback) overwrite the entry snapshot — and restore then replayed the
    // compact window back, leaving a shrunken, taskbar-less, black window.
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
    // Only the snapshot the caller captured at entry is authoritative. A
    // snapshot captured *while compact* (the rollback helper does exactly
    // that) must never win, or restore replays the compact window back.
    final native = snapshot.titleBarStyle is Win32WindowSnapshot
        ? snapshot.titleBarStyle as Win32WindowSnapshot
        : null;

    if (native != null) {
      // Replays placement and every style bit captured on entry — bounds,
      // resizable, skip-taskbar and top-most included — in one sequence.
      Win32WindowFfi.restoreSnapshot(native);
      return;
    }

    // No native snapshot travels with this snapshot (captured by another
    // backend, or the handle was gone): reconstruct from the readable fields.
    // Styles are re-stated rather than guessed, and the title needs no
    // restore because the compact window never changed it.
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
