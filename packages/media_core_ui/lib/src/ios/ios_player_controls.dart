import 'package:flutter/cupertino.dart';
import '../common/player_control_buttons.dart';
import '../common/player_controls_controller.dart';
import '../common/player_controls_theme.dart';

/// Control set in the iOS / AVPlayer idiom.
///
/// What makes it read as iOS rather than as "dark buttons":
///
/// - a single large glyph in the middle, where the thumb already is, instead of
///   a row of small buttons;
/// - the right-hand time counts *down* and is prefixed with a minus, so the
///   viewer reads "how much is left", not "how long it was";
/// - a hairline progress bar that thickens only while it is being dragged;
/// - a buffering spinner in place of the play glyph, not on top of it;
/// - no volume slider: iOS volume is the hardware buttons, and a second control
///   for it would be a lie.
///
/// The scrim is a top and bottom gradient rather than a flat panel, so the
/// picture stays visible behind the controls.
///
/// ```dart
/// MediaCorePlayerView(handle: handle, style: PlayerControlsStyle.ios)
/// ```
final class IosPlayerControls extends StatelessWidget {
  /// Creates the iOS control set.
  const IosPlayerControls({
    required this.controller,
    super.key,
    this.theme,
    this.showTitle = true,
    this.showSkipButtons = true,
    this.skipStep = const Duration(seconds: 15),
    this.padding = EdgeInsets.zero,
  });

  /// Playback state and actions.
  final PlayerControlsController controller;

  /// Colors and metrics; defaults to [PlayerControlsTheme.ios].
  final PlayerControlsTheme? theme;

  /// Whether the title rides in the top bar.
  final bool showTitle;

  /// Whether the ±15 s buttons flank the play button.
  final bool showSkipButtons;

  /// Amount the skip buttons jump.
  final Duration skipStep;

  /// Padding around the whole set.
  final EdgeInsets padding;

  PlayerControlsTheme get _theme => theme ?? const PlayerControlsTheme.ios();

  @override
  Widget build(BuildContext context) {
    final theme = _theme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: padding,
          child: Column(
            children: <Widget>[
              _TopBar(controller: controller, theme: theme, showTitle: showTitle),
              Expanded(
                child: _CenterControls(
                  controller: controller,
                  theme: theme,
                  showSkipButtons: showSkipButtons,
                  skipStep: skipStep,
                ),
              ),
              _BottomBar(controller: controller, theme: theme),
            ],
          ),
        );
      },
    );
  }
}

final class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.theme, required this.showTitle});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final title = controller.title;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: Padding(
        padding: theme.contentPadding,
        child: Row(
          children: <Widget>[
            if (showTitle && title != null)
              Expanded(
                child: Text(title, style: theme.titleTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              )
            else
              const Spacer(),
            if (controller.actions.canEnterPip)
              PlayerIconButton(
                icon: CupertinoIcons.rectangle_on_rectangle_angled,
                theme: theme,
                tooltip: 'Picture in picture',
                onPressed: controller.enterPip,
              ),
            if (controller.actions.canEnterFullscreen)
              PlayerIconButton(
                icon: CupertinoIcons.arrow_up_left_arrow_down_right,
                theme: theme,
                tooltip: 'Fullscreen',
                onPressed: controller.enterFullscreen,
              ),
            if (controller.actions.canExitFullscreen)
              PlayerIconButton(
                icon: CupertinoIcons.arrow_down_right_arrow_up_left,
                theme: theme,
                tooltip: 'Leave fullscreen',
                onPressed: controller.exitFullscreen,
              ),
          ],
        ),
      ),
    );
  }
}

final class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.controller,
    required this.theme,
    required this.showSkipButtons,
    required this.skipStep,
  });

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;
  final bool showSkipButtons;
  final Duration skipStep;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasSource) {
      return const SizedBox.shrink();
    }

    if (controller.isBuffering) {
      // The spinner *replaces* the glyph: a play button that does nothing while
      // the stream loads is the classic way to make a viewer tap twice.
      return CupertinoActivityIndicator(radius: theme.primaryIconSize / 3, color: theme.foreground);
    }

    final seconds = skipStep.inSeconds;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (showSkipButtons)
          PlayerIconButton(
            icon: _rewindIcon(seconds),
            theme: theme,
            size: theme.primaryIconSize * 0.6,
            tooltip: 'Back ${seconds}s',
            onPressed: () => controller.seekBy(-skipStep),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: PlayerIconButton(
            icon: controller.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            theme: theme,
            size: theme.primaryIconSize,
            tooltip: controller.isPlaying ? 'Pause' : 'Play',
            onPressed: controller.togglePlayPause,
          ),
        ),
        if (showSkipButtons)
          PlayerIconButton(
            icon: _forwardIcon(seconds),
            theme: theme,
            size: theme.primaryIconSize * 0.6,
            tooltip: 'Forward ${seconds}s',
            onPressed: () => controller.seekBy(skipStep),
          ),
      ],
    );
  }

  /// Cupertino ships 10/30/45-second glyphs only; the closest one is used and
  /// the tooltip states the real step.
  IconData _rewindIcon(int seconds) {
    if (seconds <= 10) {
      return CupertinoIcons.gobackward_10;
    }

    if (seconds >= 45) {
      return CupertinoIcons.gobackward_45;
    }

    return CupertinoIcons.gobackward_15;
  }

  IconData _forwardIcon(int seconds) {
    if (seconds <= 10) {
      return CupertinoIcons.goforward_10;
    }

    if (seconds >= 45) {
      return CupertinoIcons.goforward_45;
    }

    return CupertinoIcons.goforward_15;
  }
}

final class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.theme});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: Padding(
        padding: theme.contentPadding,
        child: Column(
          children: <Widget>[
            if (controller.canSeek)
              // Remaining time on the right is the iOS convention.
              PlayerTimeline(controller: controller, theme: theme, showRemaining: true, barHeight: 22),
            Row(
              children: <Widget>[
                PlayerIconButton(
                  icon: controller.isMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill,
                  theme: theme,
                  tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                  onPressed: controller.toggleMute,
                ),
                if (controller.canCaptureScreenshot)
                  PlayerIconButton(
                    icon: CupertinoIcons.camera,
                    theme: theme,
                    tooltip: 'Save frame',
                    onPressed: controller.captureScreenshot,
                  ),
                const Spacer(),
                if (controller.actions.canEnterFullscreen)
                  PlayerIconButton(
                    icon: CupertinoIcons.arrow_up_left_arrow_down_right,
                    theme: theme,
                    tooltip: 'Fullscreen',
                    onPressed: controller.enterFullscreen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
