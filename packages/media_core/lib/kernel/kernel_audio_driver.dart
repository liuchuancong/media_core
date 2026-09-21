import 'player_handle.dart';

/// Driver interface for audio capability packages.
///
/// A [KernelAudioDriver] is attached to a [PlayerKernel] via
/// `attachAudio` and receives active-player notifications. The
/// kernel owns the notifications; the driver owns the platform
/// integration (audio focus, media notification, lock screen).
///
/// Activation semantics:
///
/// - a player that starts playback becomes active (switching away
///   from a previously active player is implicit);
/// - pausing does NOT deactivate: the paused player stays the
///   active one so notifications keep offering resume;
/// - stopping or releasing deactivates.
///
/// Implementations:
///
/// - `media_core_audio` (audio_service / audio_session)
///
/// It does not:
///
/// - decide which player is active
/// - own playback state
///
/// Those belong to:
///
/// - PlayerKernel
/// - PlayerHandle
abstract interface class KernelAudioDriver {
  /// Called when [handle] becomes the active player.
  void onPlayerActivated(PlayerHandle handle);

  /// Called when the active player stopped or was released.
  void onPlayerDeactivated();
}
