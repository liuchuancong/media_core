/// What the host's small window should present.
///
/// Deliberately narrow: the small window is a Flutter surface the host owns
/// (`flutter_floating`, an in-app overlay, a platform view — the choice is the
/// host's), and the driver only needs to say *which* player it belongs to and
/// how the video is shaped. Passing a widget, a route or a controller through
/// here would make the module depend on the host's UI.
final class FloatingWindowRequest {
  const FloatingWindowRequest({
    required this.playerId,
    this.title,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.closeOnVideoEnd = true,
  });

  /// Player the window should present.
  ///
  /// A string rather than the kernel's typed id so a host can key its own
  /// navigation or service state without importing the kernel.
  final String playerId;

  /// Optional label for the window (window title, notification text).
  final String? title;

  /// Latest known video size; `0` when unknown.
  final int videoWidth;
  final int videoHeight;

  /// Whether the window should close itself when playback ends.
  ///
  /// A hint for the host's policy, not something the driver enforces: only the
  /// host can observe the end of playback for its own surface.
  final bool closeOnVideoEnd;

  @override
  String toString() => 'FloatingWindowRequest($playerId${title == null ? '' : ', $title'})';
}

/// Host-owned small window surface.
///
/// Responsibilities:
///
/// - show and hide the small window
/// - report whether this device can host one at all
///
/// It does not:
///
/// - decide when a small window is appropriate
/// - track presentation mode
/// - own the player
///
/// Those belong to:
///
/// - MobilePresentationDriver
/// - the application
///
/// Implementations must be idempotent: showing an already visible window and
/// hiding a hidden one are both no-ops, because the driver's sequencing can
/// legitimately repeat a state after a failed transition.
abstract interface class FloatingWindowPresenter {
  /// Whether this device can present a small window.
  ///
  /// False on platforms without an overlay capability and when the host has
  /// not wired one; the driver turns that into an explicit refusal instead of
  /// a silent no-op.
  bool get isSupported;

  /// Shows the small window for [request].
  Future<void> show(FloatingWindowRequest request);

  /// Hides the small window. Safe to call when nothing is shown.
  Future<void> hide();
}

/// Presenter for hosts that have no small window.
///
/// The default, so a driver can be constructed before the host wires its
/// surface: a floating request then fails loudly rather than doing nothing.
final class NullFloatingWindowPresenter implements FloatingWindowPresenter {
  const NullFloatingWindowPresenter();

  @override
  bool get isSupported => false;

  @override
  Future<void> show(FloatingWindowRequest request) {
    throw UnsupportedError('No floating window presenter is installed.');
  }

  @override
  Future<void> hide() async {}
}
