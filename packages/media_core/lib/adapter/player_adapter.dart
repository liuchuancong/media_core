import '../core/player_state.dart';
import 'player_adapter_event.dart';
import 'player_adapter_context.dart';
import 'player_adapter_metrics.dart';
import '../source/player_source.dart';
import 'player_adapter_capabilities.dart';

/// Abstract media player backend adapter.
///
/// [PlayerAdapter] is the common interface between
/// media_core and concrete playback engines.
///
/// Implementations may use:
///
/// - media_kit
/// - native player
/// - ffmpeg based backend
/// - platform player
///
/// Responsibilities:
///
/// - control playback backend
/// - expose backend events
/// - provide backend state
///
/// It does not:
///
/// - select backend
/// - create backend instance
/// - handle fallback
///
/// Those belong to:
///
/// - PlayerAdapterFactory
/// - PlayerAdapterSelector
/// - FallbackManager
abstract interface class PlayerAdapter {
  /// Adapter identifier.
  String get id;

  /// Adapter capabilities.
  PlayerAdapterCapabilities get capabilities;

  /// Current adapter state.
  PlayerState get state;

  /// Current metrics.
  PlayerAdapterMetrics get metrics;

  /// Adapter events.
  Stream<PlayerAdapterEvent> get events;

  /// Whether adapter is initialized.
  bool get initialized;

  /// Initializes adapter.
  Future<void> initialize(PlayerAdapterContext context);

  /// Opens a media source.
  Future<void> open(PlayerSource source);

  /// Starts playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback.
  Future<void> stop();

  /// Seeks to position.
  Future<void> seek(Duration position);

  /// Sets volume.
  Future<void> setVolume(double volume);

  /// Sets playback speed.
  Future<void> setRate(double rate);

  /// Closes current source.
  Future<void> close();

  /// Releases adapter resources.
  Future<void> dispose();
}
