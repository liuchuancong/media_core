import 'package:flutter/material.dart';
import '../common/player_control_buttons.dart';
import '../common/player_controls_controller.dart';
import '../common/player_controls_theme.dart';

/// Control set in the desktop window-player idiom.
///
/// What makes it read as a Windows player rather than as a phone UI stretched
/// wide:
///
/// - the controls are a *hover* surface: they appear when the pointer enters
///   and disappear when it leaves and the video keeps playing, instead of
///   waiting for a tap;
/// - everything is compact — 16 px glyphs, 3 px progress track — because a
///   desktop viewer sits close to a large picture and does not want it covered;
/// - a volume slider exists, and a rate button shows the current rate as text
///   (`1.25x`) rather than hiding it in a menu;
/// - tooltips on every control, and keyboard shortcuts from
///   [PlayerShortcuts] (space, arrows, m, f);
/// - a menu at the top right for the occasional actions (loop, audio-only,
///   floating window, screenshot).
///
/// ```dart
/// MediaCorePlayerView(handle: handle, style: PlayerControlsStyle.windows)
/// ```
final class WindowsPlayerControls extends StatelessWidget {
  /// Creates the desktop control set.
  const WindowsPlayerControls({
    required this.controller,
    super.key,
    this.theme,
    this.showTitle = true,
    this.showVolumeSlider = true,
    this.showMenu = true,
    this.padding = EdgeInsets.zero,
  });

  /// Playback state and actions.
  final PlayerControlsController controller;

  /// Colors and metrics; defaults to [PlayerControlsTheme.windows].
  final PlayerControlsTheme? theme;

  /// Whether the title rides in the top bar.
  final bool showTitle;

  /// Whether a volume slider is offered.
  ///
  /// Desktop is the one style where it belongs: the pointer is already there,
  /// and system volume is not reachable from inside a window.
  final bool showVolumeSlider;

  /// Whether the top-right menu is offered.
  final bool showMenu;

  /// Padding around the whole set.
  final EdgeInsets padding;

  PlayerControlsTheme get _theme => theme ?? const PlayerControlsTheme.windows();

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
              _TopBar(controller: controller, theme: theme, showTitle: showTitle, showMenu: showMenu),
              const Spacer(),
              if (controller.isBuffering && controller.hasSource)
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: theme.progressTrack,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                ),
              _BottomBar(
                controller: controller,
                theme: theme,
                showVolumeSlider: showVolumeSlider,
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.theme,
    required this.showTitle,
    required this.showMenu,
  });

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;
  final bool showTitle;
  final bool showMenu;

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
            if (showMenu) _DesktopMenu(controller: controller, theme: theme),
          ],
        ),
      ),
    );
  }
}

final class _DesktopMenu extends StatelessWidget {
  const _DesktopMenu({required this.controller, required this.theme});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(const Color(0xFF1F1F1F)),
        shape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      ),
      menuChildren: <Widget>[
        if (controller.canSeek) ...<Widget>[
          _MenuHeader(text: 'Playback speed', theme: theme),
          for (final rate in PlayerControlsController.defaultRates)
            MenuItemButton(
              leadingIcon: Icon(
                (controller.rate - rate).abs() < 0.001 ? Icons.check : Icons.speed,
                size: theme.compactIconSize,
                color: theme.foreground,
              ),
              onPressed: () => controller.setRate(rate),
              child: Text('${rate}x', style: theme.timeTextStyle),
            ),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
        ],
        MenuItemButton(
          leadingIcon: Icon(
            controller.isLooping ? Icons.repeat_on_outlined : Icons.repeat,
            size: theme.compactIconSize,
            color: theme.foreground,
          ),
          onPressed: controller.toggleLoop,
          child: Text('Loop', style: theme.timeTextStyle),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            controller.isAudioOnly ? Icons.music_note : Icons.music_note_outlined,
            size: theme.compactIconSize,
            color: theme.foreground,
          ),
          onPressed: () => controller.setAudioOnly(!controller.isAudioOnly),
          child: Text('Audio only', style: theme.timeTextStyle),
        ),
        if (controller.canCaptureScreenshot)
          MenuItemButton(
            leadingIcon: Icon(Icons.photo_camera_outlined, size: theme.compactIconSize, color: theme.foreground),
            onPressed: controller.captureScreenshot,
            child: Text('Save frame', style: theme.timeTextStyle),
          ),
        if (controller.actions.canEnterFloating)
          MenuItemButton(
            leadingIcon: Icon(Icons.picture_in_picture_alt_outlined, size: theme.compactIconSize, color: theme.foreground),
            onPressed: controller.enterFloating,
            child: Text('Floating window', style: theme.timeTextStyle),
          ),
      ],
      builder: (context, menuController, child) {
        return PlayerIconButton(
          icon: Icons.more_horiz,
          theme: theme,
          tooltip: 'More',
          padding: const EdgeInsets.all(4),
          onPressed: () => menuController.isOpen ? menuController.close() : menuController.open(),
        );
      },
    );
  }
}

