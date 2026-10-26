/// Lifecycle events.
enum LifecycleEventType {
  /// The player object was constructed.
  created,

  /// Its backend engine was initialized.
  initialized,

  /// Bound to a foreground surface and ready to play.
  activated,

  /// Playback was paused while the player stays active.
  paused,

  /// Paused playback was resumed.
  resumed,

  /// Released from the surface (for example, backgrounded); playback stops.
  inactive,

  /// Detached from its resources ahead of disposal.
  detached,

  /// Disposal has begun; the player is winding down.
  disposing,

  /// Fully disposed; no further transitions are recorded.
  disposed,
}
