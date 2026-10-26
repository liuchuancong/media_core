import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/reconciler/reconcile_action.dart';

part 'reconcile_plan.g.dart';

/// Describes a set of actions required
/// to reach desired state.
abstract class ReconcilePlan implements Built<ReconcilePlan, ReconcilePlanBuilder> {
  /// Builds a plan from a [updates] callback — the codegen entry.
  factory ReconcilePlan([void Function(ReconcilePlanBuilder)? updates]) = _$ReconcilePlan;

  /// Creates a plan from the given [actions].
  factory ReconcilePlan.of({required List<ReconcileAction> actions}) {
    return ReconcilePlan(
      (builder) => builder..actions = actions,
    );
  }

  ReconcilePlan._();

  /// Creates a plan that requires no actions.
  factory ReconcilePlan.empty() {
    return ReconcilePlan.of(actions: const <ReconcileAction>[]);
  }

  /// An unplanned reconciliation is an empty list, not a null one.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ReconcilePlanBuilder builder) => builder..actions = const <ReconcileAction>[];

  /// The ordered actions needed to reach the desired state.
  List<ReconcileAction> get actions;

  /// Whether the plan requires no actions.
  bool get isEmpty {
    return actions.isEmpty;
  }

  /// Whether the plan requires at least one action.
  bool get isNotEmpty {
    return actions.isNotEmpty;
  }

  /// The number of actions in the plan.
  int get length {
    return actions.length;
  }

  /// Returns the action at [index].
  ReconcileAction operator [](int index) {
    return actions[index];
  }
}
