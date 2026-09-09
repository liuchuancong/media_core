/// Defines how the player presentation is displayed.
///
/// Presentation mode is independent from
/// the underlying media playback state.
///
/// A player can continue playing while switching
/// between different presentation modes.
enum PresentationMode {
  /// Normal in-page presentation.
  ///
  /// The player is displayed inside
  /// the normal application layout.
  normal,

  /// Fullscreen presentation.
  ///
  /// The player occupies the fullscreen area.
  fullscreen,

  /// Picture-in-picture presentation.
  ///
  /// The player is displayed in a native PiP window.
  pip,

  /// Floating window presentation.
  ///
  /// The player is displayed above
  /// normal application content.
  floating,
}

/// Extension helpers for PresentationMode.
extension PresentationModeExtension on PresentationMode {
  /// Whether this mode is fullscreen.
  bool get isFullscreen => this == PresentationMode.fullscreen;

  /// Whether this mode is PiP.
  bool get isPip => this == PresentationMode.pip;

  /// Whether this mode is floating.
  bool get isFloating => this == PresentationMode.floating;

  /// Whether this mode is normal.
  bool get isNormal => this == PresentationMode.normal;

  /// Whether this mode requires
  /// a separate presentation surface.
  bool get requiresExternalSurface {
    switch (this) {
      case PresentationMode.normal:
        return false;

      case PresentationMode.fullscreen:
      case PresentationMode.pip:
      case PresentationMode.floating:
        return true;
    }
  }

  /// Display name.
  String get name {
    switch (this) {
      case PresentationMode.normal:
        return 'normal';

      case PresentationMode.fullscreen:
        return 'fullscreen';

      case PresentationMode.pip:
        return 'pip';

      case PresentationMode.floating:
        return 'floating';
    }
  }
}
