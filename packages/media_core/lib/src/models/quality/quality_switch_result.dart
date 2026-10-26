/// Result of one quality switch.
enum QualitySwitchResult {
  /// The new source is open and the playhead landed back on it.
  applied,

  /// Nothing changed: the requested candidate is already the open
  /// one. Reported rather than silently returning success, because a
  /// host that logged "switched to 1080p" when no switch happened
  /// would be writing fiction into its own analytics.
  alreadyCurrent,

  /// The switch failed mid-flight.
  ///
  /// The outcome's `restored` flag says whether the handle was
  /// rolled back to the previous source; when rollback itself
  /// failed, the handle is on whatever the last open left it on, and
  /// only the host's error surface can decide what to show.
  failed,
}
