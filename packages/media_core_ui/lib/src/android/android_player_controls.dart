import 'package:flutter/material.dart';
import '../common/player_control_buttons.dart';
import '../common/player_controls_controller.dart';
import '../common/player_controls_theme.dart';

/// Control set in the Android / Material idiom.
///
/// What makes it read as Material rather than as "dark buttons":
///
/// - a solid scrim bar at the top carrying the title and an overflow menu,
///   because Android put the actions there since the first YouTube app;
/// - a filled circular play button in the middle, sized for a thumb;
/// - a thick slider with a visible thumb, always, not only while dragging;
/// - the duration on the right and the elapsed time on the left of the slider,
///   with the mute and fullscreen glyphs at the ends of the same row;
/// - ripple feedback on every control;
/// - no volume slider: Android volume belongs to the hardware keys, and an
///   in-app slider would fight the system panel.
///
/// ```dart
/// MediaCorePlayerView(handle: handle, style: PlayerControlsStyle.android)
/// ```
final class AndroidPlayerControls extends StatelessWidget {
  /// Creates the Android control set.
  const AndroidPlayerControls({
    required this.controller,
    super.key,
    this.theme,
    this.showTitle = true,
    this.showOverflowMenu = true,
    this.showSkipButtons = false,
    this.skipStep = const Duration(seconds: 10),
    this.padding = EdgeInsets.zero,
  });

  /// Playback state and actions.
  final PlayerControlsController controller;

  /// Colors and metrics; defaults to [PlayerControlsTheme.android].
  final PlayerControlsTheme? theme;

  /// Whether the title rides in the top bar.
  final bool showTitle;

  /// Whether the overflow menu is offered.
  ///
  /// Holds what does not deserve a permanent button: rate, loop, audio-only,
  /// floating window.
  final bool showOverflowMenu;

  /// Whether ±10 s buttons flank the play button.
  ///
  /// Off by default — Android apps usually leave those to gestures — but the
  /// buttons are there for hosts that want YouTube's tap-to-skip buttons
  /// visible.
  final bool showSkipButtons;

  /// Amount the skip buttons jump.
  final Duration skipStep;

  /// Padding around the whole set.
  final EdgeInsets padding;

  PlayerControlsTheme get _theme => theme ?? const PlayerControlsTheme.android();

  @override
  Widget build(BuildContext context) {
    final theme = _theme;

    return Material(
      // Transparent, but present: Material widgets (ripple, menus, sliders)
      // assert without a Material ancestor, and a host may be a Cupertino app.
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Padding(
            padding: padding,
            child: Column(
              children: <Widget>[
                _TopBar(
                  controller: controller,
                  theme: theme,
                  showTitle: showTitle,
                  showOverflowMenu: showOverflowMenu,
                ),
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
      ),
    );
  }
}

final class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.theme,
    required this.showTitle,
    required this.showOverflowMenu,
  });

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;
  final bool showTitle;
  final bool showOverflowMenu;

  @override
  Widget build(BuildContext context) {
    final title = controller.title;

    return ColoredBox(
      color: theme.scrim,
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
            if (controller.canCaptureScreenshot)
              PlayerIconButton(
                icon: Icons.photo_camera_outlined,
                theme: theme,
                ripple: true,
                tooltip: 'Save frame',
                onPressed: controller.captureScreenshot,
              ),
            if (controller.actions.canEnterPip)
              PlayerIconButton(
                icon: Icons.picture_in_picture_alt_outlined,
                theme: theme,
                ripple: true,
                tooltip: 'Picture in picture',
                onPressed: controller.enterPip,
              ),
            if (showOverflowMenu) _OverflowMenu(controller: controller, theme: theme),
          ],
        ),
      ),
    );
  }
}

