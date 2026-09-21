import 'dart:async';

import 'live_playback_models.dart';

/// Watchdog-driven orchestration for live (non-seekable) streams.
///
/// [LiveWatchdogs] observes one player's adapter events and the
/// kernel event bus, and infers stalls the backend never reports:
///
/// - [sourceReadyTimeout]: opened but produced no playing state
/// - [unexpectedPauseGrace] / [unexpectedPauseFailureGrace]:
///   playing went false without user intent
/// - [bufferingStallTimeout]: buffering never ended
/// - [videoFrameStallTimeout]: playing but no new video frame
///   event arrived (decoder wedged)
///
/// Inferred stalls are reported through [onStall] with a
/// [LiveStallKind]; the [LivePlaybackController] turns them into
/// line / engine recovery. Everything is revision-guarded so a
/// stall observed on a retired source generation is dropped.
final class LiveWatchdogs {
  /// Creates the watchdog bundle.
  LiveWatchdogs({
    this.sourceReadyTimeout = const Duration(seconds: 18),
    this.unexpectedPauseGrace = const Duration(milliseconds: 350),
    this.unexpectedPauseFailureGrace = const Duration(seconds: 5),
    this.bufferingStallTimeout = const Duration(seconds: 12),
    this.videoFrameStallTimeout = const Duration(seconds: 10),
    this.enabled = true,
  }) : _clock = Stopwatch();

  /// Opened-but-not-playing deadline. Zero disables.
  final Duration sourceReadyTimeout;

  /// Grace before an unexpected `playing=false` triggers a resume.
  final Duration unexpectedPauseGrace;

  /// Grace for the resumed playback to actually start playing.
  final Duration unexpectedPauseFailureGrace;

  /// Deadline for a single uninterrupted buffering episode.
  final Duration bufferingStallTimeout;

  /// Deadline without any new video frame event while playing.
  final Duration videoFrameStallTimeout;

  /// Master switch; disabled watchdogs never arm.
  final bool enabled;

  final Stopwatch _clock;

  Timer? _sourceReadyTimer;
  Timer? _continuityTimer;
  Timer? _bufferingStallTimer;
  Timer? _videoFrameStallTimer;
  Duration? _videoFrameDeadline;

  bool _playing = false;
  bool _buffering = false;
  bool _presentationVisible = true;

  /// Called when a stall is inferred.
  ///
  /// May be invoked from a timer callback; the owner decides how
  /// to schedule the recovery.
  void Function(LiveStallKind kind)? onStall;

  /// Called when an unexpected pause was detected and a direct
  /// `play()` reassert is wanted before escalation.
  ///
  /// Return false to let the watchdog escalate immediately.
  Future<bool> Function()? onReassertPlay;

  /// Arms the source-ready deadline after a successful open.
  void armSourceReady() {
    _cancelSourceReady();
    if (!enabled || sourceReadyTimeout <= Duration.zero || _playing) return;
    _sourceReadyTimer = Timer(sourceReadyTimeout, () {
      _sourceReadyTimer = null;
      if (!_playing) onStall?.call(LiveStallKind.sourceReadyTimeout);
    });
  }

  /// Feeds the playing state from adapter events.
  ///
  /// [fromUserIntent] distinguishes a user pause from a transport
  /// hiccup; only the latter arms the continuity watchdog.
  void onPlayingChanged(bool playing, {required bool fromUserIntent}) {
    _playing = playing;
    _cancelSourceReady();

    if (playing) {
      _cancelContinuity();
      if (_buffering) {
        _armBufferingStall();
      } else {
        _armVideoFrameStall();
      }
      return;
    }

    _cancelVideoFrameStall();
    if (fromUserIntent) {
      _cancelContinuity();
      _cancelBufferingStall();
      return;
    }
    if (_buffering) {
      _armBufferingStall();
    } else {
      _armContinuity();
    }
  }

  /// Feeds the buffering state from adapter events.
  void onBufferingChanged(bool buffering) {
    _buffering = buffering;
    if (buffering) {
      _cancelVideoFrameStall();
      _cancelContinuity();
      _armBufferingStall();
    } else {
      _cancelBufferingStall();
      if (_playing) {
        _armVideoFrameStall();
      } else {
        _armContinuity();
      }
    }
  }

