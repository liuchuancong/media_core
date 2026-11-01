import 'package:media_core_cast_dlna/src/domain/entities/dlna_media.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_playback_state.dart';

/// The playback facet of a cast session (§18.2).
///
/// Commands are queued per session and run serially; a [stop] cancels
/// everything queued before it. A command's success means the device
/// accepted it — the resulting transport state is verified separately
/// and lands on the session's playback state stream.
abstract interface class DlnaPlaybackController {
  /// Loads [media] on the device without starting playback.
  Future<void> setMedia(DlnaMedia media);

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and clears the command queue. Pending commands are
  /// dropped: they complete with a DlnaSessionException rather than
  /// playing after the user asked for silence.
  Future<void> stop();

  /// Seeks to an absolute [position].
  ///
  /// Throws [ArgumentError] when the target is negative or beyond the
  /// duration the device last reported (§13.5), and
  /// A DlnaUnsupportedActionException when the device's SCPD declares
  /// no Seek action.
  Future<void> seek(Duration position);

  /// Reads the current playback state from the device.
  Future<DlnaPlaybackState> getPlaybackState();

  /// The last reported playhead position, when known.
  Future<Duration?> getPosition();

  /// The last reported media duration, when known.
  Future<Duration?> getDuration();
}
