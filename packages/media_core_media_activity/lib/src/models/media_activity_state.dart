import 'package:flutter/foundation.dart';

/// Dynamic content of one Media Activity (ActivityKit `ContentState`).
///
/// Time rules (spec §6.1): [positionMs] is whole milliseconds; [playbackRate]
/// is the only double. The lock screen advances its displayed progress by
/// `rate × Δt` between updates, so Dart only pushes when a lyric boundary,
/// play state, seek or track actually changes — never on a timer (spec §8.1).
@immutable
final class MediaActivityContentState {
  /// Creates one dynamic snapshot of the activity.
  const MediaActivityContentState({
    required this.currentLyric,
    required this.isPlaying,
    required this.positionMs,
    this.nextLyric = '',
    this.playbackRate = 1.0,
    this.lyricRevision = 0,
  });

  /// The lyric line on screen right now; empty when the track has none —
  /// the activity then shows track information only (spec §16).
  final String currentLyric;

  /// Preview of the following line; empty when there is none.
  final String nextLyric;

  /// Whether playback is advancing. A paused activity keeps its song
  /// information and lyric, and stops receiving lyric updates (spec §9.4).
  final bool isPlaying;

  /// Playback position at the moment of the update, in milliseconds.
  final int positionMs;

  /// Playback speed (0 while paused); drives the lock-screen clock drift
  /// between updates.
  final double playbackRate;

  /// Monotonic revision of the lyric payload; the controller increments it
  /// so an out-of-order channel reply can never overwrite newer content.
  final int lyricRevision;

  /// Returns a copy with the named fields replaced, leaving the rest as-is.
  MediaActivityContentState copyWith({
    String? currentLyric,
    String? nextLyric,
    bool? isPlaying,
    int? positionMs,
    double? playbackRate,
    int? lyricRevision,
  }) {
    return MediaActivityContentState(
      currentLyric: currentLyric ?? this.currentLyric,
      nextLyric: nextLyric ?? this.nextLyric,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      playbackRate: playbackRate ?? this.playbackRate,
      lyricRevision: lyricRevision ?? this.lyricRevision,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MediaActivityContentState &&
      other.currentLyric == currentLyric &&
      other.nextLyric == nextLyric &&
      other.isPlaying == isPlaying &&
      other.positionMs == positionMs &&
      other.playbackRate == playbackRate &&
      other.lyricRevision == lyricRevision;

  @override
  int get hashCode => Object.hash(
        currentLyric,
        nextLyric,
        isPlaying,
        positionMs,
        playbackRate,
        lyricRevision,
      );

  @override
  String toString() =>
      'MediaActivityContentState(playing: $isPlaying, ${positionMs}ms, '
      'rate $playbackRate, rev $lyricRevision, "${currentLyric.length > 24 ? '${currentLyric.substring(0, 24)}…' : currentLyric}")';
}