  /// Feeds a video-size / frame-progress observation.
  ///
  /// Any geometry or frame event proves the decoder is alive.
  void onFrameProgress() {
    if (_videoFrameStallTimer != null || _videoFrameDeadline != null) {
      _clock.start();
      _videoFrameDeadline = _clock.elapsed + videoFrameStallTimeout;
    }
  }

  /// Marks whether a route currently owns the mounted video
  /// presentation. Hidden presentations stop frame watchdogs.
  void setPresentationVisible(bool visible) {
    _presentationVisible = visible;
    if (!visible) {
      _cancelVideoFrameStall();
    } else if (_playing) {
      _armVideoFrameStall();
    }
  }

  /// Whether the playing state is currently true.
  bool get isPlaying => _playing;

  // ---------------------------------------------------------------------------
  // Arming internals
  // ---------------------------------------------------------------------------

  void _armContinuity() {
    if (!enabled || unexpectedPauseGrace <= Duration.zero) return;
    _cancelContinuity();
    _continuityTimer = Timer(unexpectedPauseGrace, () {
      _continuityTimer = null;
      _reassertPlay();
    });
  }

  Future<void> _reassertPlay() async {
    final reassert = onReassertPlay;
    if (reassert == null) {
      onStall?.call(LiveStallKind.unexpectedPauseTimeout);
      return;
    }
    final resumed = await reassert();
    if (resumed && (_playing || _buffering)) return;

    // Give the resumed playback one more bounded chance.
    if (!enabled || unexpectedPauseFailureGrace <= Duration.zero) {
      onStall?.call(LiveStallKind.unexpectedPauseResumeFailed);
      return;
    }
    _continuityTimer = Timer(unexpectedPauseFailureGrace, () {
      _continuityTimer = null;
      if (!_playing) {
        onStall?.call(LiveStallKind.unexpectedPauseTimeout);
      }
    });
  }

  void _armBufferingStall() {
    if (!enabled || bufferingStallTimeout <= Duration.zero || !_buffering) return;
    _cancelBufferingStall();
    _bufferingStallTimer = Timer(bufferingStallTimeout, () {
      _bufferingStallTimer = null;
      if (_buffering) {
        onStall?.call(LiveStallKind.bufferingStallTimeout);
      }
    });
  }

  void _armVideoFrameStall() {
    if (!enabled ||
        videoFrameStallTimeout <= Duration.zero ||
        !_presentationVisible ||
        !_playing) {
      _cancelVideoFrameStall();
      return;
    }
    _clock.start();
    _videoFrameDeadline = _clock.elapsed + videoFrameStallTimeout;
    if (_videoFrameStallTimer != null) return;

    void check() {
      _videoFrameStallTimer = null;
      if (!_presentationVisible || !_playing) {
        _cancelVideoFrameStall();
        return;
      }
      final deadline = _videoFrameDeadline;
      if (deadline == null) return;
      final remaining = deadline - _clock.elapsed;
      if (remaining > Duration.zero) {
        _videoFrameStallTimer = Timer(remaining, check);
        return;
      }
      _cancelVideoFrameStall();
      onStall?.call(LiveStallKind.videoFrameStallTimeout);
    }

    _videoFrameStallTimer = Timer(videoFrameStallTimeout, check);
  }

  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  void _cancelSourceReady() {
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
  }

  void _cancelContinuity() {
    _continuityTimer?.cancel();
    _continuityTimer = null;
  }

  void _cancelBufferingStall() {
    _bufferingStallTimer?.cancel();
    _bufferingStallTimer = null;
  }

  void _cancelVideoFrameStall() {
    _videoFrameStallTimer?.cancel();
    _videoFrameStallTimer = null;
    _videoFrameDeadline = null;
    _clock
      ..stop()
      ..reset();
  }

  /// Cancels every watchdog. Called on source change, user pause
  /// and disposal.
  void cancelAll() {
    _cancelSourceReady();
    _cancelContinuity();
    _cancelBufferingStall();
    _cancelVideoFrameStall();
  }

  /// Releases the watchdog bundle.
  void dispose() {
    cancelAll();
    onStall = null;
    onReassertPlay = null;
  }
}
