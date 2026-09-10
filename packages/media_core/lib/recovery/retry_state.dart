import 'package:equatable/equatable.dart';

/// Describes the state of a retry sequence.
///
/// `RetryState` only tracks retry scheduling and attempt information.
/// It does not decide whether a recovery should be attempted and does
/// not execute the retry itself.
final class RetryState extends Equatable {
  const RetryState({
    required this.attempt,
    required this.maxAttempts,
    required this.active,
    required this.exhausted,
    required this.scheduled,
    required this.nextDelay,
  });

  /// Initial retry state.
  const RetryState.initial({this.maxAttempts = 3})
    : attempt = 0,
      active = false,
      exhausted = false,
      scheduled = false,
      nextDelay = Duration.zero;

  /// Number of attempts that have already been performed.
  final int attempt;

  /// Maximum number of attempts allowed.
  final int maxAttempts;

  /// Whether the retry sequence is active.
  final bool active;

  /// Whether no further retry attempts are available.
  final bool exhausted;

  /// Whether a retry is currently scheduled.
  final bool scheduled;

  /// Delay before the next retry attempt.
  final Duration nextDelay;

  /// Whether another retry attempt can be performed.
  bool get canRetry {
    return !exhausted && attempt < maxAttempts;
  }

  /// Whether the retry sequence has reached its limit.
  bool get hasReachedLimit {
    return attempt >= maxAttempts;
  }

  /// Creates a modified retry state.
  RetryState copyWith({
    int? attempt,
    int? maxAttempts,
    bool? active,
    bool? exhausted,
    bool? scheduled,
    Duration? nextDelay,
  }) {
    return RetryState(
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      active: active ?? this.active,
      exhausted: exhausted ?? this.exhausted,
      scheduled: scheduled ?? this.scheduled,
      nextDelay: nextDelay ?? this.nextDelay,
    );
  }

  /// Starts a retry sequence.
  RetryState start() {
    return copyWith(active: true, exhausted: false, scheduled: false, nextDelay: Duration.zero);
  }

  /// Schedules the next retry.
  RetryState schedule(Duration delay) {
    if (!canRetry) {
      return copyWith(active: false, exhausted: true, scheduled: false, nextDelay: Duration.zero);
    }

    return copyWith(active: true, scheduled: true, nextDelay: delay);
  }

  /// Records a performed retry attempt.
  RetryState recordAttempt() {
    final nextAttempt = attempt + 1;
    final exhausted = nextAttempt >= maxAttempts;

    return copyWith(
      attempt: nextAttempt,
      active: !exhausted,
      scheduled: false,
      exhausted: exhausted,
      nextDelay: Duration.zero,
    );
  }

  /// Marks the retry sequence as completed.
  RetryState complete() {
    return copyWith(active: false, scheduled: false, nextDelay: Duration.zero);
  }

  /// Cancels the current retry sequence.
  RetryState cancel() {
    return copyWith(active: false, scheduled: false, nextDelay: Duration.zero);
  }

  /// Resets all retry information.
  RetryState reset() {
    return RetryState(
      attempt: 0,
      maxAttempts: maxAttempts,
      active: false,
      exhausted: false,
      scheduled: false,
      nextDelay: Duration.zero,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attempt': attempt,
      'maxAttempts': maxAttempts,
      'active': active,
      'exhausted': exhausted,
      'scheduled': scheduled,
      'nextDelay': nextDelay.inMilliseconds,
    };
  }

  factory RetryState.fromMap(Map<String, dynamic> map) {
    return RetryState(
      attempt: map['attempt'] as int? ?? 0,
      maxAttempts: map['maxAttempts'] as int? ?? 3,
      active: map['active'] as bool? ?? false,
      exhausted: map['exhausted'] as bool? ?? false,
      scheduled: map['scheduled'] as bool? ?? false,
      nextDelay: Duration(milliseconds: (map['nextDelay'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  List<Object?> get props => [attempt, maxAttempts, active, exhausted, scheduled, nextDelay];

  @override
  String toString() {
    return 'RetryState('
        'attempt=$attempt, '
        'maxAttempts=$maxAttempts, '
        'active=$active, '
        'scheduled=$scheduled, '
        'exhausted=$exhausted)';
  }
}
