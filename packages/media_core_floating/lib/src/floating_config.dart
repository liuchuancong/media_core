import 'floating_window_placement.dart';

/// Behaviour of the in-app small window.
///
/// Geometry lives in [FloatingPlacementConfig]; this object holds what the
/// window *does* — whether the viewer can dismiss it, whether it offers a way
/// back to the page, and whether playback continues while it is hidden.
final class FloatingConfig {
  const FloatingConfig({
    this.placement = const FloatingPlacementConfig(),
    this.dismissible = true,
    this.showExpandControl = true,
    this.keepPlayingWhenHidden = true,
  });

  /// Caller-accepted defaults.
  static const FloatingConfig defaults = FloatingConfig();

  /// Where the window sits and how it is dragged.
  final FloatingPlacementConfig placement;

  /// Whether the window offers a close control.
  final bool dismissible;

  /// Whether the window offers a control that returns the video to the page.
  final bool showExpandControl;

  /// Whether playback continues after the small window is closed.
  ///
  /// On by default: the viewer collapsed the *window*, not the video, and a
  /// small window that silently stops the stream makes the main page look
  /// broken when they return to it.
  final bool keepPlayingWhenHidden;

  FloatingConfig copyWith({
    FloatingPlacementConfig? placement,
    bool? dismissible,
    bool? showExpandControl,
    bool? keepPlayingWhenHidden,
  }) {
    return FloatingConfig(
      placement: placement ?? this.placement,
      dismissible: dismissible ?? this.dismissible,
      showExpandControl: showExpandControl ?? this.showExpandControl,
      keepPlayingWhenHidden: keepPlayingWhenHidden ?? this.keepPlayingWhenHidden,
    );
  }
}
