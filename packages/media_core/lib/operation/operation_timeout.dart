import 'operation.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

/// Describes the lifecycle state of an operation.
///
/// [OperationState] is an immutable value object rather than a Dart enum.
/// Built-in states provide the standard operation lifecycle while custom
/// states allow extensions without changing this class.
///
/// Operation state describes **where an operation is in its lifecycle**.
///
/// Scheduling states such as `queued` belong to [TaskState], because task
/// scheduling and operation lifecycle are intentionally separated.
///
/// Standard lifecycle:
///
/// ```text
/// created
///    │
///    ├── running
///    │      ├── completed
///    │      ├── failed
///    │      └── cancelled
///    │
///    └── cancelled
/// ```
///
/// Terminal states cannot transition to another state.
final class OperationState implements Comparable<OperationState> {
  const OperationState._(this.value, this.name);

  /// Creates a custom operation state.
  ///
  /// Custom values are normalized by trimming leading and trailing
  /// whitespace.
  ///
  /// An empty value is not allowed.
  factory OperationState.custom(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Operation state cannot be empty.');
    }

    return OperationState._(normalized, normalized);
  }

  // ---------------------------------------------------------------------------
  // Built-in states
  // ---------------------------------------------------------------------------

  /// Operation has been created but has not started.
  static const OperationState created = OperationState._('created', 'Created');

  /// Operation is currently executing.
  static const OperationState running = OperationState._('running', 'Running');

  /// Operation completed successfully.
  static const OperationState completed = OperationState._('completed', 'Completed');

  /// Operation failed.
  static const OperationState failed = OperationState._('failed', 'Failed');

  /// Operation was cancelled.
  static const OperationState cancelled = OperationState._('cancelled', 'Cancelled');

  // ---------------------------------------------------------------------------
  // Built-in values
  // ---------------------------------------------------------------------------

  static const Set<String> _builtInValues = <String>{'created', 'running', 'completed', 'failed', 'cancelled'};

  /// All built-in operation states.
  static const List<OperationState> values = <OperationState>[created, running, completed, failed, cancelled];

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// Stable machine-readable state value.
  final String value;

  /// Human-readable state name.
  final String name;

  /// Whether this is one of the built-in states.
  bool get isBuiltIn => _builtInValues.contains(value);

  /// Whether this is a custom state.
  bool get isCustom => !isBuiltIn;

  /// Whether this state is the initial operation state.
  bool get isCreated => value == created.value;

  /// Whether this operation is currently running.
  bool get isRunning => value == running.value;

  /// Whether this operation completed successfully.
  bool get isCompleted => value == completed.value;

  /// Whether this operation failed.
  bool get isFailed => value == failed.value;

  /// Whether this operation was cancelled.
  bool get isCancelled => value == cancelled.value;

  /// Whether this is a terminal state.
  ///
  /// Terminal states:
  ///
  /// - completed
  /// - failed
  /// - cancelled
  bool get isTerminal {
    return isCompleted || isFailed || isCancelled;
  }

  /// Whether this state represents an operation that has not started.
  bool get isPending => isCreated;

  /// Whether this state represents an actively executing operation.
  bool get isActive => isRunning;

  /// Whether this operation completed successfully.
  bool get isSuccess => isCompleted;

  /// Whether this operation ended unsuccessfully.
  ///
  /// Cancellation is intentionally treated separately from failure.
  bool get isFailure => isFailed;

  /// Whether this state can be cancelled.
  bool get canCancel {
    return isCreated || isRunning;
  }

  /// Whether this state can be started.
  bool get canStart => isCreated;

  /// Whether this state can be completed.
  bool get canComplete => isRunning;

  /// Whether this state can be failed.
  bool get canFail => isRunning;

  // ---------------------------------------------------------------------------
  // Transition graph
  // ---------------------------------------------------------------------------

  /// Returns all legal next states from this state.
  ///
  /// The lifecycle graph is:
  ///
  /// ```text
  /// created -> running
  /// created -> cancelled
  ///
  /// running -> completed
  /// running -> failed
  /// running -> cancelled
  ///
  /// completed -> none
  /// failed    -> none
  /// cancelled -> none
  /// ```
  List<OperationState> get nextStates {
    if (isCreated) {
      return const <OperationState>[running, cancelled];
    }

    if (isRunning) {
      return const <OperationState>[completed, failed, cancelled];
    }

    return const <OperationState>[];
  }

  /// Returns whether this state can transition to [target].
  bool canTransitionTo(OperationState target) {
    if (this == target) {
      return false;
    }

    return nextStates.contains(target);
  }

  /// Validates a transition to [target].
  ///
  /// Throws [StateError] when the transition is not legal.
  void validateTransitionTo(OperationState target) {
    if (!canTransitionTo(target)) {
      throw StateError(
        'Invalid operation state transition: '
        '$value -> ${target.value}.',
      );
    }
  }

  /// Returns whether this state has [target] as a legal next state.
  bool hasNextState(OperationState target) {
    return nextStates.contains(target);
  }

  /// Returns whether [target] is a valid terminal state.
  static bool isValidTerminalState(OperationState target) {
    return target.isCompleted || target.isFailed || target.isCancelled;
  }

  /// Returns whether this state can transition to a terminal state.
  bool get canTerminate => isRunning;

  // ---------------------------------------------------------------------------
  // Conversion
  // ---------------------------------------------------------------------------

  /// Returns the stable state value.
  String toValue() => value;

  /// Returns the stable state value for JSON serialization.
  String toJson() => value;

  /// Creates a state from JSON.
  ///
  /// Unknown values are represented as custom states.
  factory OperationState.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('OperationState JSON value must be a String.');
    }

    return OperationState.fromValue(json);
  }

  /// Creates a state from its stable string value.
  ///
  /// Built-in values return their canonical instances.
  /// Unknown values become custom states.
  factory OperationState.fromValue(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Operation state cannot be empty.');
    }

    for (final state in values) {
      if (state.value == normalized) {
        return state;
      }
    }

    return OperationState.custom(normalized);
  }

  /// Parses an operation state from a string.
  static OperationState parse(String value) {
    return OperationState.fromValue(value);
  }

  /// Returns whether [value] is a valid operation state.
  static bool isValid(String value) {
    return value.trim().isNotEmpty;
  }

  /// Returns whether [value] represents a built-in state.
  static bool isBuiltInValue(String value) {
    return _builtInValues.contains(value.trim());
  }

  /// Attempts to parse an operation state.
  ///
  /// Returns `null` when [value] is empty.
  static OperationState? tryParse(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return OperationState.fromValue(normalized);
  }

  // ---------------------------------------------------------------------------
  // Value helpers
  // ---------------------------------------------------------------------------

  /// Creates a custom state with [value].
  ///
  /// This method intentionally creates a custom value instead of attempting
  /// to return a built-in singleton.
  ///
  /// Use [fromValue] when canonical built-in values are desired.
  OperationState copyWith(String value) {
    return OperationState.custom(value);
  }

  /// Returns whether this state has the same value as [other].
  bool isSameAs(OperationState other) {
    return this == other;
  }

  /// Returns whether this state has a different value from [other].
  bool isDifferentFrom(OperationState other) {
    return this != other;
  }

  // ---------------------------------------------------------------------------
  // Comparable / equality
  // ---------------------------------------------------------------------------

  @override
  int compareTo(OperationState other) {
    return value.compareTo(other.value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is OperationState && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'OperationState($value)';
  }
}

