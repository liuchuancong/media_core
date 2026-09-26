import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Visual language of a control set.
///
/// The three sets share one control layer (state, actions, visibility) and
/// differ in what they show and how it behaves, because that is the difference
/// a user actually notices:
///
/// - [ios] follows the AVPlayer conventions: a large centred play button,
///   remaining time counting down, a hairline progress bar that thickens while
///   dragging, and no volume slider (volume belongs to the hardware buttons).
/// - [android] follows Material: a top app bar with the title and an overflow
///   menu, a filled play button, a thick slider with a visible thumb, ripple
///   feedback, and again no volume slider.
/// - [windows] follows desktop players: controls revealed by the pointer,
///   compact icons with tooltips, a window-level menu, a volume slider, and
///   keyboard shortcuts.
///
/// Responsibilities:
///
/// - name a visual language
/// - resolve the language a platform expects
///
/// It does not:
///
/// - hold colors or sizes ([PlayerControlsTheme] does)
/// - build widgets (each set does)
enum PlayerControlsStyle {
  /// iOS / iPadOS / macOS conventions.
  ios,

  /// Android and Material conventions.
  android,

  /// Desktop window-player conventions.
  windows;

  /// Style a platform expects.
  static PlayerControlsStyle forPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => PlayerControlsStyle.ios,
      TargetPlatform.android || TargetPlatform.fuchsia => PlayerControlsStyle.android,
      TargetPlatform.windows || TargetPlatform.linux => PlayerControlsStyle.windows,
    };
  }

  /// Style for the current platform.
  ///
  /// Web is reported as [windows]: a browser is driven by a pointer and a
  /// keyboard even when the device under it is a phone.
  static PlayerControlsStyle resolve([TargetPlatform? platform]) {
    if (kIsWeb && platform == null) {
      return PlayerControlsStyle.windows;
    }

    return forPlatform(platform ?? defaultTargetPlatform);
  }

  /// Whether the style is driven by touch.
  bool get isTouch => this != PlayerControlsStyle.windows;

  /// Whether the pointer is what reveals the controls.
  bool get revealsOnHover => this == PlayerControlsStyle.windows;

  /// Whether the style offers a volume slider.
  ///
  /// Touch platforms do not: their volume is the device's, changed with the
  /// hardware buttons, and a slider inside the player would fight it.
  bool get showsVolumeSlider => this == PlayerControlsStyle.windows;

  /// Whether the style keeps controls on screen while playback is paused.
  bool get keepsControlsWhilePaused => true;
}
