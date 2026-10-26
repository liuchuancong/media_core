import 'package:built_value/built_value.dart';
import 'package:media_core/src/core/state/player_status.dart';
import 'package:media_core/src/models/reconciler/reconcile_action_type.dart';

part 'reconcile_action.g.dart';

/// Represents an action required during reconciliation.
///
/// ReconcileAction does not execute anything.
/// It only describes what should happen.
///
/// Execution belongs to:
///
/// - Coordinator
/// - Controller
/// - SessionManager
abstract class ReconcileAction implements Built<ReconcileAction, ReconcileActionBuilder> {
  /// Builds an action from a [updates] callback — the codegen entry.
  factory ReconcileAction([void Function(ReconcileActionBuilder)? updates]) = _$ReconcileAction;

  /// Creates a reconciliation action from its type and the statuses it moves.
  factory ReconcileAction.of({
    required ReconcileActionType type,
    PlayerStatus? from,
    PlayerStatus? to,
  }) {
    return ReconcileAction(
      (builder) => builder
        ..type = type
        ..from = from
        ..to = to,
    );
  }

  ReconcileAction._();

  /// Changes player lifecycle state.
  factory ReconcileAction.changeState({required PlayerStatus from, required PlayerStatus to}) {
    return ReconcileAction.of(type: ReconcileActionType.changeState, from: from, to: to);
  }

  /// Action type.
  ReconcileActionType get type;

  /// Previous status.
  PlayerStatus? get from;

  /// Target status.
  PlayerStatus? get to;

  /// Whether this action changes state.
  bool get isStateChange {
    return type == ReconcileActionType.changeState;
  }
}
