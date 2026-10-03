import 'dart:async';

import 'package:flame_barrage/flame_barrage.dart';
import 'package:media_core/media_core.dart';

/// Drives a [BarrageController] from a player's transport state.
///
/// The engine has no idea a video exists: it advances its own clock and
/// dispatches what it is given. Something has to make that clock mean the
/// media's time, and that is this binding — play and pause together, seek
/// together, and at the same rate. Without it a paused video keeps scrolling
/// its comments, a 2× video shows them at 1×, and a drag along the progress
/// bar leaves last minute's lines on screen.
///
/// It listens to commands rather than inferring intent from positions: the
/// transport state says when a seek happened, so there is no "the position
/// jumped, therefore the user dragged" guess to get wrong.
///
/// Constructed from streams so it is testable without a player; use
/// [DanmakuPlayerBinding.forHandle] to wire a [PlayerHandle].
final class DanmakuPlayerBinding {
  /// Creates a binding fed by explicit streams.
  ///
  /// [visible] is optional and exists for surfaces that come and go — a
  /// picture-in-picture window, a wall of cells where only the focused one
  /// shows comments. When it is supplied, hiding pauses the engine and
  /// showing resumes it.
  DanmakuPlayerBinding({
    required this.controller,
    required Stream<PlayerTransportState> playback,
    Stream<PlayerSource?>? sourceChanges,
    Stream<bool>? visible,
    this.syncSeek = true,
  }) : _playback = playback,
       _sourceChanges = sourceChanges,
       _visible = visible;

  /// Creates a binding on [handle]'s own streams.
  factory DanmakuPlayerBinding.forHandle({
    required BarrageController controller,
    required PlayerHandle handle,
    Stream<bool>? visible,
    bool syncSeek = true,
  }) {
    return DanmakuPlayerBinding(
      controller: controller,
      playback: handle.playbackStream,
      sourceChanges: handle.sourceChanges,
      visible: visible,
      syncSeek: syncSeek,
    );
  }

  /// The engine facade this binding drives.
  final BarrageController controller;

  /// Whether a seek moves the comment timeline too.
  ///
  /// On by default and harmless for a live room: a live source has no timeline
  /// loaded, so there is nothing to move. Turn it off for a host that wants
  /// comments to keep flowing across a seek.
  final bool syncSeek;

  final Stream<PlayerTransportState> _playback;
  final Stream<PlayerSource?>? _sourceChanges;
  final Stream<bool>? _visible;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _visibleNow = true;
  bool _disposed = false;

  /// Starts listening. Idempotent.
  void attach() {
    if (_disposed || _subscriptions.isNotEmpty) {
      return;
    }

    _subscriptions.add(_playback.listen(_onTransport));

    final sources = _sourceChanges;
    if (sources != null) {
      _subscriptions.add(sources.listen(_onSource));
    }

    final visibility = _visible;
    if (visibility != null) {
      _subscriptions.add(visibility.listen(_onVisible));
    }
  }

  /// Stops listening and leaves the engine alone.
  ///
  /// The controller is not disposed here: a host may keep it across players
  /// (a wall reusing one engine, a page that rebuilds its handle). Call
  /// [BarrageController.dispose] where the controller is owned.
  Future<void> detach() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Detaches and marks the binding unusable.
  Future<void> dispose() async {
    await detach();
    _disposed = true;
  }

  void _onTransport(PlayerTransportState state) {
    switch (state.command) {
      case PlaybackCommandPlay():
        _resumeIfVisible();
      case PlaybackCommandPause():
      case PlaybackCommandStop():
        controller.pause();
      case PlaybackCommandSeek(:final position):
        if (syncSeek) {
          controller.seekTo(position);
        }
      case PlaybackCommandIdle():
      case PlaybackCommandLoading():
      case PlaybackCommandPosition():
      case PlaybackCommandDuration():
      case PlaybackCommandBuffering():
      case PlaybackCommandVolume():
      case PlaybackCommandBuffered():
        break;
      case PlaybackCommandRate(:final rate):
        // The engine clamps, so a 16× debug rate degrades to its own maximum
        // instead of throwing here.
        controller.playbackRate = rate;
    }

    // Buffering is not a pause: the video stalled, but the comment clock is
    // the media's clock, and the media resumes from where it stalled.
  }

  void _onSource(PlayerSource? source) {
    // A new source must not inherit the previous room's comments, and a
    // timeline loaded for the old video is now wrong by definition.
    controller.clear();
    if (source != null) {
      controller.playbackRate = 1.0;
    }
  }

  void _onVisible(bool visible) {
    _visibleNow = visible;
    if (visible) {
      _resumeIfVisible();
    } else {
      controller.pause();
    }
  }

  /// Resumes only when the surface is actually shown.
  ///
  /// Without this a hidden window would start scrolling comments nobody can
  /// see, paying the shaping and raster cost for nothing.
  void _resumeIfVisible() {
    if (_visibleNow) {
      controller.resume();
    }
  }
}
