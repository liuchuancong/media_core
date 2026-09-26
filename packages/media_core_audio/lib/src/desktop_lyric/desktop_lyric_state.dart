/// Visual/textual properties of a desktop lyric overlay.
///
/// Style lives here because it has to *survive the window*: the host draws the
/// overlay with its own toolkit (a Win32 layered window, an Android
/// `TYPE_APPLICATION_OVERLAY` view), so the only thing this package can own is
/// the description of what should be shown and how.
final class DesktopLyricStyle {
  /// Creates a style.
  const DesktopLyricStyle({
    this.fontFamily,
    this.fontSize = 40,
    this.textColor = 0xFFFFFFFF,
    this.strokeColor = 0xFF000000,
    this.strokeWidth = 2,
    this.opacity = 1.0,
    this.alignment = DesktopLyricAlignment.center,
  });

  /// Font family, when the host can resolve one.
  final String? fontFamily;

  /// Font size in logical pixels.
  final double fontSize;

  /// Text colour as 0xAARRGGBB (overlay windows take platform colours, not
  /// Flutter `Color`s, and a host must not have to parse Flutter types).
  final int textColor;

  /// Outline colour as 0xAARRGGBB.
  final int strokeColor;

  /// Outline width in logical pixels.
  final double strokeWidth;

  /// Overlay opacity, 0.0–1.0.
  final double opacity;

  /// Horizontal anchoring of the text.
  final DesktopLyricAlignment alignment;

  /// Creates a copy with selected fields replaced.
  DesktopLyricStyle copyWith({
    Object? fontFamily = _sentinel,
    double? fontSize,
    int? textColor,
    int? strokeColor,
    double? strokeWidth,
    double? opacity,
    DesktopLyricAlignment? alignment,
  }) {
    return DesktopLyricStyle(
      fontFamily: identical(fontFamily, _sentinel) ? this.fontFamily : fontFamily as String?,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      alignment: alignment ?? this.alignment,
    );
  }

  /// Serializes for the platform channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (fontFamily != null) 'fontFamily': fontFamily,
      'fontSize': fontSize,
      'textColor': textColor,
      'strokeColor': strokeColor,
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'alignment': alignment.name,
    };
  }

  static const Object _sentinel = Object();
}

/// Horizontal anchoring of a desktop lyric line.
enum DesktopLyricAlignment {
  /// Left-aligned.
  left,

  /// Centered.
  center,

  /// Right-aligned.
  right,
}

/// What the overlay should display right now.
///
/// A full description rather than a delta: overlay windows live in another
/// process on Android (and another thread on Windows), where partial updates
/// are a source of visual desync. Sending the whole state costs nothing at a
/// few dozen bytes and makes the host trivially stateless.
final class DesktopLyricState {
  /// Creates a state.
  const DesktopLyricState({
    required this.text,
    this.translation,
    this.nextLine,
    this.progress = 0,
    this.playing = false,
    this.locked = false,
    this.clickThrough = true,
    this.visible = true,
    this.style = const DesktopLyricStyle(),
    this.hasLyrics = true,
  });

  /// Current line text.
  final String text;

  /// Current line translation, when available.
  final String? translation;

  /// The line after the current one, for a two-line overlay.
  final String? nextLine;

  /// Progress through the current line, 0.0–1.0.
  final double progress;

  /// Whether audio is playing (drives the host's play/pause glyph).
  final bool playing;

  /// Whether the overlay is locked (mouse input passes through).
  final bool locked;

  /// Whether the host should ignore pointer events.
  final bool clickThrough;

  /// Whether the overlay is visible.
  final bool visible;

  /// Styling.
  final DesktopLyricStyle style;

  /// Whether a lyric is loaded at all; when false the host shows its
  /// "no lyrics" placeholder instead of an empty box.
  final bool hasLyrics;

  /// Serializes for the platform channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'text': text,
      if (translation != null) 'translation': translation,
      if (nextLine != null) 'nextLine': nextLine,
      'progress': progress,
      'playing': playing,
      'locked': locked,
      'clickThrough': clickThrough,
      'visible': visible,
      'hasLyrics': hasLyrics,
      'style': style.toMap(),
    };
  }

  @override
  String toString() => 'DesktopLyricState("$text"${locked ? ', locked' : ''}${visible ? '' : ', hidden'})';
}
