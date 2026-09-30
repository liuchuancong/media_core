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

export 'package:media_core_presentation/src/kernel_presentation_adapter.dart';
export 'package:media_core_presentation/src/media_core_presentation.dart';
export 'package:media_core_presentation/src/presentation_capability_config.dart';
export 'package:media_core_presentation/src/widgets/player_overlay.dart';
export 'package:media_core_presentation/src/widgets/presentation_stage.dart';
export 'package:media_core_presentation/src/video_presentation_geometry.dart';
