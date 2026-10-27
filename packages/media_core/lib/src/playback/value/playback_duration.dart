import 'package:equatable/equatable.dart';
import 'package:media_core/src/util/collection/math_utils.dart';
import 'package:media_core/src/util/time/time_utils.dart';

/// Playback duration value object.
///
/// Represents total media duration.
///
/// Does not:
///
/// - control playback
/// - perform seeking
/// - calculate renderer layout
final class PlaybackDuration extends Equatable {
  /// Creates a duration of [value].
  const PlaybackDuration({required this.value});

  /// Reads a duration written by [toMap].
  ///
  /// A missing `milliseconds` becomes [Duration.zero], which [isUnknown] then
  /// reports — the same value an engine gives for a length it does not know yet.
  factory PlaybackDuration.fromMap(Map<String, dynamic> map) {
    return PlaybackDuration.fromMilliseconds(map['milliseconds'] as int? ?? 0);
  }

  /// Zero duration.
  const PlaybackDuration.zero() : value = Duration.zero;

  /// Creates from milliseconds.
  factory PlaybackDuration.fromMilliseconds(int milliseconds) {
    return PlaybackDuration(value: Duration(milliseconds: milliseconds));
  }

  /// Total duration.
  final Duration value;

  /// Milliseconds.
  int get milliseconds => value.inMilliseconds;

  /// Seconds.
  double get seconds => TimeUtils.toSeconds(value);

  /// Whether duration exists.
  bool get isValid => milliseconds > 0;

  /// Whether unknown duration.
  bool get isUnknown => value == Duration.zero;

  /// Compare.
  bool operator <(PlaybackDuration other) {
    return value < other.value;
  }

  /// Whether this duration is longer than [other].
  bool operator >(PlaybackDuration other) {
    return value > other.value;
  }

  /// Creates remaining duration.
  Duration remaining(Duration position) {
    final result = value - position;

    if (result < Duration.zero) {
      return Duration.zero;
    }

    return result;
  }

  /// Calculates progress.
  double progress(Duration position) {
    return MathUtils.clampDouble(MathUtils.percent(position.inMilliseconds, milliseconds), 0, 1);
  }

  /// The `fromMap()` form: duration as whole milliseconds, so any sub-millisecond
  /// remainder is dropped.
  Map<String, dynamic> toMap() {
    return {'milliseconds': milliseconds};
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() {
    return 'PlaybackDuration('
        '${value.inMilliseconds}ms)';
  }
}
