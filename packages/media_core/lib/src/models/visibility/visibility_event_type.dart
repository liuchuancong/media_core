/// Visibility event types.
enum VisibilityEventType {
  /// The player just became visible.
  appeared,

  /// The player just stopped being visible.
  disappeared,

  /// The player is visible.
  visible,

  /// The player is hidden.
  hidden,

  /// A visibility input changed without an appearance transition.
  changed,
}
