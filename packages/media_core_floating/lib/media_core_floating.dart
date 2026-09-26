/// In-app small window for media_core.
///
/// A video surface that floats inside the application, above the current page:
/// it follows the video's shape, can be dragged, snaps to an edge, and is
/// dismissed or expanded back to the page.
///
/// ```dart
/// Stack(
///   children: [
///     page,
///     FloatingWindowOverlay(
///       visible: driver.onFloatingChanged,
///       initiallyVisible: driver.isFloating,
///       videoWidth: driver.videoWidth,
///       videoHeight: driver.videoHeight,
///       onExpand: () => kernel.exitFloating(playerId),
///       child: Video(player: player, controller: controller),
///     ),
///   ],
/// )
/// ```
///
/// There is no platform branching here because there is nothing
/// platform-specific about a widget above a page: the same code serves Android,
/// iOS, desktop and web. A separate operating-system window is picture-in-
/// picture, and that is `media_core_pip`.
library;

export 'src/floating_config.dart';
export 'src/floating_driver.dart';
export 'src/floating_window_overlay.dart';
export 'src/floating_window_placement.dart';
export 'src/floating_window_presenter.dart';
