// GENERATED MODULE LIBRARY - DO NOT EDIT.

/// Public library for the `media_core_ui` package.
///
/// Player UI for media_core: iOS, Android and desktop control sets over one
/// shared control layer.
///
/// The package is split in two halves:
///
/// * `src/common` — what every style needs: the controller that mirrors a
///   [PlayerHandle] and owns the controls' visibility, the theme tokens, the
///   timeline (progress bar + time labels), the control button, the keyboard
///   map and the stage that stacks the bars over the video.
/// * `src/ios`, `src/android`, `src/windows` — one control set each. A set is
///   stateless: it renders the controller's state and calls its actions.
///
/// A host normally uses [MediaCorePlayerView], which assembles video, controls,
/// gestures and keyboard with the style its platform expects:
///
/// ```dart
/// MediaCorePlayerView(
///   handle: handle,
///   actions: KernelPlayerControlActions(kernel: kernel, playerId: handle.id),
/// )
/// ```
///
/// The pieces are public so a host can also use them separately: a custom bar
/// can be built on [PlayerControlsController] + [PlayerControlsTheme] alone, and
/// a single style set can be dropped into a layout the host already owns.
library;

// ============================================================================
// Public exports
// ============================================================================

export 'src/android/android_player_controls.dart';
export 'src/common/player_control_actions.dart';
export 'src/common/player_control_buttons.dart';
export 'src/common/player_controls_controller.dart';
export 'src/common/player_controls_stage.dart';
export 'src/common/player_controls_style.dart';
export 'src/common/player_controls_theme.dart';
export 'src/common/player_progress_bar.dart';
export 'src/ios/ios_player_controls.dart';
export 'src/media_core_player_view.dart';
export 'src/windows/windows_player_controls.dart';
