/// Public library for the `live` module.
///
/// Watchdog-driven orchestration for live (non-seekable) streams
/// on top of the player kernel: stall inference, line fallback,
/// engine fallback and backoff retry.
library;

export 'live_playback_controller.dart';
export 'live_playback_models.dart';
export 'live_playback_state.dart';
export 'live_watchdogs.dart';
