import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';

import 'player_controls_controller.dart';
import 'player_controls_theme.dart';
import 'player_progress_bar.dart';

/// A control glyph that answers a press the way its style does.
///
/// The three sets differ in feedback, not only in looks: Material answers with
/// a ripple, iOS with an opacity dip, desktop with a hover highlight. Keeping
/// that here means a bar composes buttons instead of re-implementing the
/// interaction, and a host that mixes styles gets each one's own response.
///
/// Responsibilities:
///
/// - draw one glyph
/// - answer press, hover and disabled states per style
///
/// It does not:
///
/// - know what the button does (the caller passes the callback)
/// - hold playback state
final class PlayerIconButton extends StatefulWidget {
  /// Creates a control button.
  const PlayerIconButton({
    required this.icon,
    required this.theme,
    super.key,
    this.onPressed,
    this.size,
    this.color,
    this.tooltip,
    this.semanticLabel,
    this.active = false,
    this.ripple = false,
    this.padding = const EdgeInsets.all(6),
  });

  /// Glyph to draw.
  final IconData icon;

  /// Colors and metrics.
  final PlayerControlsTheme theme;

  /// Action; null renders the button disabled.
  final VoidCallback? onPressed;

  /// Glyph size; defaults to the theme's regular icon size.
  final double? size;

  /// Glyph color; defaults to the theme's foreground.
  final Color? color;

  /// Tooltip text.
  ///
  /// Desktop conventions expect one on every control; touch styles usually
  /// have none, and passing null on them is the honest default.
  final String? tooltip;

  /// Accessibility label, when [tooltip] is not enough.
  final String? semanticLabel;

  /// Whether the control reads as "on" (loop enabled, muted, …).
  final bool active;

  /// Whether a press paints a ripple.
  ///
  /// Material and desktop both support one; the desktop styles in this package
  /// prefer a hover highlight, which is what a mouse user expects.
  final bool ripple;

  /// Padding around the glyph.
  final EdgeInsets padding;

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

final class _PlayerIconButtonState extends State<PlayerIconButton> {
  bool _hovering = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  Color get _color {
    if (!_enabled) {
      return widget.theme.foregroundMuted.withValues(alpha: 0.5);
    }

    if (widget.active) {
      return widget.theme.accent;
    }

    return widget.color ?? widget.theme.foreground;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? widget.theme.iconSize;

    Widget glyph = Icon(widget.icon, size: size, color: _color);

    if (widget.semanticLabel != null) {
      glyph = Semantics(label: widget.semanticLabel, button: true, child: glyph);
    }

    final highlight = widget.theme.hoverHighlight;

    Widget button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: highlight == null ? null : (_) => setState(() => _hovering = true),
      onExit: highlight == null ? null : (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _enabled && _hovering && highlight != null ? highlight : const Color(0x00000000),
            borderRadius: BorderRadius.circular(widget.theme.controlButtonRadius),
          ),
          // Opacity is the touch-style feedback: a tap that changes nothing
          // visible reads as a dead button.
          child: _enabled && _pressed ? Opacity(opacity: 0.55, child: glyph) : glyph,
        ),
      ),
    );

    if (widget.ripple) {
      // A ripple needs a Material ancestor; any widget can provide one without
      // affecting the layout it sits in.
      button = Material(type: MaterialType.transparency, child: button);
    }

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Progress bar plus the two time labels, laid out the way a bar wants.
///
/// The labels move during a drag because they read the same preview the bar
/// reports: a viewer dragging on a phone cannot see the thumb under their
/// finger, so the text is the feedback.
final class PlayerTimeline extends StatefulWidget {
  /// Creates a timeline row.
  const PlayerTimeline({
    required this.controller,
    required this.theme,
    super.key,
    this.showRemaining = false,
    this.padding,
    this.barHeight,
    this.hoverable = false,
    this.spacing,
    this.leading,
  });

  /// Controller whose player this timeline drives.
  final PlayerControlsController controller;

  /// Colors and metrics.
  final PlayerControlsTheme theme;

  /// Whether the right label counts down instead of showing the duration.
  ///
  /// iOS convention; desktop conventions show the total.
  final bool showRemaining;

  /// Padding around the row.
  final EdgeInsets? padding;

  /// Height of the bar's hit area.
  final double? barHeight;

  /// Whether the bar thickens under the pointer.
  final bool hoverable;

  /// Gap between a label and the bar.
  final double? spacing;

  /// Optional widget placed before the first label (a mute button, say).
  final Widget? leading;

  @override
  State<PlayerTimeline> createState() => _PlayerTimelineState();
}

final class _PlayerTimelineState extends State<PlayerTimeline> {
  Duration? _preview;

  @override
  Widget build(BuildContext context) {
    final spacing = widget.spacing ?? widget.theme.barGap;

    return ValueListenableBuilder<PlaybackState>(
      valueListenable: widget.controller.playbackListenable,
      builder: (context, playback, _) {
        final duration = playback.duration;
        final position = _preview ?? playback.position;

        final left = formatPlayerDuration(position, showHours: duration.inHours > 0);

        final right = widget.showRemaining
            ? '-${formatPlayerDuration(duration - position, showHours: duration.inHours > 0)}'
            : formatPlayerDuration(duration, showHours: duration.inHours > 0);

        final widgets = <Widget>[
          if (widget.leading != null) widget.leading!,
          _TimeLabel(text: left, theme: widget.theme),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: PlayerProgressBar(
                controller: widget.controller,
                theme: widget.theme,
                height: widget.barHeight,
                hoverable: widget.hoverable,
                onPreview: (value) => setState(() => _preview = value),
              ),
            ),
          ),
          _TimeLabel(text: right, theme: widget.theme),
        ];

        return Padding(
          padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: widgets),
        );
      },
    );
  }
}

final class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text, required this.theme});

  final String text;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: theme.timeTextStyle, maxLines: 1, softWrap: false);
  }
}
