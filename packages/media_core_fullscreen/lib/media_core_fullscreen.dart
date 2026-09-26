/// Fullscreen for media_core, covering both variants:
///
/// ```text
/// PresentationMode.fullscreen        platform fullscreen (desktop window
///                                    covers the screen; mobile hides system UI)
/// PresentationMode.windowFullscreen  the video fills the app window while the
///                                    window stays a window
/// ```
///
/// The driver also answers which fit strategy the current video orientation
/// wants, so a host does not have to re-derive portrait/landscape rules.
library;

export 'package:media_core_fullscreen/src/fullscreen_config.dart';
export 'package:media_core_fullscreen/src/fullscreen_driver.dart';
export 'package:media_core_fullscreen/src/fullscreen_window.dart';
export 'package:media_core_fullscreen/src/window_manager_fullscreen_window.dart';
