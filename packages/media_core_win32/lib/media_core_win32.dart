/// Public library for the `media_core_win32` module.
///
/// Direct Win32 window-state operations (snapshot/restore, frameless bounds
/// moves, screen fullscreen) for the desktop presentations, bound through
/// dart:ffi so the fullscreen and PiP layers never depend on
/// window_manager's frameless fast path.
library;

export 'src/win32_window_ffi.dart';
