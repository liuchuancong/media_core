/// Picture-in-picture for media_core.
///
/// One feature, two platform families behind one contract:
///
/// ```text
/// desktop → an always-on-top, aspect-locked small window (window_manager)
/// mobile  → the platform's own PiP window (Android, via the floating plugin)
/// ```
///
/// Install it as part of a [PresentationDriverChain] so the presentation state
/// machine can route PiP requests here and route fullscreen or the in-app small
/// window elsewhere.
library;

export 'src/floating_system_pip.dart';
export 'src/pip_config.dart';
export 'src/pip_controller.dart';
export 'src/pip_driver.dart';
export 'src/pip_window.dart';
export 'src/system_pip.dart';
export 'src/window_manager_pip_window.dart';
