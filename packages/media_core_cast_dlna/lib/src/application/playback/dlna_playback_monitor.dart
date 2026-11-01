import 'dart:async';

import 'package:media_core_cast_dlna/src/domain/enums/dlna_transport_state.dart';

/// Polling cadence for a session's playback monitor (§19.2).
///
/// The defaults are the doc's initial engineering policy and are meant
/// to be tuned by hosts: playing reads fast enough for a smooth
/// progress bar, paused reads slowly enough not to nag a device that is
/// just sitting there, and stopped reads nothing — a stopped renderer
/// has no playhead to advance.
final class DlnaPlaybackMonitorOptions {
  /// Creates options.
  const DlnaPlaybackMonitorOptions({
    this.playingInterval = const Duration(seconds: 2),
    this.pausedInterval = const Duration(seconds: 8),
  });

  /// The read interval while the device reports playing.
  final Duration playingInterval;

  /// The read interval while the device reports paused.
  final Duration pausedInterval;
}

/// Drives a session's state polling (§19).
///
/// The monitor owns only the *cadence*: the transport state tells it how
/// often to fire (playing fast, paused slow, stopped/idle never), and
/// each tick asks the session to read the device and merge. GENA
/// subscription (Phase 7) will replace most ticks with pushes; this
/// stays as the fallback every device understands.
///
/// A tick never overlaps the next one: the timer is only rescheduled
/// after the read completes, so a slow device cannot stack reads.
final class DlnaPlaybackMonitor {
  /// Creates a monitor.
  DlnaPlaybackMonitor({required this.onTick, this.options = const DlnaPlaybackMonitorOptions()});

  /// Called on every scheduled tick; the reader is responsible for
  /// error handling — a failed read must not kill the cadence.
  final void Function() onTick;

  /// The cadence tunables.
  final DlnaPlaybackMonitorOptions options;

  Timer? _timer;
  bool _running = false;
  bool _tickInFlight = false;

  /// Whether the monitor is polling.
  bool get running => _running;

  /// The current transport state as last reported by the session.
  DlnaTransportState _transportState = DlnaTransportState.unknown;

  /// Starts the cadence. Idempotent.
  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _schedule();
  }

  /// Feeds the latest transport state in; the cadence adapts (§19.2:
  /// a state change should also cause an immediate read, which the
  /// session triggers itself).
  void updateTransportState(DlnaTransportState state) {
    _transportState = state;
    _schedule();
  }

  /// Stops the cadence without forgetting the state.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Stops and resets.
  void dispose() {
    stop();
    _transportState = DlnaTransportState.unknown;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_running || _tickInFlight) {
      return;
    }
    final interval = switch (_transportState) {
      DlnaTransportState.playing => options.playingInterval,
      DlnaTransportState.paused || DlnaTransportState.transitioning => options.pausedInterval,
      // A stopped renderer has no playhead to advance; a read storm
      // against a device with no media helps nobody.
      DlnaTransportState.stopped || DlnaTransportState.noMediaPresent || DlnaTransportState.unknown => null,
    };
    if (interval == null) {
      return;
    }
    _timer = Timer(interval, _tick);
  }

  Future<void> _tick() async {
    if (!_running || _tickInFlight) {
      return;
    }
    _tickInFlight = true;
    try {
      onTick();
    } finally {
      _tickInFlight = false;
      _schedule();
    }
  }
}
