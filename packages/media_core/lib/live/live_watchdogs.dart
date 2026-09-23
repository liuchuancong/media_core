import 'dart:async';
import 'live_playback_models.dart';
import 'package:rxdart/rxdart.dart';
import 'package:media_core/adapter/player_adapter_capabilities.dart';

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
///
/// Capability handling follows the single-source-of-truth rule: this
/// class holds a [PlayerAdapterCapabilities] snapshot and reads the
/// fields it cares about directly. It does not declare its own
/// `supportsXxx` flags, mirror getters, or per-capability setters. The
/// snapshot is bound through [updateCapabilities] and re-bound whenever
/// the active adapter changes (fallback, engine switch, close).
///
/// A capability describes what an adapter *can* produce; a session can
/// still rule a signal out. Audio-only playback is that case:
/// [setVideoExpected] with `false` keeps the frame watchdog disarmed for
/// the whole session, because an audio-only source has no video track and
/// therefore never produces the heartbeat it waits for.
final class LiveWatchdogs {
  LiveWatchdogs({
    PlayerAdapterCapabilities? capabilities,
    this.sourceReadyTimeout = const Duration(seconds: 18),
    this.unexpectedPauseGrace = const Duration(milliseconds: 350),
    this.unexpectedPauseFailureGrace = const Duration(seconds: 5),
    this.bufferingStallTimeout = const Duration(seconds: 12),
    this.videoFrameStallTimeout = const Duration(seconds: 10),
    this.enabled = true,
  }) : _capabilities = capabilities;

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
  ///
  /// Only consulted when the bound capability snapshot declares
  /// [PlayerAdapterCapabilities.supportsVideoFrameProgress].
  final Duration videoFrameStallTimeout;

  /// Master switch.
  ///
  /// Disabled watchdogs never arm.
  final bool enabled;

  // ---------------------------------------------------------------------------
  // Bound capabilities
  // ---------------------------------------------------------------------------

  PlayerAdapterCapabilities? _capabilities;

  /// The capability snapshot currently bound to these watchdogs.
  ///
  /// This is a bound view, not the authoritative declaration — the
  /// authority is the adapter's own `capabilities`. Read this only for
  /// diagnostics and tests.
  PlayerAdapterCapabilities? get capabilities => _capabilities;

  /// Binds the capability snapshot of the active adapter.
  ///
  /// Call this whenever the active adapter is created, replaced, or
  /// released:
  ///
  /// - after the handle is bound for a new source
  /// - after the engine is switched via `attachAdapter`
  /// - with null on [close] and [dispose], so a stale snapshot never
  ///   leaks into the next source
  ///
  /// Passing null clears the snapshot; the frame-progress watchdog then
  /// treats the adapter as not supporting the signal.
  ///
  /// Only the fields this bundle actually consumes are read, and they
  /// are read directly from the snapshot. No capability is mirrored as
  /// a field, getter, or constructor parameter here.
  ///
  /// Re-binding is a no-op when the snapshot compares equal, so calling
  /// this on every open with the same adapter does not reset a running
  /// video-frame timeout window. The watchdog only reacts when the
  /// consumed capability (`supportsVideoFrameProgress`) actually
  /// changes value.
  void updateCapabilities(PlayerAdapterCapabilities? capabilities) {
    if (_disposed) return;
    if (_capabilities == capabilities) return;

    final wasSupported = _supportsVideoFrameProgress;
    _capabilities = capabilities;
    final nowSupported = _supportsVideoFrameProgress;

    // Only the frame-progress signal is capability-gated. Re-evaluate
    // it so a live subscription never outlives a change of declaration
    // in either direction. Other watchdogs derive from state
    // transitions and are not affected by capability changes.
    if (wasSupported == nowSupported) return;

    if (!nowSupported) {
      _cancelVideoFrameStall();
      return;
    }

    if (_playing && !_buffering && _presentationVisible) {
      _armVideoFrameStall();
    }
  }

  /// Whether the bound adapter declares a decoded-frame heartbeat.
  bool get _supportsVideoFrameProgress => _capabilities?.supportsVideoFrameProgress ?? false;

