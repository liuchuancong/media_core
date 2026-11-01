/// Where a discovery run is in its lifecycle.
enum DlnaDiscoveryState {
  /// Created, never started.
  idle,

  /// `start` is running (binding the socket, sending the first search).
  starting,

  /// Listening and searching.
  active,

  /// `stop` is running.
  stopping,

  /// Stopped; every resource released.
  stopped,

  /// Start failed (e.g. the socket could not be bound at all).
  error,
}
