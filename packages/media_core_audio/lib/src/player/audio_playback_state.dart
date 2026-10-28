import 'package:flutter/foundation.dart' show immutable;
import 'package:media_core/media_core.dart' show MathUtils;
import 'package:media_core_audio/src/queue/play_mode.dart';
import 'package:media_core_audio/src/track/music_quality.dart';
import 'package:media_core_audio/src/track/music_track.dart';

/// Everything a music UI needs to render one frame of player state.
///
/// A snapshot rather than a live object: the controller publishes a new one
/// whenever anything changes, so a consumer never has to ask the player, the
/// queue and the source resolver separately and stitch an answer together.
@immutable
final class AudioPlaybackState {
  /// Creates a state snapshot.
  const AudioPlaybackState({
    this.track,
    this.index = -1,
    this.queueLength = 0,
    this.mode = PlayMode.list,
    this.playing = false,
    this.buffering = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.rate = 1.0,
    this.muted = false,
    this.quality,
    this.error,
    this.ended = false,
    this.lyricOffset = Duration.zero,
    this.sleepTimerEndsAt,
    this.pauseAfterCurrentTrack = false,
  });

  /// The idle state, before any track was requested.
  static const AudioPlaybackState idle = AudioPlaybackState();

  /// Current track, if any.
  final MusicTrack? track;

  /// Cursor into the queue.
  final int index;

  /// Number of queued tracks.
  final int queueLength;

  /// Current play mode.
  final PlayMode mode;

  /// Whether audio is running.
  final bool playing;

  /// Whether the engine reports buffering.
  final bool buffering;

  /// Whether a source is being resolved/opened right now.
  final bool loading;

  /// Playback position.
  final Duration position;

  /// Track duration (`Duration.zero` until the engine reports one).
  final Duration duration;

  /// Output volume, 0.0–1.0.
  final double volume;

  /// Playback rate.
  final double rate;

  /// Whether output is muted.
  final bool muted;

  /// Quality actually being served for the current track.
  final MusicQuality? quality;

  /// Last failure, cleared when a new track starts loading.
  final String? error;

  /// Whether playback reached the end of a non-looping queue.
  final bool ended;

  /// Viewer-adjusted lyric delay; positive values delay the highlight.
  final Duration lyricOffset;

  /// When a sleep timer will pause playback, or null when none is armed.
  final DateTime? sleepTimerEndsAt;

  /// Whether playback pauses when the current track ends — the reference's
  /// 定时停止「播完当前歌曲」.
  final bool pauseAfterCurrentTrack;

  /// Time left on the sleep timer, or null when none is armed.
  Duration? get sleepTimerRemaining {
    final endsAt = sleepTimerEndsAt;

    if (endsAt == null) {
      return null;
    }

    final left = endsAt.difference(DateTime.now());

    return left.isNegative ? Duration.zero : left;
  }

  /// Whether a track is loaded.
  bool get hasTrack => track != null;

  /// Progress through the current track, 0.0–1.0.
  double get progress {
    return MathUtils.clampDouble(MathUtils.percent(position.inMilliseconds, duration.inMilliseconds), 0, 1);
  }

  /// Creates a copy with selected fields replaced.
  AudioPlaybackState copyWith({
    MusicTrack? track,
    bool clearTrack = false,
    int? index,
    int? queueLength,
    PlayMode? mode,
    bool? playing,
    bool? buffering,
    bool? loading,
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    bool? muted,
    MusicQuality? quality,
    bool clearQuality = false,
    String? error,
    bool clearError = false,
    bool? ended,
    Duration? lyricOffset,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    bool? pauseAfterCurrentTrack,
  }) {
    return AudioPlaybackState(
      track: clearTrack ? null : (track ?? this.track),
      index: index ?? this.index,
      queueLength: queueLength ?? this.queueLength,
      mode: mode ?? this.mode,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      loading: loading ?? this.loading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      muted: muted ?? this.muted,
      quality: clearQuality ? null : (quality ?? this.quality),
      error: clearError ? null : (error ?? this.error),
      ended: ended ?? this.ended,
      lyricOffset: lyricOffset ?? this.lyricOffset,
      sleepTimerEndsAt: clearSleepTimer ? null : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
      pauseAfterCurrentTrack: pauseAfterCurrentTrack ?? this.pauseAfterCurrentTrack,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioPlaybackState &&
        other.track == track &&
        other.index == index &&
        other.queueLength == queueLength &&
        other.mode == mode &&
        other.playing == playing &&
        other.buffering == buffering &&
        other.loading == loading &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.rate == rate &&
        other.muted == muted &&
        other.quality == quality &&
        other.error == error &&
        other.ended == ended &&
        other.lyricOffset == lyricOffset &&
        other.sleepTimerEndsAt == sleepTimerEndsAt &&
        other.pauseAfterCurrentTrack == pauseAfterCurrentTrack;
  }

  @override
  int get hashCode => Object.hash(
    track,
    index,
    queueLength,
    mode,
    playing,
    buffering,
    loading,
    position,
    duration,
    volume,
    rate,
    muted,
    quality,
    error,
    ended,
    lyricOffset,
    sleepTimerEndsAt,
    pauseAfterCurrentTrack,
  );

  @override
  String toString() =>
      'AudioPlaybackState(${track?.displayName ?? 'idle'}, $index/$queueLength, '
      '${mode.name}${playing ? ', playing' : ''}${loading ? ', loading' : ''}'
      '${buffering ? ', buffering' : ''}${error == null ? '' : ', error: $error'})';
}