  // ---------------------------------------------------------------------------
  // RxDart event sources
  // ---------------------------------------------------------------------------

  /// Emits whenever a new decoded video frame is observed.
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
  bool _videoExpected = true;
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

  /// Feeds a real decoded-video-frame observation.
  ///
  /// This must only be called from [PlayerAdapterEvent.videoFrameProgress].
  ///
  /// Video-size changes, position changes, metadata changes, and other
  /// backend events must not be treated as decoded-frame progress.
  void onFrameProgress() {
    if (_disposed || !_playing || !_presentationVisible || !_supportsVideoFrameProgress) {
      return;
    }

    _frameProgress.add(null);
  }

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  /// Marks whether a route currently owns the mounted video presentation.
  ///
  /// Hidden presentations do not run the frame watchdog. Buffering state
  /// is checked by [armVideoFrameStall] itself, so this method does not
  /// need to duplicate it.
  void setPresentationVisible(bool visible) {
    if (_disposed) return;

    _presentationVisible = visible;

    if (!visible) {
      _cancelVideoFrameStall();
    } else if (_playing) {
      _armVideoFrameStall();
    }
  }

  /// Marks whether decoded video frames are expected for the session.
  ///
  /// Audio-only playback has no video track, so no frame heartbeat can
  /// ever arrive and a missing one proves nothing. Passing `false` keeps
  /// the frame watchdog disarmed instead of inferring a stall from a
  /// signal the session was never going to produce; passing `true` arms
  /// it again for the current playback state.
  ///
  /// This is a session-level mode rather than a per-source state, like
  /// [setPresentationVisible], so it survives source changes.
  void setVideoExpected(bool expected) {
    if (_disposed) return;
    if (_videoExpected == expected) return;

    _videoExpected = expected;

    if (!expected) {
      _cancelVideoFrameStall();
      return;
    }

    if (_playing && !_buffering && _presentationVisible) {
      _armVideoFrameStall();
    }
  }

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

  /// Arms the decoded-frame stall deadline.
  ///
  /// All preconditions are checked here so callers do not need to
  /// remember them:
  ///
  /// - the adapter must declare
  ///   [PlayerAdapterCapabilities.supportsVideoFrameProgress]
  /// - the watchdog must be enabled and the timeout non-zero
  /// - video frames must be expected for the session
  ///   ([setVideoExpected]; false for audio-only playback)
  /// - the mounted presentation must be visible
  /// - playback must be running
  /// - buffering must not be in progress (no frames are expected while
  ///   the engine is filling its cache, so a missing heartbeat is not
  ///   a stall)
  void _armVideoFrameStall() {
    _cancelVideoFrameStall();

    if (!_canWatch ||
        !_supportsVideoFrameProgress ||
        !_videoExpected ||
        videoFrameStallTimeout <= Duration.zero ||
        !_presentationVisible ||
        !_playing ||
        _buffering) {
      return;
    }

    _videoFrameSubscription = _frameProgress
        .startWith(null)
        .switchMap<void>((_) => TimerStream<void>(null, videoFrameStallTimeout))
        .listen((_) {
          if (_disposed) return;

          if (!_presentationVisible || !_playing || !_videoExpected || !_supportsVideoFrameProgress) {
            return;
          }

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

  /// Cancels every watchdog and clears the observations behind them.
  ///
  /// The observed playback flags are dropped together with the timers so
  /// a retired source cannot influence the next one. They are read back
  /// by [armSourceReady] and by [updateCapabilities] when the next
  /// adapter is bound, and a leftover `playing` would either disable the
  /// source-ready deadline or arm the frame deadline before the new
  /// source has produced anything.
  ///
  /// Call this when:
  ///
  /// - the source changes
  /// - the playback generation changes
  /// - the user pauses
  /// - recovery takes ownership
  /// - the controller closes the current source
  void cancelAll() {
    _playing = false;
    _buffering = false;

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
    _capabilities = null;

    _frameProgress.close();
  }
}
