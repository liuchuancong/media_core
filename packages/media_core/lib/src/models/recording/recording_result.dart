import 'package:built_value/built_value.dart';

part 'recording_result.g.dart';

/// Represents the result of a recording lifecycle.
///
/// A [RecordingResult] contains the information produced when a recording
/// session finishes. It is independent of the concrete recording backend.
///
/// Responsibilities:
///
/// - identify whether the recording completed successfully
/// - describe the generated output
/// - record the final recording duration
/// - record the number of bytes written
/// - expose a recording error when applicable
///
/// It does not:
///
/// - perform the recording
/// - finalize backend resources
/// - create output files
/// - decide how recording failures are recovered
///
/// Those responsibilities belong to:
///
/// - RecordingSession
/// - RecordingBackend
/// - RecordingManager
abstract class RecordingResult implements Built<RecordingResult, RecordingResultBuilder> {
  /// Builds RecordingResult from a [updates] callback — the codegen entry.
  factory RecordingResult([void Function(RecordingResultBuilder)? updates]) = _$RecordingResult;

  /// Creates a recording result.
  factory RecordingResult.of({
    required bool success,
    String? outputPath,
    Duration duration = Duration.zero,
    int bytesWritten = 0,
    Object? error,
  }) {
    return RecordingResult(
      (builder) => builder
        ..success = success
        ..outputPath = outputPath
        ..duration = duration
        ..bytesWritten = bytesWritten
        ..error = error,
    );
  }

  /// Creates a successful recording result.
  factory RecordingResult.success({required String outputPath, Duration duration = Duration.zero, int bytesWritten = 0}) {
    return RecordingResult.of(success: true, outputPath: outputPath, duration: duration, bytesWritten: bytesWritten);
  }

  /// Creates a failed recording result.
  factory RecordingResult.failure({
    required Object error,
    String? outputPath,
    Duration duration = Duration.zero,
    int bytesWritten = 0,
  }) {
    return RecordingResult.of(
      success: false,
      outputPath: outputPath,
      duration: duration,
      bytesWritten: bytesWritten,
      error: error,
    );
  }

  RecordingResult._();

  /// A stopped recording has written nothing and lasted nothing until the
  /// backend says otherwise.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(RecordingResultBuilder builder) => builder
    ..duration = Duration.zero
    ..bytesWritten = 0;

  /// Whether the recording completed successfully.
  bool get success;

  /// Path of the generated recording output.
  String? get outputPath;

  /// Final duration of the recording.
  Duration get duration;

  /// Number of bytes written to the output.
  int get bytesWritten;

  /// Error associated with an unsuccessful recording.
  Object? get error;

  /// Whether an output path is available.
  bool get hasOutput {
    return outputPath != null && outputPath!.isNotEmpty;
  }

  /// Whether this result contains an error.
  bool get hasError {
    return error != null;
  }
}
