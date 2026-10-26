import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/operation/operation.dart';
import 'package:media_core/src/operation/operation_state.dart' show OperationState;

part 'operation_timeout.g.dart';

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
/// final timeout = OperationTimeout.of(
///   duration: Duration(seconds: 15),
/// );
///
/// if (timeout.isExpired(operation)) {
///   // Handle timeout.
/// }
/// ```
abstract class OperationTimeout implements Built<OperationTimeout, OperationTimeoutBuilder> {
  /// Builds OperationTimeout from a [updates] callback — the codegen entry.
  factory OperationTimeout([void Function(OperationTimeoutBuilder)? updates]) = _$OperationTimeout;

  /// Creates an operation timeout definition.
  ///
  /// [duration] must be positive.
  factory OperationTimeout.of({required Duration duration, bool enabled = true}) {
    return OperationTimeout(
      (builder) => builder
        ..duration = duration
        ..enabled = enabled,
    );
  }

  /// Creates a disabled timeout definition.
  factory OperationTimeout.disabled() {
    return OperationTimeout((builder) => builder
      ..duration = Duration.zero
      ..enabled = false);
  }

  OperationTimeout._();

  /// Checking is on unless the caller turns it off.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(OperationTimeoutBuilder builder) => builder..enabled = true;

  /// A timeout that is actually checked must have something to check against;
  /// a disabled one carries no duration to be meaningful, which is the shape
  /// [OperationTimeout.disabled] and the old `!enabled` branch produced.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(OperationTimeoutBuilder builder) {
    final duration = builder.duration;
    final enabled = builder.enabled;
    if (enabled == true && duration != null) {
      assert(duration > Duration.zero, 'Operation timeout duration must be greater than zero.');
    }
  }

  /// Timeout duration.
  ///
  /// This is the maximum amount of time an operation may remain active.
  Duration get duration;

  /// Whether timeout checking is enabled.
  bool get enabled;

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
}
