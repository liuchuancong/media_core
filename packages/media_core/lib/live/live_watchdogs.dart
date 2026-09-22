import 'dart:async';
import 'live_playback_models.dart';
import 'package:rxdart/rxdart.dart';

/// Watchdog-driven orchestration for live (non-seekable) streams.
///
/// RxDart is used for watchdog scheduling while the actual live playback
/// semantics remain owned by this class.
///
/// A stall is an inference, not a backend report: the watchdog observed
/// a missing expectation rather than an explicit player error.
///
/// The watchdogs are:
///
/// - [LiveStallKind.sourceReadyTimeout]
///   Opened but produced no playing state in time.
///
/// - [LiveStallKind.unexpectedPauseResumed]
///   Reserved for continuity recovery when an unexpected pause recovers.
///
/// - [LiveStallKind.unexpectedPauseResumeFailed]
///   Reasserted playback did not recover.
///
/// - [LiveStallKind.unexpectedPauseTimeout]
///   Playback remained paused after the continuity retry.
///
/// - [LiveStallKind.bufferingStallTimeout]
///   Buffering never ended within the deadline.
///
/// - [LiveStallKind.videoFrameStallTimeout]
///   Playing state remained true but no new video frame arrived.
///
/// All watchdogs are source-local. The owner should call [cancelAll] when
/// the current source/generation is retired.
final class LiveWatchdogs {
  /// Creates the watchdog bundle.
  LiveWatchdogs({
    this.sourceReadyTimeout = const Duration(seconds: 18),
    this.unexpectedPauseGrace = const Duration(milliseconds: 350),
    this.unexpectedPauseFailureGrace = const Duration(seconds: 5),
    this.bufferingStallTimeout = const Duration(seconds: 12),
    this.videoFrameStallTimeout = const Duration(seconds: 10),
    this.enabled = true,
  });

  /// Opened-but-not-playing deadline.
  ///
  /// Zero disables this watchdog.
  final Duration sourceReadyTimeout;

  /// Grace before an unexpected `playing=false` triggers a resume.
  final Duration unexpectedPauseGrace;

  /// Grace for resumed playback to actually start playing.
  final Duration unexpectedPauseFailureGrace;

  /// Deadline for a single uninterrupted buffering episode.
  final Duration bufferingStallTimeout;

  /// Deadline without any new video frame while playing.
  final Duration videoFrameStallTimeout;

  /// Master switch.
  ///
  /// Disabled watchdogs never arm.
  final bool enabled;

  // ---------------------------------------------------------------------------
  // RxDart event sources
  // ---------------------------------------------------------------------------

  /// Emits whenever a new video frame/progress observation is received.
  ///
  /// The frame watchdog uses switchMap so every new frame cancels the
  /// previous timeout and starts a fresh timeout window.
  final PublishSubject<void> _frameProgress = PublishSubject<void>();

  // ---------------------------------------------------------------------------
  // Active watchdog subscriptions
  // ---------------------------------------------------------------------------

  StreamSubscription<void>? _sourceReadySubscription;
  StreamSubscription<void>? _continuitySubscription;
  StreamSubscription<void>? _bufferingSubscription;
  StreamSubscription<void>? _videoFrameSubscription;

  // ---------------------------------------------------------------------------
  // Current playback observations
  // ---------------------------------------------------------------------------

  bool _playing = false;
  bool _buffering = false;
  bool _presentationVisible = true;
  bool _disposed = false;

  /// Called when a stall is inferred.
  ///
  /// May be invoked from an RxDart timer callback. The owner decides
  /// how recovery should be scheduled.
  void Function(LiveStallKind kind)? onStall;

  /// Called when an unexpected pause should be reasserted.
  ///
  /// Return `true` when the direct `play()` reassertion succeeded.
  /// Returning `false` allows the watchdog to escalate.
  Future<bool> Function()? onReassertPlay;

  // ---------------------------------------------------------------------------
  // Source ready
  // ---------------------------------------------------------------------------

