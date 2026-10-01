/// Picture-in-picture for media_core.
///
/// One feature, one contract, three platform families behind it:
///
/// ```text
/// desktop → an always-on-top, aspect-shaped small window
///   Windows    → Win32PipWindow (direct user32 calls, no plugin)
///   macOS/Linux→ WindowManagerPipWindow (the window_manager plugin)
///   selection  → defaultDesktopPipWindow(), injectable per host
/// android → the platform's own PiP window (FloatingSystemPip)
/// iOS     → no system PiP API is reachable for arbitrary Flutter content,
///           so availability reports false instead of pretending
/// ```
///
/// [DisplayAwarePipWindow] layers the desktop placement policy (multi-
/// monitor awareness, remembered bounds, minimum-size release, rollback)
/// over whichever [PipWindow] backend the host picked.
///
/// Install it as part of a [PresentationDriverChain] so the presentation state
/// machine can route PiP requests here and route fullscreen or the in-app small
/// window elsewhere.
library;

export 'package:media_core_pip/src/desktop_pip_window.dart';
export 'package:media_core_pip/src/display_pip_window.dart';
export 'package:media_core_pip/src/floating_system_pip.dart';
export 'package:media_core_pip/src/pip_config.dart';
export 'package:media_core_pip/src/pip_controller.dart';
export 'package:media_core_pip/src/pip_driver.dart';
export 'package:media_core_pip/src/pip_window.dart';
export 'package:media_core_pip/src/system_pip.dart';
export 'package:media_core_pip/src/win32_pip_window.dart';
export 'package:media_core_pip/src/window_manager_pip_window.dart';
