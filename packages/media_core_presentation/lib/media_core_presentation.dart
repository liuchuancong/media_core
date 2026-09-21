/// Presentation capability for media_core.
///
/// Provides fullscreen, picture-in-picture and floating window
/// presentations with video-orientation awareness:
///
/// - landscape video → landscape fullscreen
/// - portrait video → portrait fullscreen (or rotated as configured)
/// - Windows: window_manager fullscreen + always-on-top floating
///   window used as PiP
/// - other platforms: capability stubs pending native integration
/// - overlay layer (danmaku / controls) with hover-based visibility
///   on desktop and always-visible behaviour on touch devices
///
/// Attach to a kernel:
///
/// ```dart
/// final presentation = MediaCorePresentation();
/// await presentation.initialize();
/// kernel.attachPresentation(presentation);
/// await kernel.enterFullscreen(playerId);
/// ```
library;

export 'src/kernel_presentation_adapter.dart';
export 'src/media_core_presentation.dart';
export 'src/presentation_capability_config.dart';
export 'src/widgets/player_overlay.dart';
export 'src/widgets/presentation_stage.dart';
