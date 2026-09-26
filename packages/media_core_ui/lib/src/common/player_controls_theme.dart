import 'package:flutter/widgets.dart';

import 'player_controls_style.dart';

/// Colors and metrics of a control set.
///
/// A theme holds the tokens a style needs, and nothing else: no widget decides
/// its own colors, so a host that wants a branded player overrides the theme
/// instead of forking a style. The named constructors are the conventions each
/// platform expects — for example the hairline bar of [PlayerControlsTheme.ios]
/// against the thick one of [PlayerControlsTheme.android].
final class PlayerControlsTheme {
  /// Creates a theme.
  const PlayerControlsTheme({
    required this.foreground,
    required this.foregroundMuted,
    required this.scrim,
    required this.accent,
    required this.progressTrack,
    required this.progressBuffered,
    required this.progressPlayed,
    required this.progressThumb,
    required this.iconSize,
    required this.primaryIconSize,
    required this.compactIconSize,
    required this.trackHeight,
    required this.trackHeightWhileDragging,
    required this.thumbRadius,
    required this.contentPadding,
    required this.barGap,
    required this.controlButtonRadius,
    required this.titleTextStyle,
    required this.timeTextStyle,
    required this.hideDelay,
    this.hoverHighlight,
  });

  /// iOS conventions: hairline bar, thin glyphs, a soft gradient scrim.
  const PlayerControlsTheme.ios()
    : foreground = const Color(0xFFFFFFFF),
      foregroundMuted = const Color(0xB3FFFFFF),
      scrim = const Color(0x00000000),
      accent = const Color(0xFFFFFFFF),
      progressTrack = const Color(0x4DFFFFFF),
      progressBuffered = const Color(0x80FFFFFF),
      progressPlayed = const Color(0xFFFFFFFF),
      progressThumb = const Color(0xFFFFFFFF),
      iconSize = 22,
      primaryIconSize = 48,
      compactIconSize = 18,
      trackHeight = 2.5,
      trackHeightWhileDragging = 5.5,
      thumbRadius = 7,
      contentPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      barGap = 10,
      controlButtonRadius = 22,
      titleTextStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
      timeTextStyle = const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xCCFFFFFF)),
      hideDelay = const Duration(seconds: 4),
      hoverHighlight = null;

  /// Material conventions: a solid scrim, a thick bar with a visible thumb.
  const PlayerControlsTheme.android()
    : foreground = const Color(0xFFFFFFFF),
      foregroundMuted = const Color(0xB3FFFFFF),
      scrim = const Color(0x99000000),
      accent = const Color(0xFFFF0033),
      progressTrack = const Color(0x40FFFFFF),
      progressBuffered = const Color(0x66FFFFFF),
      progressPlayed = const Color(0xFFFF0033),
      progressThumb = const Color(0xFFFF0033),
      iconSize = 24,
      primaryIconSize = 44,
      compactIconSize = 20,
      trackHeight = 4,
      trackHeightWhileDragging = 6,
      thumbRadius = 9,
      contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      barGap = 8,
      controlButtonRadius = 24,
      titleTextStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
      timeTextStyle = const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xE6FFFFFF)),
      hideDelay = const Duration(seconds: 3),
      hoverHighlight = null;

  /// Desktop conventions: a compact bar that thickens under the pointer.
  const PlayerControlsTheme.windows()
    : foreground = const Color(0xFFF2F2F2),
      foregroundMuted = const Color(0xB3F2F2F2),
      scrim = const Color(0xCC000000),
      accent = const Color(0xFF4CC2FF),
      progressTrack = const Color(0x40FFFFFF),
      progressBuffered = const Color(0x59FFFFFF),
      progressPlayed = const Color(0xFF4CC2FF),
      progressThumb = const Color(0xFFF2F2F2),
      iconSize = 16,
      primaryIconSize = 26,
      compactIconSize = 14,
      trackHeight = 3,
      trackHeightWhileDragging = 5,
      thumbRadius = 6,
      contentPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      barGap = 6,
      controlButtonRadius = 4,
      titleTextStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFF2F2F2)),
      timeTextStyle = const TextStyle(fontSize: 12, color: Color(0xCCF2F2F2)),
      hideDelay = const Duration(seconds: 2),
      hoverHighlight = const Color(0x29FFFFFF);

  /// Theme matching [style].
  factory PlayerControlsTheme.of(PlayerControlsStyle style) {
    return switch (style) {
      PlayerControlsStyle.ios => const PlayerControlsTheme.ios(),
      PlayerControlsStyle.android => const PlayerControlsTheme.android(),
      PlayerControlsStyle.windows => const PlayerControlsTheme.windows(),
    };
  }

  /// Primary text and glyph color.
  final Color foreground;

  /// Secondary text and inactive glyph color.
  final Color foregroundMuted;

  /// Backdrop behind the bars.
  final Color scrim;

  /// Progress and active-state color.
  final Color accent;

  /// Unplayed part of the progress track.
  final Color progressTrack;

  /// Buffered part of the progress track.
  final Color progressBuffered;

  /// Played part of the progress track.
  final Color progressPlayed;

  /// Progress thumb.
  final Color progressThumb;

  /// Size of a regular control glyph.
  final double iconSize;

  /// Size of the primary (play/pause) glyph.
  final double primaryIconSize;

  /// Size of a glyph in a dense row (desktop).
  final double compactIconSize;

  /// Height of the progress track at rest.
  final double trackHeight;

  /// Height of the progress track while a drag is in progress.
  final double trackHeightWhileDragging;

  /// Radius of the progress thumb.
  final double thumbRadius;

  /// Padding inside the bars.
  final EdgeInsets contentPadding;

  /// Vertical gap between bar rows.
  final double barGap;

  /// Corner radius of a control button's highlight.
  final double controlButtonRadius;

  /// Text style of the title.
  final TextStyle titleTextStyle;

  /// Text style of the time labels.
  final TextStyle timeTextStyle;

  /// How long the controls stay on screen after the last interaction.
  final Duration hideDelay;

  /// Highlight painted under a hovered control; null disables it.
  ///
  /// Desktop only: touch styles answer a press with a ripple or an opacity
  /// change instead.
  final Color? hoverHighlight;

  /// Whether the theme paints a hover highlight.
  bool get hasHoverHighlight => hoverHighlight != null;

  /// The theme's hide delay, unless the host asked for another one.
  Duration hideDelayOr(Duration? override) => override ?? hideDelay;

  /// Creates a modified theme.
  PlayerControlsTheme copyWith({
    Color? foreground,
    Color? foregroundMuted,
    Color? scrim,
    Color? accent,
    Color? progressTrack,
    Color? progressBuffered,
    Color? progressPlayed,
    Color? progressThumb,
    double? iconSize,
    double? primaryIconSize,
    double? compactIconSize,
    double? trackHeight,
    double? trackHeightWhileDragging,
    double? thumbRadius,
    EdgeInsets? contentPadding,
    double? barGap,
    double? controlButtonRadius,
    TextStyle? titleTextStyle,
    TextStyle? timeTextStyle,
    Duration? hideDelay,
    Color? hoverHighlight,
  }) {
    return PlayerControlsTheme(
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      scrim: scrim ?? this.scrim,
      accent: accent ?? this.accent,
      progressTrack: progressTrack ?? this.progressTrack,
      progressBuffered: progressBuffered ?? this.progressBuffered,
      progressPlayed: progressPlayed ?? this.progressPlayed,
      progressThumb: progressThumb ?? this.progressThumb,
      iconSize: iconSize ?? this.iconSize,
      primaryIconSize: primaryIconSize ?? this.primaryIconSize,
      compactIconSize: compactIconSize ?? this.compactIconSize,
      trackHeight: trackHeight ?? this.trackHeight,
      trackHeightWhileDragging: trackHeightWhileDragging ?? this.trackHeightWhileDragging,
      thumbRadius: thumbRadius ?? this.thumbRadius,
      contentPadding: contentPadding ?? this.contentPadding,
      barGap: barGap ?? this.barGap,
      controlButtonRadius: controlButtonRadius ?? this.controlButtonRadius,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      timeTextStyle: timeTextStyle ?? this.timeTextStyle,
      hideDelay: hideDelay ?? this.hideDelay,
      hoverHighlight: hoverHighlight ?? this.hoverHighlight,
    );
  }
}
