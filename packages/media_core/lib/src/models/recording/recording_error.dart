import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/recording/recording_error_code.dart' show RecordingErrorCode;

part 'recording_error.g.dart';

/// Describes an error produced during a recording lifecycle.
///
/// A [RecordingError] provides a backend-independent representation of a
/// recording failure so higher-level components do not need to depend on
/// platform-specific exception types.
///
/// Responsibilities:
///
/// - identify the recording failure category
/// - describe the failure
/// - optionally retain the original cause
/// - optionally retain the original stack trace
/// - provide stable error information to higher layers
///
/// It does not:
///
/// - recover from recording failures
/// - retry recording operations
/// - decide whether a recording should be stopped
/// - implement backend-specific error handling
///
/// Those responsibilities belong to:
///
/// - RecordingSession
/// - RecordingManager
/// - RecordingBackend
abstract class RecordingError implements Built<RecordingError, RecordingErrorBuilder> {
  /// Builds RecordingError from a [updates] callback — the codegen entry.
  factory RecordingError([void Function(RecordingErrorBuilder)? updates]) = _$RecordingError;

  /// Creates a recording error.
  factory RecordingError.of({
    required RecordingErrorCode code,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return RecordingError(
      (builder) => builder
        ..code = code
        ..message = message
        ..cause = cause
        ..stackTrace = stackTrace,
    );
  }

  /// Creates an error indicating that the recording configuration is invalid.
  factory RecordingError.invalidConfiguration({required String message, Object? cause, StackTrace? stackTrace}) {
    return RecordingError.of(
      code: RecordingErrorCode.invalidConfiguration,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an error indicating that recording is already active.
  factory RecordingError.alreadyRecording({String message = 'A recording is already active.'}) {
    return RecordingError.of(code: RecordingErrorCode.alreadyRecording, message: message);
  }

  /// Creates an error indicating that no recording is active.
  factory RecordingError.notRecording({String message = 'No recording is active.'}) {
    return RecordingError.of(code: RecordingErrorCode.notRecording, message: message);
  }

  /// Creates an error indicating that the requested backend is unavailable.
  factory RecordingError.backendUnavailable({required String message, Object? cause, StackTrace? stackTrace}) {
    return RecordingError.of(
      code: RecordingErrorCode.backendUnavailable,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an error indicating that the recording source is unavailable.
  factory RecordingError.sourceUnavailable({required String message, Object? cause, StackTrace? stackTrace}) {
    return RecordingError.of(
      code: RecordingErrorCode.sourceUnavailable,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an error indicating that the output cannot be created.
  factory RecordingError.outputUnavailable({required String message, Object? cause, StackTrace? stackTrace}) {
    return RecordingError.of(
      code: RecordingErrorCode.outputUnavailable,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an error indicating that recording has failed.
  factory RecordingError.failed({required String message, Object? cause, StackTrace? stackTrace}) {
    return RecordingError.of(code: RecordingErrorCode.failed, message: message, cause: cause, stackTrace: stackTrace);
  }

  /// Creates an error indicating that recording was cancelled.
  factory RecordingError.cancelled({String message = 'Recording was cancelled.'}) {
    return RecordingError.of(code: RecordingErrorCode.cancelled, message: message);
  }

  RecordingError._();

  /// Stable recording error code.
  RecordingErrorCode get code;

  /// Human-readable description of the failure.
  String get message;

  /// Original exception or error that caused the failure.
  Object? get cause;

  /// Stack trace associated with [cause].
  StackTrace? get stackTrace;

  /// Whether an underlying cause is available.
  bool get hasCause {
    return cause != null;
  }

  /// Whether a stack trace is available.
  bool get hasStackTrace {
    return stackTrace != null;
  }
}