final class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.text, required this.theme});

  final String text;
  final PlayerControlsTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        style: theme.timeTextStyle.copyWith(fontSize: 11, color: theme.foregroundMuted),
      ),
    );
  }
}

final class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.theme, required this.showVolumeSlider});

  final PlayerControlsController controller;
  final PlayerControlsTheme theme;
  final bool showVolumeSlider;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.scrim,
      child: Padding(
        padding: theme.contentPadding,
        child: Column(
          children: <Widget>[
            if (controller.canSeek)
              PlayerTimeline(
                controller: controller,
                theme: theme,
                hoverable: true,
                barHeight: 18,
              )
            else if (controller.isLive)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('LIVE', style: theme.timeTextStyle.copyWith(color: theme.accent)),
                ),
              ),
            Row(
              children: <Widget>[
                PlayerIconButton(
                  icon: controller.isPlaying ? Icons.pause : Icons.play_arrow,
                  theme: theme,
                  size: theme.primaryIconSize,
                  tooltip: controller.isPlaying ? 'Pause (space)' : 'Play (space)',
                  onPressed: controller.togglePlayPause,
                ),
                PlayerIconButton(
                  icon: Icons.skip_previous,
                  theme: theme,
                  tooltip: 'Back 10s (j)',
                  onPressed: () => controller.seekBy(-const Duration(seconds: 10)),
                ),
                PlayerIconButton(
                  icon: Icons.skip_next,
                  theme: theme,
                  tooltip: 'Forward 10s (l)',
                  onPressed: () => controller.seekBy(const Duration(seconds: 10)),
                ),
                if (showVolumeSlider) ...<Widget>[
                  PlayerIconButton(
                    icon: controller.isMuted ? Icons.volume_off : Icons.volume_up,
                    theme: theme,
                    tooltip: controller.isMuted ? 'Unmute (m)' : 'Mute (m)',
                    onPressed: controller.toggleMute,
                  ),
                  SizedBox(
                    width: 90,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: theme.accent,
                        inactiveTrackColor: theme.progressTrack,
                        thumbColor: theme.progressThumb,
                      ),
                      child: Slider(
                        value: controller.isMuted ? 0 : controller.volume.clamp(0.0, 1.0),
                        onChanged: controller.setVolume,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text('${controller.rate}x', style: theme.timeTextStyle),
                const Spacer(),
                if (controller.actions.canEnterPip)
                  PlayerIconButton(
                    icon: Icons.picture_in_picture_alt_outlined,
                    theme: theme,
                    tooltip: 'Picture in picture',
                    onPressed: controller.enterPip,
                  ),
                if (controller.actions.canEnterFullscreen)
                  PlayerIconButton(
                    icon: Icons.fullscreen,
                    theme: theme,
                    tooltip: 'Fullscreen (f)',
                    onPressed: controller.enterFullscreen,
                  ),
                if (controller.actions.canExitFullscreen)
                  PlayerIconButton(
                    icon: Icons.fullscreen_exit,
                    theme: theme,
                    tooltip: 'Leave fullscreen (esc)',
                    onPressed: controller.exitFullscreen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
