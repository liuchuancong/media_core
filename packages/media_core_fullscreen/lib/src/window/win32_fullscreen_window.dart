import 'dart:async';

import 'package:flutter/painting.dart' show Rect;
import 'package:media_core_fullscreen/src/window/fullscreen_window.dart';
import 'package:media_core_win32/media_core_win32.dart';

/// [FullscreenWindow] implemented with direct user32 calls.
///
/// `window_manager`'s `setFullScreen` sits behind a frameless fast path for
/// hosts whose window is created with a hidden title bar: styles and bounds
/// updates are silently skipped while the call still reports success, so a
/// fullscreen transition through it does nothing the user can see. This
/// implementation follows the `fullscreen_window` plugin sequence instead —
/// snapshot the placement, strip the caption/thickframe bits, fill the
/// monitor the window is on with one `SetWindowPos(FRAMECHANGED)`, and on
/// exit restore the snapshot followed by a forced re-layout.
final class Win32FullscreenWindow implements FullscreenWindow {
  /// Creates the backend.
  ///
  /// [windowHandle] pins the top-level window to drive. A
  /// desktop_multi_window clone engine cannot use the process-wide lookup:
  /// it finds the runner's first window (the primary), so the clone would
  /// take the main window fullscreen instead of its own. The primary leaves
  /// this null and keeps the lookup.
  Win32FullscreenWindow({int? windowHandle}) : _hwnd = windowHandle;

  int? _hwnd;

  bool get _pinned => _hwnd != null;

  Win32WindowSnapshot? _snapshot;

  int get _windowHandle {
    final pinned = _hwnd;
    // A pinned zero means "this engine has no window to drive": answer 0 and
    // let every user32 call degrade, rather than falling back to the
    // process's first window — which belongs to the primary.
    if (pinned != null) {
      return pinned;
    }
    final found = Win32WindowFfi.mainWindowHandle();
    _hwnd = found;
    return found ?? 0;
  }

  @override
  Future<bool> get isFullscreen async => _snapshot != null;

  @override
  Future<Rect> captureBounds() async => Win32WindowFfi.bounds(_windowHandle) ?? Rect.zero;

  @override
  Future<void> setFullscreen({required bool value, Rect? restoreBounds}) async {
    if (_windowHandle == 0 && _pinned) {
      // A clone whose handle could not be read reaches here pinned to zero.
      // Failing keeps the host's presentation state truthful instead of
      // reporting a fullscreen window that never moved.
      throw StateError('The window to take fullscreen could not be found.');
    }
    if (value) {
      // Idempotent enter: a second fullscreen request must not overwrite the
      // pre-fullscreen snapshot with fullscreen-era bounds, or the exit would
      // restore the window to a fullscreen-sized rect.
      _snapshot ??= Win32WindowFfi.capture(_windowHandle);

      Win32WindowFfi.setScreenFullscreen(_windowHandle, fullscreen: true, snapshot: _snapshot);
      return;
    }

    final snapshot = _snapshot;
    _snapshot = null;
    if (snapshot != null) {
      Win32WindowFfi.setScreenFullscreen(_windowHandle, fullscreen: false, snapshot: snapshot);
      return;
    }

    // Fullscreen was never entered through this window: fall back to forcing
    // a re-layout so the caller's [restoreBounds] still lands cleanly.
    Win32WindowFfi.setScreenFullscreen(_windowHandle, fullscreen: false);
    if (restoreBounds != null) {
      Win32WindowFfi.applyBounds(_windowHandle, restoreBounds, topmost: false);
    }
  }
}
