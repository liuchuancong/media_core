/// Where a cast session's connection stands (§20.1).
enum DlnaConnectionState {
  /// Created, never connected.
  disconnected,

  /// The session's connect call is running.
  connecting,

  /// The device's services are validated and commands may flow.
  connected,

  /// The device went quiet and recovery is being attempted.
  reconnecting,

  /// The session's disconnect call is running.
  disconnecting,

  /// Connect failed; the session is not usable until reconnected.
  failed,
}
