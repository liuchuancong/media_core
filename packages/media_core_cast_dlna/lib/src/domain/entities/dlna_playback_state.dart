import 'package:media_core_cast_dlna/src/domain/enums/dlna_transport_state.dart';
import 'package:meta/meta.dart';

/// A snapshot of what the renderer is doing (§19.3).
///
/// Built from device answers (polls now, GENA in Phase 7) and merged
/// with command-driven updates. Every field is what the device last
/// *said* — this package never passes off its own prediction as device
/// state.
@immutable
final class DlnaPlaybackState {
  /// Creates a snapshot.
  const DlnaPlaybackState({
    required this.updatedAt,
    this.transportState = DlnaTransportState.unknown,
    this.position,
    this.duration,
    this.currentUri,
    this.currentTitle,
    this.volume,
    this.isMuted,
  });

  /// The transport state as of [updatedAt].
  final DlnaTransportState transportState;

  /// The playhead position, when the device reported one.
  final Duration? position;

  /// The media duration, when the device reported one.
  final Duration? duration;

  /// The URI the device has loaded, when known.
  final String? currentUri;

  /// The title this session cast, when a media was set.
  final String? currentTitle;

  /// The device volume (0..100), once RenderingControl lands (Phase 8).
  final int? volume;

  /// The device mute state, once RenderingControl lands (Phase 8).
  final bool? isMuted;

  /// When any part of this snapshot was last refreshed.
  final DateTime updatedAt;

  /// Whether the device appears to still be playing.
  bool get isPlaying => transportState == DlnaTransportState.playing;

  /// Rebuilds this snapshot with [updatedAt] advanced and the given
  /// fields replaced; fields left null keep their current value.
  ///
  /// Explicitly pass a value to clear a field (the device stopped
  /// reporting it); absent means "unchanged", which is what a position
  /// poll that only answered part of its arguments should mean.
  DlnaPlaybackState copyWith({
    DlnaTransportState? transportState,
    Duration? position,
    Duration? duration,
    String? currentUri,
    String? currentTitle,
    int? volume,
    bool? isMuted,
    DateTime? updatedAt,
  }) {
    return DlnaPlaybackState(
      transportState: transportState ?? this.transportState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentUri: currentUri ?? this.currentUri,
      currentTitle: currentTitle ?? this.currentTitle,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'DlnaPlaybackState($transportState, $position/$duration, updated $updatedAt)';
}
