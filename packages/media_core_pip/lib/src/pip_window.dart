import 'package:flutter/painting.dart' show Offset, Rect, Size;

/// Desktop window state captured before entering picture-in-picture.
///
/// Every field is something the feature changes, so every field has to be
/// restored: leaving a user's window resizable-but-always-on-top because the
/// feature only remembered the size is worse than not remembering anything.
final class PipWindowSnapshot {
  const PipWindowSnapshot({
    required this.bounds,
    required this.alwaysOnTop,
    required this.resizable,
    required this.skipTaskbar,
    required this.title,
  });

  final Rect bounds;
  final bool alwaysOnTop;
  final bool resizable;
  final bool skipTaskbar;
  final String title;

  @override
  String toString() => 'PipWindowSnapshot(${bounds.width}x${bounds.height} at ${bounds.topLeft})';
}

/// Desktop window operations the PiP feature needs.
///
/// This is the seam that lets the driver be tested without a live window: the
/// production implementation wraps `window_manager`'s static API, and tests
/// supply a fake. It is deliberately narrow — only the operations the small
/// window uses — so an implementation for another window toolkit has little to
/// satisfy.
abstract interface class PipWindow {
  /// Reads the current window state.
  Future<PipWindowSnapshot> capture();

  /// Applies the small-window state.
  ///
  /// [aspectRatio] locks the window to the video's shape when non-null.
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  });

  /// Restores a previously captured state.
  Future<void> restore(PipWindowSnapshot snapshot);
}