final class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.controller, required this.theme});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    final entries = <PopupMenuEntry<String>>[
      if (controller.canSeek)
        PopupMenuItem<String>(
          value: 'rate',
          child: Row(
            children: <Widget>[
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 12),
              const Text('Playback speed'),
              const Spacer(),
              Text('${controller.rate.toStringAsFixed(2)}x', style: theme.timeTextStyle.copyWith(color: Colors.black87)),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'loop',
        child: Row(
          children: <Widget>[
            Icon(controller.isLooping ? Icons.repeat_on_outlined : Icons.repeat, size: 20),
            const SizedBox(width: 12),
            const Text('Loop'),
            if (controller.isLooping) const Spacer(),
            if (controller.isLooping) const Icon(Icons.check, size: 18),
          ],
        ),
      ),
      if (controller.actions.canEnterFloating)
        const PopupMenuItem<String>(
          value: 'floating',
          child: Row(
            children: <Widget>[
              Icon(Icons.picture_in_picture_outlined, size: 20),
              SizedBox(width: 12),
              Text('Floating window'),
            ],
          ),
        ),
    ];

    return PopupMenuButton<String>(
      tooltip: 'More',
      color: const Color(0xFF212121),
      icon: const Icon(Icons.more_vert, size: 22, color: Color(0xFFFFFFFF)),
      onSelected: (value) {
        switch (value) {
          case 'rate':
            controller.cycleRate();
          case 'loop':
            controller.toggleLoop();
          case 'floating':
            controller.enterFloating();
        }
      },
      itemBuilder: (context) => entries,
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
      return SizedBox(
        width: theme.primaryIconSize,
        height: theme.primaryIconSize,
        child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(theme.accent)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (showSkipButtons)
          IconButton(
            iconSize: 32,
            color: theme.foreground,
            tooltip: 'Back ${skipStep.inSeconds}s',
            icon: const Icon(Icons.replay_10),
            onPressed: () => controller.seekBy(-skipStep),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: IconButton.filled(
            iconSize: theme.primaryIconSize * 0.7,
            style: IconButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.foreground,
              padding: const EdgeInsets.all(12),
            ),
            tooltip: controller.isPlaying ? 'Pause' : 'Play',
            icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: controller.togglePlayPause,
          ),
        ),
        if (showSkipButtons)
          IconButton(
            iconSize: 32,
            color: theme.foreground,
            tooltip: 'Forward ${skipStep.inSeconds}s',
            icon: const Icon(Icons.forward_10),
            onPressed: () => controller.seekBy(skipStep),
          ),
      ],
    );
  }
}

final class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.theme});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.scrim,
      child: Padding(
        padding: theme.contentPadding,
        child: controller.canSeek
            ? Row(
                children: <Widget>[
                  // YouTube-Android order: elapsed, slider, duration, then the
                  // two glyphs at the end of the same row.
                  Expanded(child: PlayerTimeline(controller: controller, theme: theme, barHeight: 26)),
                  PlayerIconButton(
                    icon: controller.isMuted ? Icons.volume_off : Icons.volume_up,
                    theme: theme,
                    ripple: true,
                    tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                    onPressed: controller.toggleMute,
                  ),
                  if (controller.actions.canEnterFullscreen)
                    PlayerIconButton(
                      icon: Icons.fullscreen,
                      theme: theme,
                      ripple: true,
                      tooltip: 'Fullscreen',
                      onPressed: controller.enterFullscreen,
                    ),
                  if (controller.actions.canExitFullscreen)
                    PlayerIconButton(
                      icon: Icons.fullscreen_exit,
                      theme: theme,
                      ripple: true,
                      tooltip: 'Leave fullscreen',
                      onPressed: controller.exitFullscreen,
                    ),
                ],
              )
            : Row(
                children: <Widget>[
                  if (controller.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(3)),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  const Spacer(),
                  PlayerIconButton(
                    icon: controller.isMuted ? Icons.volume_off : Icons.volume_up,
                    theme: theme,
                    ripple: true,
                    tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                    onPressed: controller.toggleMute,
                  ),
                  if (controller.actions.canEnterFullscreen)
                    PlayerIconButton(
                      icon: Icons.fullscreen,
                      theme: theme,
                      ripple: true,
                      tooltip: 'Fullscreen',
                      onPressed: controller.enterFullscreen,
                    ),
                ],
              ),
      ),
    );
  }
}
