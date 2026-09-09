import '../identity/player_id.dart';
import '../identity/session_id.dart';

/// Context information used during reconciliation.
final class ReconcileContext {
  const ReconcileContext({this.playerId, this.sessionId, this.reason});

  /// Related player.
  final PlayerId? playerId;

  /// Related session.
  final SessionId? sessionId;

  /// Reason of reconciliation.
  final String? reason;

  ReconcileContext copyWith({PlayerId? playerId, SessionId? sessionId, String? reason}) {
    return ReconcileContext(
      playerId: playerId ?? this.playerId,
      sessionId: sessionId ?? this.sessionId,
      reason: reason ?? this.reason,
    );
  }
}
