import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/reconciler/reconcile_plan.dart';
import 'package:media_core/src/models/reconciler/reconcile_result_type.dart';

part 'reconcile_result.g.dart';

/// The result of evaluating a [ReconcilePlan].
abstract class ReconcileResult implements Built<ReconcileResult, ReconcileResultBuilder> {
  /// Builds a result from a [updates] callback — the codegen entry.
  factory ReconcileResult([void Function(ReconcileResultBuilder)? updates]) = _$ReconcileResult;

  /// Creates a result from its outcome category and detail.
  factory ReconcileResult.of({required ReconcileResultType type, ReconcilePlan? plan, Object? error}) {
    return ReconcileResult(
      (builder) => builder
        ..type = type
        ..plan = plan?.toBuilder()
        ..error = error,
    );
  }

  ReconcileResult._();

  /// Creates a result for an empty plan that requires no action.
  factory ReconcileResult.noop() {
    return ReconcileResult.of(type: ReconcileResultType.noop);
  }

  /// Creates a result carrying the [plan] still to be executed.
  factory ReconcileResult.pending(ReconcilePlan plan) {
    return ReconcileResult.of(type: ReconcileResultType.pending, plan: plan);
  }

  /// Creates a result for a plan that completed successfully.
  factory ReconcileResult.completed() {
    return ReconcileResult.of(type: ReconcileResultType.completed);
  }

  /// Creates a result for a plan that failed with [error].
  factory ReconcileResult.failed(Object error) {
    return ReconcileResult.of(type: ReconcileResultType.failed, error: error);
  }

  /// The outcome category this result falls under.
  ReconcileResultType get type;

  /// The plan associated with the result, when one exists.
  ReconcilePlan? get plan;

  /// The error that caused the failure, when [type] is [ReconcileResultType.failed].
  Object? get error;

  /// Whether the reconciliation required no action.
  bool get isNoop => type == ReconcileResultType.noop;

  /// Whether the plan is still awaiting execution.
  bool get isPending => type == ReconcileResultType.pending;

  /// Whether the plan completed successfully.
  bool get isCompleted => type == ReconcileResultType.completed;

  /// Whether the plan failed.
  bool get isFailed => type == ReconcileResultType.failed;
}
