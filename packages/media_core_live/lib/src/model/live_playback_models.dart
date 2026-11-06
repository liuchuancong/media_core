import 'package:flutter/foundation.dart' show immutable;
import 'package:media_core/media_core.dart' show ErrorPolicy, PlayerAdapterCapabilities, PlayerErrorCode, PlayerFailure;
import 'package:media_core_live/src/watchdog/live_watchdogs.dart' show LiveWatchdogs;

/// Stall kinds inferred by [LiveWatchdogs].
///
/// A stall is an inference, not a backend report: the watchdog
/// observed a missing expectation (no playing state, no frame,
/// sustained buffering) rather than an explicit error.
///
/// This enum is intentionally *not* an error model. The controller
/// maps each kind onto a [PlayerFailure] with a concrete
/// [PlayerErrorCode] before handing it to [ErrorPolicy].
enum LiveStallKind {
  /// Source opened but produced no playable state in time.
  sourceReadyTimeout,

  /// An unexpected pause resumed successfully after a reassert.
  unexpectedPauseResumed,

  /// A reasserted playback did not start playing again.
  unexpectedPauseResumeFailed,

  /// Playback stayed paused after the continuity retry.
  unexpectedPauseTimeout,

  /// Buffering never ended within the deadline.
  bufferingStallTimeout,

  /// Playing state held but no new video frame arrived.
  ///
  /// Only meaningful on engines that report a decoded-frame heartbeat; see
  /// [PlayerAdapterCapabilities.supportsVideoFrameProgress].
  videoFrameStallTimeout,

  /// Playing state held and the stream was not buffering, yet playback
  /// position stopped advancing.
  ///
  /// The detector of last resort: it works on every engine, because every
  /// adapter reports position, so a picture that freezes while the engine
  /// still claims to be playing is caught here even when no frame
  /// heartbeat and no buffering transition is available to catch it.
  positionStallTimeout,

  /// A live source that had been advancing stood still for
  /// [LiveWatchdogs.stallNoticeTimeout]: the recovery attempt is announced
  /// ahead of the [positionStallTimeout] verdict instead of waiting for it.
  positionStallNotice,
}

/// The recovery command a watchdog can ask its owner to perform.
///
/// An action rather than an error: the watchdog never touches the player, so
/// this says only what the owner is expected to do and leaves the how to it.
enum LiveWatchdogRecoveryAction {
  /// Reassert playback after an unexpected pause.
  ///
  /// The owner should forward this to `PlayerHandle.play` or the
  /// equivalent lifecycle-safe playback command.
  reassertPlay,
}

/// The controller's recovery attempt counter, as published on
/// `LivePlaybackController.onRecoveryChanged`.
///
/// [attempt] counts the attempts of one losing streak: it runs on across
/// consecutive recoveries and drops back to zero once the stream has played
/// long enough to restore the recovery budgets. [cause] names the failure
/// behind the current attempt, [offline] says the network itself stopped
/// answering and the controller is probing it.
@immutable
final class LiveRecoveryState {
  /// Creates a recovery state snapshot.
  const LiveRecoveryState({required this.attempt, this.cause, this.offline = false});

  /// Attempt number, counting from 1; 0 while nothing is being recovered.
  final int attempt;

  /// The failure behind the current attempt; null while [attempt] is 0.
  final String? cause;

  /// Whether the network is gone and the controller is probing it.
  final bool offline;

  @override
  bool operator ==(Object other) {
    return other is LiveRecoveryState &&
        other.attempt == attempt &&
        other.cause == cause &&
        other.offline == offline;
  }

  @override
  int get hashCode => Object.hash(attempt, cause, offline);

  @override
  String toString() => 'LiveRecoveryState(attempt: $attempt, cause: $cause, offline: $offline)';
}
