/// The platform muxer failed.
///
/// A distinct type so a caller can tell "this device could not merge
/// the pair" (fall back to another quality line, or tell the user)
/// apart from the argument-level [UnsupportedError] that will never
/// change its answer for the same source.
final class RemuxFailedError extends Error {
  /// Creates a remux failure with a human-readable [message].
  RemuxFailedError(this.message);

  /// Why the merge failed, as reported by the platform.
  final String message;

  @override
  String toString() => 'RemuxFailedError: $message';
}