/// Defines timeout behavior for an operation.
///
/// [OperationTimeout] is an immutable value object that describes how long
/// an operation is allowed to remain active.
///
/// It does not:
///
/// - cancel an operation;
/// - change [OperationState];
/// - schedule an operation;
/// - complete or fail an operation.
///
/// Those responsibilities belong to the operation lifecycle and coordination
/// layers.
///
/// Example:
///
/// ```dart
/// const timeout = OperationTimeout(
///   duration: Duration(seconds: 15),
/// );
///
/// if (timeout.isExpired(operation)) {
///   // Handle timeout.
/// }
/// ```
final class OperationTimeout extends Equatable {
  /// Creates an operation timeout definition.
  ///
  /// [duration] must be positive.
  const OperationTimeout({required this.duration, this.enabled = true})
    : assert(duration > Duration.zero, 'Operation timeout duration must be greater than zero.');

  /// Creates a disabled timeout definition.
  const OperationTimeout.disabled() : duration = Duration.zero, enabled = false;

  /// Timeout duration.
  ///
  /// This is the maximum amount of time an operation may remain active.
  final Duration duration;

  /// Whether timeout checking is enabled.
  final bool enabled;

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// Whether this timeout is disabled.
  bool get isDisabled => !enabled;

  /// Whether this timeout is enabled and has a valid duration.
  bool get isActive => enabled && duration > Duration.zero;

  /// Timeout duration in milliseconds.
  int get milliseconds => duration.inMilliseconds;

