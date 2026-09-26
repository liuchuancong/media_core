import 'dart:async';

import 'package:media_core/media_core.dart';

import 'floating_config.dart';
import 'floating_window_presenter.dart';

/// Owns the in-app small-window mode.
///
/// Responsibilities:
///
/// - track whether the small window is up, and publish changes
/// - carry the player identity and video shape the surface needs
/// - delegate to a host presenter when the host renders its own surface
///
/// It does not:
///
/// - draw the window ([FloatingWindowOverlay] does, or the host's presenter)
/// - own the player (the host does; the driver only names it)
/// - touch operating-system windows — an in-app small window is a widget, so
///   it needs no window API and behaves the same on every platform
/// - own picture-in-picture or fullscreen (separate packages do)
///
/// ## Two ways to render the surface
///
/// The package ships [FloatingWindowOverlay]: the host puts it in its own
/// `Stack` and the geometry, drag and snapping are handled here. That is the
/// in-app case, and it is why this package has no platform branching at all —
/// there is nothing platform-specific about a widget above a page.
///
/// A host that wants the surface somewhere this package cannot reach — a
/// separate platform window, a system overlay — installs a
/// [FloatingWindowPresenter] instead. Both paths share the same state:
/// [isFloating] and [onFloatingChanged] mean the same thing either way.
final class FloatingDriver implements KernelPresentationDriver {
  /// Creates the driver.
  FloatingDriver({
    this.config = FloatingConfig.defaults,
    FloatingWindowPresenter presenter = const NullFloatingWindowPresenter(),
  }) : _presenter = presenter;

  /// Behaviour and geometry.
  final FloatingConfig config;

  FloatingWindowPresenter _presenter;

  final StreamController<bool> _floatingChanges = StreamController<bool>.broadcast();
  final StreamController<PlayerId> _players = StreamController<PlayerId>.broadcast();

  bool _initialized = false;
  bool _disposed = false;
  bool _isFloating = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  PlayerId? _playerId;

  /// Whether the driver has been initialized.
  bool get initialized => _initialized;

  /// Whether the small window is up.
  bool get isFloating => _isFloating;

  /// Small-window state changes.
  Stream<bool> get onFloatingChanged => _floatingChanges.stream;

  /// Player the small window should show.
  PlayerId? get playerId => _playerId;

  /// Video width fed through [onVideoSize], for the overlay's sizing.
  int get videoWidth => _videoWidth;

  /// Video height fed through [onVideoSize], for the overlay's sizing.
  int get videoHeight => _videoHeight;

  /// Whether this host can present a small window.
  ///
  /// Always true: the in-app window is a widget, so the only way to be unable
  /// to show it is to not put the overlay in the tree.
  bool get isAvailable => true;

  /// Replaces the host's surface.
  ///
  /// Exists for hosts that build their surface after the driver (a widget tree
  /// is not available at construction time) and for tests.
  void updatePresenter(FloatingWindowPresenter presenter) {
    _presenter = presenter;
  }

  /// Initializes the driver.
  ///
  /// Call once, early. Safe to call again.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
  }

  /// Feeds the latest video size, used to shape the small window.
  void onVideoSize(int width, int height) {
    _videoWidth = width;
    _videoHeight = height;
  }

  @override
  Future<void> apply(PlayerId playerId, PresentationRequest request) async {
    if (_disposed) {
      throw StateError('FloatingDriver has been disposed.');
    }

    switch (request.mode) {
      case PresentationMode.floating:
        await _show(playerId);
      case PresentationMode.normal:
        await _hide();
      case PresentationMode.fullscreen:
      case PresentationMode.windowFullscreen:
      case PresentationMode.pip:
        throw UnsupportedError(
          'FloatingDriver serves the in-app small window only; mode "${request.mode.name}" '
          'belongs to another driver (see PresentationDriverChain).',
        );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    if (_isFloating) {
      await _presenter.hide();
      _isFloating = false;
    }

    await DisposeUtils.close(_floatingChanges);
    await DisposeUtils.close(_players);
  }

  /// Player changes, for a host that binds its surface asynchronously.
  Stream<PlayerId> get onPlayerChanged => _players.stream;

  // ---------------------------------------------------------------------------
  // Show and hide
  // ---------------------------------------------------------------------------

  Future<void> _show(PlayerId playerId) async {
    if (_isFloating && _playerId == playerId) {
      return;
    }

    _playerId = playerId;
    if (!_players.isClosed) {
      _players.add(playerId);
    }

    final presenter = _presenter;
    if (presenter.isSupported) {
      await presenter.show(
        FloatingWindowRequest(
          playerId: playerId.value,
          videoWidth: _videoWidth,
          videoHeight: _videoHeight,
        ),
      );
    }

    _setFloating(true);
  }

  Future<void> _hide() async {
    if (!_isFloating) {
      return;
    }

    final presenter = _presenter;
    if (presenter.isSupported) {
      await presenter.hide();
    }

    _setFloating(false);
  }

  void _setFloating(bool value) {
    if (value == _isFloating) {
      return;
    }
    _isFloating = value;
    if (!_floatingChanges.isClosed) {
      _floatingChanges.add(value);
    }
  }
}
