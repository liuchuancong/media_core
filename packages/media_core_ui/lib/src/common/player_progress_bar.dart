import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';

import 'player_controls_controller.dart';
import 'player_controls_theme.dart';

/// The timeline every control set shares.
///
/// One implementation of the interaction, themed by each style: drag to
/// preview, release to seek, tap to jump, and a buffered range behind the
/// played range. Writing it once matters more than it sounds — "seek on every
/// drag update" floods an engine with commands and makes a drag stutter, and
/// every player that gets this wrong does so in the same place.
///
/// Responsibilities:
///
/// - own the drag-preview state
/// - seek once, on release
/// - paint track, buffered range, played range and thumb
///
/// It does not:
///
/// - decide colors or sizes ([PlayerControlsTheme] does)
/// - show times (the bars do, driven by [onPreview])
final class PlayerProgressBar extends StatefulWidget {
  /// Creates a progress bar for [controller].
  const PlayerProgressBar({
    required this.controller,
    required this.theme,
    super.key,
    this.onPreview,
    this.height,
    this.thumbRadius,
    this.trackHeight,
    this.trackHeightWhileDragging,
    this.expandThumbOnDrag = true,
    this.hoverable = false,
    this.padding = EdgeInsets.zero,
  });

  /// Controller whose player this bar seeks.
  final PlayerControlsController controller;

  /// Colors and metrics.
  final PlayerControlsTheme theme;

  /// Reports the position being previewed during a drag, and null when the drag
  /// ends.
  ///
  /// The bars use it to move their time labels, which is what makes a drag feel
  /// attached to the picture even before the engine catches up.
  final ValueChanged<Duration?>? onPreview;

  /// Height of the whole bar's hit area.
  final double? height;

  /// Radius of the thumb.
  final double? thumbRadius;

  /// Track height at rest.
  final double? trackHeight;

  /// Track height while dragging.
  final double? trackHeightWhileDragging;

  /// Whether the track thickens during a drag.
  final bool expandThumbOnDrag;

  /// Whether the track thickens while the pointer is over it.
  ///
  /// Desktop: the bar is otherwise a hairline.
  final bool hoverable;

  /// Padding around the track inside the hit area.
  final EdgeInsets padding;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

final class _PlayerProgressBarState extends State<PlayerProgressBar> {
  /// Fraction being previewed during a drag; null when not dragging.
  double? _dragFraction;

  bool _hovering = false;

  double get _trackHeight {
    final base = widget.trackHeight ?? widget.theme.trackHeight;

    if (_dragFraction != null) {
      return widget.trackHeightWhileDragging ?? widget.theme.trackHeightWhileDragging;
    }

    if (widget.hoverable && _hovering) {
      return widget.trackHeightWhileDragging ?? widget.theme.trackHeightWhileDragging;
    }

    return base;
  }

  /// Track geometry for a pointer position inside the bar.
  double _fractionFor(Offset localPosition, double width) {
    if (width <= 0) {
      return 0;
    }

    return (localPosition.dx / width).clamp(0.0, 1.0);
  }

  Duration _positionFor(double fraction) {
    final duration = widget.controller.duration;

    if (duration <= Duration.zero) {
      return Duration.zero;
    }

    return Duration(microseconds: (duration.inMicroseconds * fraction).round());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: widget.hoverable ? (_) => setState(() => _hovering = true) : null,
          onExit: widget.hoverable ? (_) => setState(() => _hovering = false) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              // A tap is a complete gesture: seeking right away is what the
              // viewer asked for.
              final fraction = _fractionFor(details.localPosition, width);

              widget.controller.seekTo(_positionFor(fraction));
            },
            onHorizontalDragStart: (details) {
              setState(() => _dragFraction = _fractionFor(details.localPosition, width));

              widget.onPreview?.call(_positionFor(_dragFraction!));
            },
            onHorizontalDragUpdate: (details) {
              final fraction = _fractionFor(details.localPosition, width);

              setState(() => _dragFraction = fraction);

              widget.onPreview?.call(_positionFor(fraction));
            },
            onHorizontalDragEnd: (_) => _commitDrag(),
            onHorizontalDragCancel: _commitDrag,
            child: Padding(
              padding: widget.padding,
              child: SizedBox(
                height: widget.height ?? (widget.theme.thumbRadius * 2 + 8),
                child: ValueListenableBuilder<PlaybackState>(
                  valueListenable: widget.controller.playbackListenable,
                  builder: (context, playback, _) {
                    return CustomPaint(
                      painter: _ProgressPainter(
                        theme: widget.theme,
                        trackHeight: _trackHeight,
                        thumbRadius: widget.thumbRadius ?? widget.theme.thumbRadius,
                        showThumb: _dragFraction != null || (widget.hoverable ? _hovering : true),
                        playbackFraction: playback.hasDuration ? playback.progress.clamp(0.0, 1.0) : 0,
                        dragFraction: _dragFraction,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _commitDrag() {
    final fraction = _dragFraction;

    if (fraction == null) {
      return;
    }

    setState(() => _dragFraction = null);

    widget.onPreview?.call(null);

    // One seek for the whole gesture, at the position the viewer let go of.
    widget.controller.seekTo(_positionFor(fraction));
  }
}

final class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.theme,
    required this.trackHeight,
    required this.thumbRadius,
    required this.showThumb,
    required this.playbackFraction,
    required this.dragFraction,
  });

  final PlayerControlsTheme theme;
  final double trackHeight;
  final double thumbRadius;
  final bool showThumb;
  final double playbackFraction;
  final double? dragFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final track = Rect.fromLTWH(0, centerY - trackHeight / 2, size.width, trackHeight);
    final radius = Radius.circular(trackHeight / 2);

    canvas.drawRRect(RRect.fromRectAndRadius(track, radius), Paint()..color = theme.progressTrack);

    final played = dragFraction ?? playbackFraction;

    if (played <= 0) {
      return;
    }

    final playedRect = Rect.fromLTWH(0, track.top, size.width * played, trackHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(playedRect, radius),
      Paint()..color = theme.progressPlayed,
    );

    if (!showThumb) {
      return;
    }

    canvas.drawCircle(
      Offset(size.width * played, centerY),
      thumbRadius,
      Paint()..color = theme.progressThumb,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    return oldDelegate.trackHeight != trackHeight ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.showThumb != showThumb ||
        oldDelegate.playbackFraction != playbackFraction ||
        oldDelegate.dragFraction != dragFraction ||
        oldDelegate.theme != theme;
  }
}

/// Formats a duration the way player UIs do.
String formatPlayerDuration(Duration duration, {bool showHours = false}) {
  final value = duration.isNegative ? Duration.zero : duration;

  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);

  String two(int number) => number.toString().padLeft(2, '0');

  if (showHours || hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }

  return '${two(minutes)}:${two(seconds)}';
}
