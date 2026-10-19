import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_core_pip/src/driver/pip_driver.dart' show PipDriver;
import 'package:media_core_pip/src/window/pip_window.dart';
import 'package:media_core_pip/src/window/win32_pip_window.dart';
import 'package:media_core_pip/src/window/window_manager_pip_window.dart';

/// Builds the best [PipWindow] backend for the host platform.
///
/// - **every desktop platform** — [WindowManagerPipWindow], now backed by
///   `window_frame_kit`: one plugin whose C++ window procedure owns the
///   frameless window *and* native edge resizing, which removes the
///   frameless fast path that used to make the old plugin silently skip
///   style and bounds updates on Windows — the exact defect [Win32PipWindow]
///   worked around with direct user32 calls. The kit fixes the cause, so
///   one backend serves all three desktops, and a compact window gains
///   native edge resizing for free.
/// - **legacy** — [Win32PipWindow] stays available for a host that wants the
///   proven user32 path (pass it explicitly); it is no longer the default
///   and no longer reached from here.
/// - **anything else** — [UnsupportedError]: a desktop small window needs a
///   real window to shrink; mobile platforms are served by the system-PiP
///   path ([PipDriver]'s mobile branch), and iOS has no system PiP API
///   reachable for arbitrary Flutter content at all.
///
/// The platform flags are injectable so the selection is testable on every
/// host.
PipWindow defaultDesktopPipWindow({bool? isWindows, bool? isMacOS, bool? isLinux}) {
  final windows = isWindows ?? (!kIsWeb && Platform.isWindows);
  final macos = isMacOS ?? (!kIsWeb && Platform.isMacOS);
  final linux = isLinux ?? (!kIsWeb && Platform.isLinux);

  if (windows || macos || linux) {
    return const WindowManagerPipWindow();
  }
  throw UnsupportedError('Desktop picture-in-picture needs Windows, macOS or Linux.');
}
