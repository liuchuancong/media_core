import 'package:built_value/built_value.dart';
import 'package:media_core/src/error/error_classifier.dart';
import 'package:media_core/src/error/player_error_category.dart';
import 'package:media_core/src/error/player_error_code.dart';
import 'package:media_core/src/error/player_exception.dart';
import 'package:media_core/src/models/error/error_context.dart' show ErrorContext, ErrorContextBuilder;

part 'player_failure.g.dart';

/// Immutable concrete failure produced by the media player core.
///
/// [PlayerErrorCode] identifies the specific failure, while
/// [PlayerErrorCategory] identifies its broader failure domain.
///
/// [PlayerFailure] is a data/diagnostic object only.
///
/// It does not:
/// - decide whether an error should be retried;
/// - decide whether fallback should be used;
/// - decide whether recovery should be performed;
/// - execute recovery;
/// - format user-facing messages.
///
/// Those responsibilities belong to higher-level policy and recovery layers.
abstract class PlayerFailure implements Built<PlayerFailure, PlayerFailureBuilder> {
  /// Builds PlayerFailure from a [updates] callback — the codegen entry.
  factory PlayerFailure([void Function(PlayerFailureBuilder)? updates]) = _$PlayerFailure;

  /// Records [code] as the failure, with the optional diagnostics that were
  /// available where it happened.
  factory PlayerFailure.of({
    required PlayerErrorCode code,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
  }) {
    return PlayerFailure(
      (builder) => builder
        ..code = code
        ..message = message
        ..cause = cause
        ..stackTrace = stackTrace
        ..context = context?.toBuilder()
        ..category = category,
    );
  }

  /// Creates a failure from an error code.
  factory PlayerFailure.fromCode(
    PlayerErrorCode code, {
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: category,
    );
  }

