import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_adapter_event.freezed.dart';

/// Events emitted by a player adapter.
///
/// [PlayerAdapterEvent] represents changes and
/// notifications from a playback backend.
///
/// Responsibilities:
///
/// - describe adapter events
/// - transport backend notifications
///
/// It does not:
///
/// - store current state
/// - dispatch events
/// - manage lifecycle
///
/// Those belong to:
///
/// - PlayerAdapterState
/// - EventDispatcher
/// - PlayerSession
@freezed
abstract class PlayerAdapterEvent with _$PlayerAdapterEvent {
  /// Creates adapter event.
  const factory PlayerAdapterEvent.opened({
    /// Opened source identifier.
    String? source,
  }) = PlayerAdapterOpened;

  /// Playback started.
  const factory PlayerAdapterEvent.playing() = PlayerAdapterPlaying;

  /// Playback paused.
  const factory PlayerAdapterEvent.paused() = PlayerAdapterPaused;

  /// Playback stopped.
  const factory PlayerAdapterEvent.stopped() = PlayerAdapterStopped;

  /// Buffering state changed.
  const factory PlayerAdapterEvent.buffering({
    /// Whether buffering is active.
    required bool buffering,

    /// Optional buffering percentage.
    double? progress,
  }) = PlayerAdapterBuffering;

  /// Playback completed.
  const factory PlayerAdapterEvent.completed() = PlayerAdapterCompleted;

  /// Position changed.
  const factory PlayerAdapterEvent.positionChanged({required Duration position}) = PlayerAdapterPositionChanged;

  /// Duration changed.
  const factory PlayerAdapterEvent.durationChanged({required Duration duration}) = PlayerAdapterDurationChanged;

  /// Video size changed.
  const factory PlayerAdapterEvent.videoSizeChanged({required int width, required int height}) =
      PlayerAdapterVideoSizeChanged;

  /// Volume changed.
  const factory PlayerAdapterEvent.volumeChanged({required double volume}) = PlayerAdapterVolumeChanged;

  /// Playback rate changed.
  const factory PlayerAdapterEvent.rateChanged({required double rate}) = PlayerAdapterRateChanged;

  /// Adapter error occurred.
  const factory PlayerAdapterEvent.error({required String message, Object? error, StackTrace? stackTrace}) =
      PlayerAdapterErrorEvent;
}

/// Extensions for adapter events.
extension PlayerAdapterEventExtension on PlayerAdapterEvent {
  /// Whether this event represents an error.
  bool get isError {
    return this is PlayerAdapterErrorEvent;
  }

  /// Whether event affects playback state.
  bool get affectsPlayback {
    return switch (this) {
      PlayerAdapterPlaying() || PlayerAdapterPaused() || PlayerAdapterStopped() || PlayerAdapterCompleted() => true,
      _ => false,
    };
  }

  /// Whether event affects media geometry.
  bool get affectsGeometry {
    return this is PlayerAdapterVideoSizeChanged;
  }
}
