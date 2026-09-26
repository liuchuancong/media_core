/// How a queue advances.
///
/// The four modes are lx-music's, and their exact semantics matter:
///
/// - [list] — play through once and stop at the end. Reaching the end is a
///   terminal state, not a wrap-around.
/// - [listLoop] — wrap to the first track after the last.
/// - [singleLoop] — repeat the current track forever; `next()` (a user
///   request) still moves on, which is why the mode is consulted with an
///   "automatic" flag rather than unconditionally.
/// - [random] — walk a shuffled permutation of the queue; because the order is
///   materialized, `previous()` can retrace what was actually played instead
///   of guessing.
enum PlayMode {
  /// Sequential, stop at the end.
  list,

  /// Sequential, wrap at the end.
  listLoop,

  /// Repeat the current track.
  singleLoop,

  /// Shuffled order.
  random,
}

/// Behaviour of [PlayMode] values.
extension PlayModeX on PlayMode {
  /// Whether an automatic advance (track finished) should replay the current
  /// track instead of moving on.
  bool get repeatsCurrent => this == PlayMode.singleLoop;

  /// Whether the queue wraps around at its end.
  bool get wraps => this == PlayMode.listLoop || this == PlayMode.random;

  /// Whether advancing follows a shuffled order.
  bool get shuffled => this == PlayMode.random;

  /// Parses a persisted mode name, falling back to [PlayMode.list].
  static PlayMode fromName(String? name) {
    for (final mode in PlayMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }

    return PlayMode.list;
  }
}
