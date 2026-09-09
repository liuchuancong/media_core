import 'backend_descriptor.dart';

/// Result of backend selection.
///
/// A [BackendSelectionResult] contains the selected
/// backend and selection diagnostics.
///
/// It is produced by:
///
/// - BackendSelector
///
/// It does not:
///
/// - create backend instances
/// - start playback
///
/// Those belong to:
///
/// - BackendFactory
/// - PlayerSession
final class BackendSelectionResult {
  /// Creates a selection result.
  const BackendSelectionResult({
    required this.success,

    this.backend,

    this.score = 0,

    this.reason,

    this.rejected = const [],
  });

  /// Whether selection succeeded.
  final bool success;

  /// Selected backend.
  ///
  /// Null when selection failed.
  final BackendDescriptor? backend;

  /// Selection score.
  ///
  /// Higher score means better match.
  final int score;

  /// Failure or diagnostic message.
  final String? reason;

  /// Backends rejected during selection.
  ///
  /// Used for diagnostics.
  final List<BackendSelectionReject> rejected;

  /// Whether backend exists.
  bool get hasBackend {
    return backend != null;
  }

  /// Selected backend id.
  String? get backendId {
    return backend?.id;
  }

  /// Creates success result.
  factory BackendSelectionResult.success({required BackendDescriptor backend, required int score}) {
    return BackendSelectionResult(success: true, backend: backend, score: score);
  }

  /// Creates failed result.
  factory BackendSelectionResult.failure({required String reason, List<BackendSelectionReject> rejected = const []}) {
    return BackendSelectionResult(success: false, reason: reason, rejected: rejected);
  }

  @override
  String toString() {
    return 'BackendSelectionResult('
        'success=$success, '
        'backend=$backendId, '
        'score=$score'
        ')';
  }
}

/// Describes why a backend was rejected.
final class BackendSelectionReject {
  /// Creates a rejection record.
  const BackendSelectionReject({required this.backend, required this.reason});

  /// Rejected backend.
  final BackendDescriptor backend;

  /// Reject reason.
  ///
  /// Examples:
  ///
  /// - unsupported platform
  /// - missing capability
  /// - disabled
  final String reason;

  @override
  String toString() {
    return '${backend.id}: $reason';
  }
}
