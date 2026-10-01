import 'dart:async';

import 'package:media_core/media_core.dart';

import 'package:media_core_floating/src/floating_config.dart';
import 'package:media_core_floating/src/floating_window_presenter.dart';

/// Decision trail for the in-app small window.
///
/// The interesting line here is which surface ended up carrying the video: the
/// package's own overlay, or a host presenter. A window that never appeared is
/// usually a presenter that reported itself unsupported.
final LogModule _log = MediaCoreLog.of(LogCategory.presentation);

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
    PresentationLifecycleHooks? lifecycleHooks,
  }) : _presenter = presenter,
       lifecycleHooks = lifecycleHooks ?? const PresentationLifecycleHooks();

  /// Behaviour and geometry.
  final FloatingConfig config;

  FloatingWindowPresenter _presenter;

  /// Lifecycle hooks fired around show/hide transitions. Replaceable for
  /// hosts that build their hooks after the driver; see [updateLifecycleHooks].
  PresentationLifecycleHooks lifecycleHooks;

  final StreamController<bool> _floatingChanges =
      StreamController<bool>.broadcast();
  final StreamController<PlayerId> _players =
      StreamController<PlayerId>.broadcast();

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

  /// PlayerIdentity the small window should show.
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

  /// Replaces the lifecycle hooks.
  ///
  /// Exists for hosts that build their hooks after the driver and for tests.
  void updateLifecycleHooks(PresentationLifecycleHooks? hooks) {
    lifecycleHooks = hooks ?? const PresentationLifecycleHooks();
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
        _log.warning(
          'floating driver asked for a mode it does not serve',
          fields: <String, Object?>{
            'mode': request.mode.name,
            'playerId': playerId.value,
          },
        );
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

  /// PlayerIdentity changes, for a host that binds its surface asynchronously.
  Stream<PlayerId> get onPlayerChanged => _players.stream;

  // ---------------------------------------------------------------------------
  // Show and hide
  // ---------------------------------------------------------------------------

  Future<void> _show(PlayerId playerId) async {
    if (_isFloating && _playerId == playerId) {
      return;
    }
    // A player swap keeps the window up, so the lifecycle only wraps an actual
    // hidden → visible transition, the same edge the change stream reports.
    final wasFloating = _isFloating;
    if (!wasFloating) {
      await _fire(PresentationLifecyclePhase.beforeEnter, playerId);
    }

    _log.info(
      'showing the in-app small window',
      fields: <String, Object?>{
        'playerId': playerId.value,
        'videoSize':
            '$_videoWidth'
            'x'
            '$_videoHeight',
      },
    );

    _playerId = playerId;
    if (!_players.isClosed) {
      _players.add(playerId);
    }

    final presenter = _presenter;
    if (presenter.isSupported) {
      // A host presenter takes over the surface entirely (a separate platform
      // window, a system overlay); the package overlay is what runs otherwise.
      _log.debug('delegating the surface to the host presenter');
      await presenter.show(
        FloatingWindowRequest(
          playerId: playerId.value,
          videoWidth: _videoWidth,
          videoHeight: _videoHeight,
        ),
      );
    } else {
      _log.debug('no host presenter; the package overlay renders the surface');
    }

    _setFloating(true);
    if (!wasFloating) {
      await _fire(PresentationLifecyclePhase.afterEnter, playerId);
    }
  }

  Future<void> _hide() async {
    if (!_isFloating) {
      return;
    }
    final playerId = _playerId ?? PlayerId('floating-unknown');

    await _fire(PresentationLifecyclePhase.beforeExit, playerId);
    _log.info(
      'hiding the in-app small window',
      fields: <String, Object?>{'playerId': _playerId?.value},
    );

    final presenter = _presenter;
    if (presenter.isSupported) {
      await presenter.hide();
    }

    _setFloating(false);
    await _fire(PresentationLifecyclePhase.afterExit, playerId);
  }

  void _setFloating(bool value) {
    if (value == _isFloating) {
      return;
    }
    _isFloating = value;
    _log.debug(
      'small window state changed',
      fields: <String, Object?>{'floating': value},
    );
    if (!_floatingChanges.isClosed) {
      _floatingChanges.add(value);
    }
  }

  /// Runs one lifecycle hook and reports failures without letting them reach
  /// the transition caller: hooks observe the transition, they never veto it.
  Future<void> _fire(
    PresentationLifecyclePhase phase,
    PlayerId playerId,
  ) async {
    final PresentationLifecycleHook? hook = switch (phase) {
      PresentationLifecyclePhase.beforeEnter => lifecycleHooks.beforeEnter,
      PresentationLifecyclePhase.afterEnter => lifecycleHooks.afterEnter,
      PresentationLifecyclePhase.beforeExit => lifecycleHooks.beforeExit,
      PresentationLifecyclePhase.afterExit => lifecycleHooks.afterExit,
    };
    if (hook == null) {
      return;
    }
    try {
      await hook(
        PresentationLifecycleEvent(
          phase: phase,
          playerId: playerId,
          mode: PresentationMode.floating,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning(
        'presentation lifecycle hook failed',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{
          'phase': phase.name,
          'playerId': playerId.value,
          'mode': PresentationMode.floating.name,
        },
      );
    }
  }
}