  /// Arms the source-ready deadline after a successful open.
  void armSourceReady() {
    _cancelSourceReady();

    if (!_canWatch || sourceReadyTimeout <= Duration.zero || _playing) {
      return;
    }

    _sourceReadySubscription = TimerStream<void>(null, sourceReadyTimeout).listen((_) {
      if (_disposed) return;

      if (!_playing) {
        onStall?.call(LiveStallKind.sourceReadyTimeout);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Playing state
  // ---------------------------------------------------------------------------

  /// Feeds the playing state from adapter events.
  ///
  /// [fromUserIntent] distinguishes a user pause from a transport hiccup.
  /// Only an unexpected pause starts the continuity watchdog.
  void onPlayingChanged(bool playing, {required bool fromUserIntent}) {
    if (_disposed) return;

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

  // ---------------------------------------------------------------------------
  // Buffering state
  // ---------------------------------------------------------------------------

  /// Feeds the buffering state from adapter events.
  void onBufferingChanged(bool buffering) {
    if (_disposed) return;

    _buffering = buffering;

    if (buffering) {
      _cancelVideoFrameStall();
      _cancelContinuity();
      _armBufferingStall();
      return;
    }

    _cancelBufferingStall();

    if (_playing) {
      _armVideoFrameStall();
    } else {
      _armContinuity();
    }
  }

  // ---------------------------------------------------------------------------
  // Video frame progress
  // ---------------------------------------------------------------------------

  /// Feeds a video-size / frame-progress observation.
  ///
  /// Every frame restarts the video-frame timeout.
  void onFrameProgress() {
    if (_disposed || !_playing || !_presentationVisible) {
      return;
    }

    _frameProgress.add(null);
  }

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  /// Marks whether a route currently owns the mounted video presentation.
  ///
  /// Hidden presentations do not run the frame watchdog.
  void setPresentationVisible(bool visible) {
    if (_disposed) return;

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
  // Continuity watchdog
  // ---------------------------------------------------------------------------

  void _armContinuity() {
    _cancelContinuity();

    if (!_canWatch || unexpectedPauseGrace <= Duration.zero) {
      return;
    }

    _continuitySubscription = TimerStream<void>(null, unexpectedPauseGrace).listen((_) {
      if (_disposed) return;

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

    if (_disposed) return;

    if (resumed && (_playing || _buffering)) {
      return;
    }

    if (!_canWatch || unexpectedPauseFailureGrace <= Duration.zero) {
      onStall?.call(LiveStallKind.unexpectedPauseResumeFailed);
      return;
    }

    _cancelContinuity();

    _continuitySubscription = TimerStream<void>(null, unexpectedPauseFailureGrace).listen((_) {
      if (_disposed) return;

      if (!_playing) {
        onStall?.call(LiveStallKind.unexpectedPauseTimeout);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Buffering watchdog
  // ---------------------------------------------------------------------------

  void _armBufferingStall() {
    _cancelBufferingStall();

    if (!_canWatch || bufferingStallTimeout <= Duration.zero || !_buffering) {
      return;
    }

    _bufferingSubscription = TimerStream<void>(null, bufferingStallTimeout).listen((_) {
      if (_disposed) return;

      if (_buffering) {
        onStall?.call(LiveStallKind.bufferingStallTimeout);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Video frame watchdog
  // ---------------------------------------------------------------------------

  void _armVideoFrameStall() {
    _cancelVideoFrameStall();

    if (!_canWatch || videoFrameStallTimeout <= Duration.zero || !_presentationVisible || !_playing) {
      return;
    }

    // Start a fresh watchdog immediately.
    //
    // Every subsequent frame emits into [_frameProgress]. switchMap cancels
    // the previous TimerStream and creates a new timeout window.
    _videoFrameSubscription = _frameProgress
        .startWith(null)
        .switchMap<void>((_) => TimerStream<void>(null, videoFrameStallTimeout))
        .listen((_) {
          if (_disposed) return;

          if (!_presentationVisible || !_playing) {
            return;
          }

          // One stall is enough. The controller decides whether to recover
          // using the same source, another line, another engine, etc.
          _cancelVideoFrameStall();

          onStall?.call(LiveStallKind.videoFrameStallTimeout);
        });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _canWatch => enabled && !_disposed;

  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  void _cancelSourceReady() {
    _sourceReadySubscription?.cancel();
    _sourceReadySubscription = null;
  }

  void _cancelContinuity() {
    _continuitySubscription?.cancel();
    _continuitySubscription = null;
  }

  void _cancelBufferingStall() {
    _bufferingSubscription?.cancel();
    _bufferingSubscription = null;
  }

  void _cancelVideoFrameStall() {
    _videoFrameSubscription?.cancel();
    _videoFrameSubscription = null;
  }

  /// Cancels every watchdog.
  ///
  /// Call this when:
  ///
  /// - the source changes
  /// - the playback generation changes
  /// - the user pauses
  /// - recovery takes ownership
  /// - the controller closes the current source
  void cancelAll() {
    _cancelSourceReady();
    _cancelContinuity();
    _cancelBufferingStall();
    _cancelVideoFrameStall();
  }

  /// Releases the watchdog bundle.
  void dispose() {
    if (_disposed) return;

    _disposed = true;

    cancelAll();

    onStall = null;
    onReassertPlay = null;

    _frameProgress.close();
  }
}