  /// Creates an unknown player failure.
  factory PlayerFailure.unknown({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.unknown,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Creates an invalid argument failure.
  factory PlayerFailure.invalidArgument({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.invalidArgument,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.invalidArgument,
    );
  }

  /// Creates an unsupported operation or capability failure.
  factory PlayerFailure.unsupported({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.unsupported,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.unsupported,
    );
  }

  /// Creates an invalid state failure.
  factory PlayerFailure.invalidState({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.invalidState,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.state,
    );
  }

  /// Creates a cancellation failure.
  factory PlayerFailure.cancelled({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.cancelled,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.cancellation,
    );
  }

  /// Creates a timeout failure.
  factory PlayerFailure.timeout({String? message, Object? cause, StackTrace? stackTrace, ErrorContext? context}) {
    return PlayerFailure.of(
      code: PlayerErrorCode.timeout,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.timeout,
    );
  }

  /// Creates a network failure.
  factory PlayerFailure.network({
    PlayerErrorCode code = PlayerErrorCode.network,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.network,
    );
  }

  /// Creates a source failure.
  factory PlayerFailure.source({
    PlayerErrorCode code = PlayerErrorCode.sourceInvalid,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.source,
    );
  }

  /// Creates a backend failure.
  factory PlayerFailure.backend({
    PlayerErrorCode code = PlayerErrorCode.backendUnavailable,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.backend,
    );
  }

  /// Creates a playback failure.
  factory PlayerFailure.playback({
    PlayerErrorCode code = PlayerErrorCode.playbackFailed,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.playback,
    );
  }

  /// Creates a decoder failure.
  factory PlayerFailure.decoder({
    PlayerErrorCode code = PlayerErrorCode.decoderError,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.decoder,
    );
  }

  /// Creates a renderer failure.
  factory PlayerFailure.renderer({
    PlayerErrorCode code = PlayerErrorCode.rendererTextureFailed,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.renderer,
    );
  }

  /// Creates a lifecycle failure.
  factory PlayerFailure.lifecycle({
    PlayerErrorCode code = PlayerErrorCode.lifecycleTransitionFailed,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.lifecycle,
    );
  }

  /// Creates a recovery failure.
  factory PlayerFailure.recovery({
    PlayerErrorCode code = PlayerErrorCode.recoveryFailed,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.recovery,
    );
  }

  /// Creates a fallback failure.
  factory PlayerFailure.fallback({
    PlayerErrorCode code = PlayerErrorCode.fallbackSelectionFailed,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    ErrorContext? context,
  }) {
    return PlayerFailure.of(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      category: PlayerErrorCategory.fallback,
    );
  }

  /// Creates a failure from an arbitrary error object.
  ///
  /// If [error] is already a [PlayerFailure], it is returned directly.
  factory PlayerFailure.fromError(
    Object error, {
    PlayerErrorCode code = PlayerErrorCode.unknown,
    String? message,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
  }) {
    if (error is PlayerFailure) {
      return error;
    }

    return PlayerFailure.of(
      code: code,
      message: message,
      cause: error,
      stackTrace: stackTrace,
      context: context,
      category: category,
    );
  }

  /// Creates a failure from an arbitrary [error].
  ///
  /// This is equivalent to [PlayerFailure.fromError].
  factory PlayerFailure.from(
    Object error, {
    PlayerErrorCode code = PlayerErrorCode.unknown,
    String? message,
    StackTrace? stackTrace,
    ErrorContext? context,
    PlayerErrorCategory? category,
  }) {
    return PlayerFailure.fromError(
      error,
      code: code,
      message: message,
      stackTrace: stackTrace,
      context: context,
      category: category,
    );
  }

  PlayerFailure._();

  /// The specific machine-readable error code.
  PlayerErrorCode get code;

  /// Optional diagnostic or technical error message.
  String? get message;

  /// Original underlying error, when available.
  Object? get cause;

  /// Stack trace associated with the failure.
  StackTrace? get stackTrace;

  /// Optional structured runtime context.
  ErrorContext? get context;

  /// Explicit broad error category.
  ///
  /// When omitted, [effectiveCategory] resolves the category from
  /// [ErrorClassifier].
  PlayerErrorCategory? get category;

  /// Whether a non-empty message is available.
  bool get hasMessage {
    final value = message;
    return value != null && value.trim().isNotEmpty;
  }

  /// Whether an underlying cause is available.
  bool get hasCause => cause != null;

  /// Whether a stack trace is available.
  bool get hasStackTrace => stackTrace != null;

  /// Whether structured context is available.
  bool get hasContext {
    final value = context;
    return value != null && value.isNotEmpty;
  }

  /// Whether an explicit category is available.
  bool get hasCategory => category != null;

  /// Whether diagnostic information is available.
  bool get hasDiagnostics {
    return hasCause || hasStackTrace || hasContext;
  }

  /// Whether this failure is unknown.
  bool get isUnknown {
    return code == PlayerErrorCode.unknown;
  }

  /// Whether this failure represents an invalid argument.
  bool get isInvalidArgument {
    return code == PlayerErrorCode.invalidArgument || category == PlayerErrorCategory.invalidArgument;
  }

  /// Whether this failure represents an unsupported capability.
  bool get isUnsupported {
    return code == PlayerErrorCode.unsupported || category == PlayerErrorCategory.unsupported;
  }

  /// Whether this failure represents an invalid state.
  bool get isInvalidState {
    return code == PlayerErrorCode.invalidState ||
        code == PlayerErrorCode.playbackInvalidState ||
        category == PlayerErrorCategory.state;
  }

  /// Whether this failure represents cancellation.
  bool get isCancelled {
    return code.isCancellation || category == PlayerErrorCategory.cancellation;
  }

  /// Whether this failure represents a timeout.
  bool get isTimeout {
    return category == PlayerErrorCategory.timeout ||
        code == PlayerErrorCode.timeout ||
        code == PlayerErrorCode.networkTimeout;
  }

  /// Whether this failure is network-related.
  bool get isNetworkRelated {
    return code.isNetworkRelated ||
        category == PlayerErrorCategory.network ||
        category == PlayerErrorCategory.http ||
        category == PlayerErrorCategory.authentication ||
        category == PlayerErrorCategory.security;
  }

  /// Whether this failure is source-related.
  bool get isSourceRelated {
    return code.isSourceRelated || category == PlayerErrorCategory.source;
  }

  /// Whether this failure is backend-related.
  bool get isBackendRelated {
    return code.isBackendRelated || category == PlayerErrorCategory.adapter || category == PlayerErrorCategory.backend;
  }

  /// Whether this failure is potentially recoverable.
  ///
  /// This is only a property of the error itself.
  /// It does not mean recovery should actually be attempted.
  bool get isPotentiallyRecoverable {
    return code.isPotentiallyRecoverable;
  }

  /// Returns the effective category of this failure.
  ///
  /// An explicitly supplied [category] takes precedence.
  ///
  /// When no explicit category is supplied, [ErrorClassifier] is the single
  /// source of truth for classifying the error code.
  PlayerErrorCategory get effectiveCategory {
    return category ?? ErrorClassifier.classify(code);
  }

  /// Returns the stable value of the effective category.
  String get categoryValue => effectiveCategory.value;

  /// Returns whether the failure belongs to [category].
  bool hasCategoryValue(PlayerErrorCategory category) {
    return effectiveCategory == category;
  }

  /// Converts this failure into a runtime [PlayerException].
  ///
  /// [PlayerException] is the only exception type exposed by the error
  /// module. The structured failure remains the source of truth for
  /// diagnostics.
  PlayerException toException() {
    return PlayerException(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    );
  }
}
