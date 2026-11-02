/// Configuration for the system media surfaces.
///
/// flutter_media_session draws the standard transport icons itself, so the
/// configuration only says which controls appear and how they behave.
final class MediaSessionConfig {
  /// Creates the configuration.
  const MediaSessionConfig({
    this.showControls = true,
    this.processInterruptions = true,
    this.seekStep = const Duration(seconds: 10),
    this.showSeekButtons = true,
    this.androidCompactActionIndices = const <int>[0, 1],
  });

  /// Configuration for a player that has no queue: seek buttons instead of
  /// skip buttons, which is what a video notification wants.
  const MediaSessionConfig.video({
    this.showControls = true,
    this.processInterruptions = true,
    this.seekStep = const Duration(seconds: 10),
    this.showSeekButtons = true,
    this.androidCompactActionIndices = const <int>[0, 1, 2],
  });

  /// Whether transport controls are shown on the surfaces.
  final bool showControls;

  /// Whether audio focus interruptions (calls, other media apps) are handled.
  ///
  /// flutter_media_session requests focus while playing and sends `pause` on
  /// a loss and `play` when transient focus returns; the driver routes both to
  /// the active player like any other button press.
  final bool processInterruptions;

  /// How far the seek buttons jump.
  ///
  /// Also handed to the platform as its skip interval (iOS/macOS show it on
  /// the lock screen buttons).
  final Duration seekStep;

  /// Whether the seek buttons are offered.
  ///
  /// On by default because the alternative for a single-media player (no queue)
  /// is a notification with only play/pause and stop, which cannot move the
  /// position at all. A music host that installs skip-to-next usually wants
  /// both, which is exactly what it gets.
  final bool showSeekButtons;

  /// Compact action indices for the Android notification.
  final List<int> androidCompactActionIndices;
}
