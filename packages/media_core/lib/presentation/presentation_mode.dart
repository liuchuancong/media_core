/// Defines how media content is presented.
///
/// Presentation mode is independent from the media player.
///
/// A player can continue playing while moving between:
///
/// - normal view
/// - fullscreen
/// - picture-in-picture
/// - floating window
///
/// Platform implementations translate these abstract
/// modes into native APIs.
enum PresentationMode {
  /// Normal in-page presentation.
  normal,

  /// Fullscreen presentation.
  fullscreen,

  /// Picture-in-picture presentation.
  pip,

  /// Floating window presentation.
  floating,
}

extension PresentationModeExtension on PresentationMode {
  /// Whether this mode is normal playback.
  bool get isNormal => this == PresentationMode.normal;

  /// Whether this mode is fullscreen.
  bool get isFullscreen => this == PresentationMode.fullscreen;

  /// Whether this mode is PiP.
  bool get isPip => this == PresentationMode.pip;

  /// Whether this mode is floating window.
  bool get isFloating => this == PresentationMode.floating;

  /// Whether this mode requires an external window.
  bool get requiresExternalWindow => this == PresentationMode.pip || this == PresentationMode.floating;

  /// Whether this mode changes application layout.
  bool get changesLayout => this == PresentationMode.fullscreen || this == PresentationMode.floating;

  /// Human readable name.
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