  /// Timeout duration in microseconds.
  int get microseconds => duration.inMicroseconds;

  // ---------------------------------------------------------------------------
  // Duration helpers
  // ---------------------------------------------------------------------------

  /// Returns the deadline after [startedAt].
  ///
  /// Returns `null` when timeout checking is disabled.
  DateTime? deadlineFrom(DateTime startedAt) {
    if (!isActive) {
      return null;
    }

    return startedAt.add(duration);
  }

  /// Returns the deadline for [operation].
  ///
  /// Returns `null` when:
  ///
  /// - timeout is disabled;
  /// - the operation has not started.
  DateTime? deadlineFor(Operation operation) {
    final startedAt = operation.startedAt;

    if (!isActive || startedAt == null) {
      return null;
    }

    return deadlineFrom(startedAt);
  }

  /// Returns the elapsed duration since [startedAt].
  Duration elapsedSince(DateTime startedAt, {DateTime? now}) {
    final current = now ?? clock.now();

    final elapsed = current.difference(startedAt);

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return elapsed;
  }

  /// Returns the remaining duration until the timeout expires.
  ///
  /// Returns [Duration.zero] when the timeout has already expired.
  ///
  /// Returns `null` when timeout checking is disabled.
  Duration? remainingFrom(DateTime startedAt, {DateTime? now}) {
    if (!isActive) {
      return null;
    }

    final elapsed = elapsedSince(startedAt, now: now);

    if (elapsed >= duration) {
      return Duration.zero;
    }

    return duration - elapsed;
  }

  /// Returns the remaining duration for [operation].
  ///
  /// Returns `null` when:
  ///
  /// - timeout is disabled;
  /// - the operation has not started.
  Duration? remainingFor(Operation operation, {DateTime? now}) {
    final startedAt = operation.startedAt;

    if (!isActive || startedAt == null) {
      return null;
    }

    return remainingFrom(startedAt, now: now);
  }

  // ---------------------------------------------------------------------------
  // Expiration
  // ---------------------------------------------------------------------------

  /// Returns whether the timeout has expired since [startedAt].
  ///
  /// A timeout is considered expired when elapsed time is greater than or
  /// equal to the configured duration.
  bool isExpiredFrom(DateTime startedAt, {DateTime? now}) {
    if (!isActive) {
      return false;
    }

    return elapsedSince(startedAt, now: now) >= duration;
  }

  /// Returns whether [operation] has exceeded its timeout.
  ///
  /// Terminal operations are never considered timed out because they have
  /// already reached a terminal lifecycle state.
  bool isExpired(Operation operation, {DateTime? now}) {
    if (!isActive || operation.isTerminal) {
      return false;
    }

    final startedAt = operation.startedAt;

    if (startedAt == null) {
      return false;
    }

    return isExpiredFrom(startedAt, now: now);
  }

  /// Returns whether [operation] is still within its timeout.
  bool isWithinTimeout(Operation operation, {DateTime? now}) {
    if (!isActive || operation.isTerminal) {
      return true;
    }

    final startedAt = operation.startedAt;

    if (startedAt == null) {
      return true;
    }

    return !isExpiredFrom(startedAt, now: now);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Throws [StateError] when [operation] has exceeded its timeout.
  void validate(Operation operation, {DateTime? now}) {
    if (isExpired(operation, now: now)) {
      throw StateError(
        'Operation "${operation.id}" exceeded its timeout '
        'of ${duration.inMilliseconds}ms.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Copy helpers
  // ---------------------------------------------------------------------------

  /// Returns a copy with a different timeout duration.
  OperationTimeout copyWith({Duration? duration, bool? enabled}) {
    final nextDuration = duration ?? this.duration;
    final nextEnabled = enabled ?? this.enabled;

    if (!nextEnabled) {
      return const OperationTimeout.disabled();
    }

    if (nextDuration <= Duration.zero) {
      throw ArgumentError.value(nextDuration, 'duration', 'Operation timeout duration must be greater than zero.');
    }

    return OperationTimeout(duration: nextDuration, enabled: nextEnabled);
  }

  /// Returns a disabled timeout.
  OperationTimeout disable() {
    return const OperationTimeout.disabled();
  }

  /// Returns an enabled timeout with [duration].
  OperationTimeout enable(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Operation timeout duration must be greater than zero.');
    }

    return OperationTimeout(duration: duration, enabled: true);
  }

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => <Object?>[duration, enabled];

  @override
  String toString() {
    return 'OperationTimeout('
        'duration: $duration, '
        'enabled: $enabled'
        ')';
  }
}
