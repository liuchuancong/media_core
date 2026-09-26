import 'package:media_core/media_core.dart' show VideoOrientation;

/// Tunables for the picture-in-picture feature.
///
/// One object covers both platform families, because the knobs are the same
/// intent expressed twice: how big the small window is, how close to the
/// screen edge it sits, and whether leaving it restores what was there before.
final class PipConfig {
  const PipConfig({
    this.width = 320,
    this.height = 180,
    this.cornerSpacing = 16,
    this.skipTaskbar = false,
    this.title = 'media_core PiP',
    this.restoreWindowOnExit = true,
    this.lockAspectRatio = true,
    this.fallbackOrientation = VideoOrientation.landscape,
    this.requestSourceRectHint = true,
  });

  /// Caller-accepted defaults.
  static const PipConfig defaults = PipConfig();

  /// Width of the desktop small window, in logical pixels.
  final double width;

  /// Height of the desktop small window.
  ///
  /// Used as-is only when the video size is unknown; otherwise the height
  /// follows the video's aspect ratio.
  final double height;

  /// Distance between the small window and the screen corner it snaps to.
  final double cornerSpacing;

  /// Whether the desktop small window hides from the taskbar.
  final bool skipTaskbar;

  /// Window title while in picture-in-picture.
  final String title;

  /// Whether leaving picture-in-picture restores the previous window state
  /// (size, position, always-on-top, resizable, title).
  final bool restoreWindowOnExit;

  /// Whether the desktop small window is locked to the video's shape.
  ///
  /// On by default: a small window that shows the video's actual shape wastes
  /// no area on letterbox bars. Turn it off for a fixed-shape small window that
  /// the video is fitted into — the in-app equivalent of that is
  /// `media_core_floating`, which is a widget rather than a window.
  final bool lockAspectRatio;

  /// Orientation assumed when the video size is unknown.
  final VideoOrientation fallbackOrientation;

  /// Whether the video widget's rectangle is passed to the platform as the
  /// picture-in-picture source hint.
  ///
  /// Mobile only, and purely cosmetic: it drives the entrance animation.
  final bool requestSourceRectHint;

  PipConfig copyWith({
    double? width,
    double? height,
    double? cornerSpacing,
    bool? skipTaskbar,
    String? title,
    bool? restoreWindowOnExit,
    bool? lockAspectRatio,
    VideoOrientation? fallbackOrientation,
    bool? requestSourceRectHint,
  }) {
    return PipConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      cornerSpacing: cornerSpacing ?? this.cornerSpacing,
      skipTaskbar: skipTaskbar ?? this.skipTaskbar,
      title: title ?? this.title,
      restoreWindowOnExit: restoreWindowOnExit ?? this.restoreWindowOnExit,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      fallbackOrientation: fallbackOrientation ?? this.fallbackOrientation,
      requestSourceRectHint: requestSourceRectHint ?? this.requestSourceRectHint,
    );
  }
}
