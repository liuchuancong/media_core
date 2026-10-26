/// Lifecycle phase of one danmaku session.
enum DanmakuSessionPhase {
  /// No transport installed yet.
  idle,

  /// A handshake is in flight; the room is owned but not delivering.
  connecting,

  /// The transport is attached and delivering.
  connected,

  /// The transport lost the room and is repairing it.
  reconnecting,

  /// A previous session ended and nothing owns the room.
  closed,

  /// The last attempt failed; the room is not owned.
  failed,
}
