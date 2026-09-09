import 'reconcile_plan.dart';
import 'reconcile_action.dart';
import 'reconcile_result.dart';
import 'reconcile_context.dart';
import '../core/player_state.dart';
import '../core/player_status.dart';

/// Reconciles desired player state
/// with current player state.
final class PlayerReconciler {
  const PlayerReconciler();

  ReconcilePlan reconcile({required PlayerState current, required PlayerState desired, ReconcileContext? context}) {
    final actions = <ReconcileAction>[];

    if (current == desired) {
      return ReconcilePlan.empty();
    }

    final currentStatus = _resolveStatus(current);

    final desiredStatus = _resolveStatus(desired);

    if (currentStatus != desiredStatus) {
      actions.add(ReconcileAction.changeState(from: currentStatus, to: desiredStatus));
    }

    return ReconcilePlan(actions: actions);
  }

  bool needsReconcile({required PlayerState current, required PlayerState desired}) {
    return current != desired;
  }

  ReconcileResult evaluate(ReconcilePlan plan) {
    if (plan.isEmpty) {
      return ReconcileResult.noop();
    }

    return ReconcileResult.pending(plan);
  }

  PlayerStatus _resolveStatus(PlayerState state) {
    if (state.disposed) {
      return PlayerStatus.disposed;
    }

    if (state.disposing) {
      return PlayerStatus.disposing;
    }

    if (state.hasError) {
      return PlayerStatus.error;
    }

    if (state.fallingBack) {
      return PlayerStatus.buffering;
    }

    if (state.recovering) {
      return PlayerStatus.buffering;
    }

    if (state.opening) {
      return PlayerStatus.opening;
    }

    if (state.seeking) {
      return PlayerStatus.seeking;
    }

    if (state.buffering) {
      return PlayerStatus.buffering;
    }

    if (state.playing) {
      return PlayerStatus.playing;
    }

    if (state.paused) {
      return PlayerStatus.paused;
    }

    if (state.completed) {
      return PlayerStatus.completed;
    }

    if (state.stopped) {
      return PlayerStatus.stopped;
    }

    if (state.ready) {
      return PlayerStatus.ready;
    }

    if (state.initialized) {
      return PlayerStatus.initializing;
    }

    return PlayerStatus.idle;
  }
}
