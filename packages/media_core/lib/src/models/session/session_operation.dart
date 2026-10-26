import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/operation_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/models/session/session_operation_state.dart';
import 'package:media_core/src/models/session/session_operation_type.dart';

part 'session_operation.g.dart';

/// Represents an operation executed on a player session.
///
/// A [SessionOperation] describes one action performed
/// during a session lifecycle.
///
/// It does not:
///
/// - execute the operation
/// - manage async execution
/// - retry failures
///
/// Those belong to:
///
/// - SessionController
/// - OperationTracker
abstract class SessionOperation implements Built<SessionOperation, SessionOperationBuilder> {
  /// Builds an operation from a [updates] callback — the codegen entry.
  factory SessionOperation([void Function(SessionOperationBuilder)? updates]) = _$SessionOperation;

  /// Creates a session operation.
  factory SessionOperation.of({
    required OperationId id,
    required SessionId sessionId,
    required SessionOperationType type,
    SessionOperationState state = SessionOperationState.pending,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return SessionOperation(
      (builder) => builder
        ..id = id
        ..sessionId = sessionId
        ..type = type
        ..state = state
        ..error = error
        ..startedAt = startedAt
        ..completedAt = completedAt,
    );
  }

  SessionOperation._();

  /// Every operation starts pending, with no error and no clock stamps.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SessionOperationBuilder builder) => builder..state = SessionOperationState.pending;

  /// Operation identity.
  OperationId get id;

  /// Related session identity.
  SessionId get sessionId;

  /// Operation type.
  SessionOperationType get type;

  /// Current operation state.
  SessionOperationState get state;

  /// Error message.
  String? get error;

  /// Start time.
  DateTime? get startedAt;

  /// Completion time.
  DateTime? get completedAt;

  /// Whether operation is running.
  bool get running {
    return state == SessionOperationState.running;
  }

  /// Whether operation completed successfully.
  bool get completed {
    return state == SessionOperationState.completed;
  }

  /// Whether operation failed.
  bool get failed {
    return state == SessionOperationState.failed;
  }
}
