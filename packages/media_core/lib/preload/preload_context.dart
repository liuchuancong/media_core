import '../identity/player_id.dart';
import '../identity/session_id.dart';

/// Context for preload execution.
final class PreloadContext {
  const PreloadContext({this.playerId, this.sessionId});

  final PlayerId? playerId;

  final SessionId? sessionId;
}
