import 'recovery_step.dart';
import 'package:equatable/equatable.dart';

/// Attempt budget of one recovery ladder run.
///
/// A single `maxAttempts` cannot describe the ladder: reopening the same
/// backend, cycling sources and attaching another backend are different
/// resources, and a failure in one of them must not consume the budget
/// of the others. The budget therefore counts four dimensions plus a
/// global ceiling that guarantees the ladder terminates.
final class RecoveryBudget extends Equatable {
  /// Creates a budget.
  const RecoveryBudget({
    this.maxSameBackendAttempts = 3,
    this.maxLineAttempts = 4,
    this.maxBackendAttempts = 3,
    this.maxBackoffAttempts = 2,
    this.maxTotalAttempts = 12,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 8),
    this.backoffFactor = 2.0,
  });

  /// Maximum same-backend reopens per ladder run.
  final int maxSameBackendAttempts;

  /// Maximum source switches per ladder run.
  final int maxLineAttempts;

  /// Maximum backend swaps per ladder run.
  final int maxBackendAttempts;

  /// Maximum backoff waits per ladder run.
  ///
  /// Each wait is followed by a full rescan of the ladder, so this also
  /// bounds how often the escalation is retried from the top.
  final int maxBackoffAttempts;

  /// Ceiling across every dimension.
  ///
  /// The per-dimension limits alone do not bound the run: the ladder
  /// rescans after each wait, so it needs one counter that only ever
  /// grows. This is that counter.
  final int maxTotalAttempts;

  /// Delay before the first backoff wait.
  final Duration initialBackoff;

  /// Upper bound for a single backoff wait.
  final Duration maxBackoff;

  /// Multiplier applied per backoff wait.
  final double backoffFactor;

  /// Default budget.
  static const RecoveryBudget defaults = RecoveryBudget();

  /// Budget that performs no recovery at all.
  static const RecoveryBudget none = RecoveryBudget(
    maxSameBackendAttempts: 0,
    maxLineAttempts: 0,
    maxBackendAttempts: 0,
    maxBackoffAttempts: 0,
    maxTotalAttempts: 0,
  );

  /// Whether this budget allows any physical recovery step.
  bool get allowsRecovery {
    return maxTotalAttempts > 0 &&
        (maxSameBackendAttempts > 0 || maxLineAttempts > 0 || maxBackendAttempts > 0);
  }

  /// Whether waiting is allowed at all.
  bool get allowsBackoff => maxBackoffAttempts > 0 && maxTotalAttempts > 0;

  /// Attempt limit for [kind].
  int limitFor(RecoveryStepKind kind) {
    return switch (kind) {
      RecoveryStepKind.sameBackendReopen => maxSameBackendAttempts,
      RecoveryStepKind.nextLine => maxLineAttempts,
      RecoveryStepKind.nextBackend => maxBackendAttempts,
      RecoveryStepKind.backoff => maxBackoffAttempts,
    };
  }

  /// Delay before backoff attempt [attempt] (zero-based).
  ///
  /// The delay grows geometrically from [initialBackoff] and is capped
  /// at [maxBackoff]. Negative attempts collapse to [initialBackoff] so
  /// a caller that lost count still gets a sane value.
  Duration delayFor(int attempt) {
    if (attempt <= 0 || backoffFactor <= 1.0) {
      return _clamp(initialBackoff);
    }

    final scaled = initialBackoff.inMilliseconds * _pow(backoffFactor, attempt);

    return _clamp(Duration(milliseconds: scaled.round()));
  }

  Duration _clamp(Duration value) {
    if (value > maxBackoff) {
      return maxBackoff;
    }

    if (value < Duration.zero) {
      return Duration.zero;
    }

    return value;
  }

  static double _pow(double base, int exponent) {
    var result = 1.0;

    for (var index = 0; index < exponent; index++) {
      result *= base;
    }

    return result;
  }

  /// Creates a copy with selected values replaced.
  RecoveryBudget copyWith({
    int? maxSameBackendAttempts,
    int? maxLineAttempts,
    int? maxBackendAttempts,
    int? maxBackoffAttempts,
    int? maxTotalAttempts,
    Duration? initialBackoff,
    Duration? maxBackoff,
    double? backoffFactor,
  }) {
    return RecoveryBudget(
      maxSameBackendAttempts: maxSameBackendAttempts ?? this.maxSameBackendAttempts,
      maxLineAttempts: maxLineAttempts ?? this.maxLineAttempts,
      maxBackendAttempts: maxBackendAttempts ?? this.maxBackendAttempts,
      maxBackoffAttempts: maxBackoffAttempts ?? this.maxBackoffAttempts,
      maxTotalAttempts: maxTotalAttempts ?? this.maxTotalAttempts,
      initialBackoff: initialBackoff ?? this.initialBackoff,
      maxBackoff: maxBackoff ?? this.maxBackoff,
      backoffFactor: backoffFactor ?? this.backoffFactor,
    );
  }

  /// Returns a budget with same-backend reopen disabled.
  RecoveryBudget withoutSameBackend() => copyWith(maxSameBackendAttempts: 0);

  /// Returns a budget with source switching disabled.
  RecoveryBudget withoutLines() => copyWith(maxLineAttempts: 0);

  /// Returns a budget with backend switching disabled.
  RecoveryBudget withoutBackends() => copyWith(maxBackendAttempts: 0);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'maxSameBackendAttempts': maxSameBackendAttempts,
      'maxLineAttempts': maxLineAttempts,
      'maxBackendAttempts': maxBackendAttempts,
      'maxBackoffAttempts': maxBackoffAttempts,
      'maxTotalAttempts': maxTotalAttempts,
      'initialBackoffMs': initialBackoff.inMilliseconds,
      'maxBackoffMs': maxBackoff.inMilliseconds,
      'backoffFactor': backoffFactor,
    };
  }

  @override
  List<Object?> get props => <Object?>[
    maxSameBackendAttempts,
    maxLineAttempts,
    maxBackendAttempts,
    maxBackoffAttempts,
    maxTotalAttempts,
    initialBackoff,
    maxBackoff,
    backoffFactor,
  ];

  @override
  String toString() {
    return 'RecoveryBudget('
        'reopen: $maxSameBackendAttempts, '
        'lines: $maxLineAttempts, '
        'backends: $maxBackendAttempts, '
        'backoff: $maxBackoffAttempts, '
        'total: $maxTotalAttempts'
        ')';
  }
}
