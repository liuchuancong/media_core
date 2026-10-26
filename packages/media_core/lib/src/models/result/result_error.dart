import 'package:built_value/built_value.dart';
import 'package:media_core/src/error/error_context.dart' show ErrorContext;
import 'package:media_core/src/error/player_error_category.dart' show PlayerErrorCategory;
import 'package:media_core/src/error/player_error_code.dart' show PlayerErrorCode;
import 'package:media_core/src/models/error/library.dart' show PlayerFailure, PlayerFailureBuilder;

part 'result_error.g.dart';

/// Represents an error contained by a `Result`.
///
/// [ResultError] is the error value used by the result layer.
///
/// It can retain the original [PlayerFailure] so callers do not lose
/// diagnostic information when converting a player failure into a result.
///
/// Classification and recovery policy remain the responsibility of the
/// error layer. [ResultError] only carries the error information required
/// by the result layer.
///
/// A [ResultError] is immutable and value-based.
abstract class ResultError implements Built<ResultError, ResultErrorBuilder> {
  /// Builds ResultError from a [updates] callback — the codegen entry.
  factory ResultError([void Function(ResultErrorBuilder)? updates]) = _$ResultError;

  /// Creates a [ResultError].
  factory ResultError.of({
    required PlayerErrorCode code,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
    PlayerFailure? failure,
  }) {
    return ResultError(
      (builder) => builder
        ..code = code
        ..message = message
        ..cause = cause
        ..stackTrace = stackTrace
        ..context = context
        ..category = category
        ..failure = failure?.toBuilder(),
    );
  }

  /// Creates a [ResultError] from a [PlayerFailure].
  ///
  /// The original failure is retained in [failure] so that no diagnostic
  /// information is lost.
  factory ResultError.fromFailure(PlayerFailure failure) {
    return ResultError.of(
      code: failure.code,
      message: failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
      context: failure.context,
      category: failure.category,
      failure: failure,
    );
  }

  /// Creates a [ResultError] from an arbitrary error.
  ///
  /// When [error] is already a [PlayerFailure], it is preserved directly
  /// through [ResultError.fromFailure].
  factory ResultError.fromError(
    Object error, {
    PlayerErrorCode code = PlayerErrorCode.unknown,
    String? message,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
  }) {
    if (error is PlayerFailure) {
      return ResultError.fromFailure(error);
    }

    return ResultError.of(
      code: code,
      message: message,
      cause: error,
      stackTrace: stackTrace,
      context: context,
      category: category,
    );
  }

  ResultError._();

  /// Machine-readable player error code.
  PlayerErrorCode get code;

  /// Optional human-readable error message.
  String? get message;

  /// Original underlying error.
  Object? get cause;

  /// Stack trace associated with the error.
  StackTrace? get stackTrace;

  /// Diagnostic context associated with the error.
  ErrorContext? get context;

  /// Error category.
  PlayerErrorCategory? get category;

  /// Original [PlayerFailure], when this error was created from one.
  PlayerFailure? get failure;

  /// Returns `true` when a non-empty message is available.
  bool get hasMessage {
    final value = message;
    return value != null && value.trim().isNotEmpty;
  }

  /// Returns `true` when an underlying cause is available.
  bool get hasCause => cause != null;

  /// Returns `true` when a stack trace is available.
  bool get hasStackTrace => stackTrace != null;

  /// Returns `true` when diagnostic context is available.
  bool get hasContext {
    final value = context;
    return value != null && value.isNotEmpty;
  }

  /// Returns `true` when an error category is available.
  bool get hasCategory => category != null;

  /// Returns `true` when the original [PlayerFailure] is available.
  bool get hasFailure => failure != null;

  /// Returns `true` when this error contains diagnostic information.
  ///
  /// Diagnostic information consists of an underlying cause, stack trace,
  /// or diagnostic context.
  bool get hasDiagnostics {
    return hasCause || hasStackTrace || hasContext;
  }

  /// Converts this result error back into a [PlayerFailure].
  ///
  /// When the original failure is available, it is returned directly.
  ///
  /// Otherwise a new [PlayerFailure] is created from the stored information.
  PlayerFailure toFailure() {
    final originalFailure = failure;

    if (originalFailure != null) {
      return originalFailure;
    }

    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: category,
    );
  }
}
