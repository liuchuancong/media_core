import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';

import 'floating_config.dart';
import 'floating_driver.dart';
import 'floating_window_overlay.dart';
import 'floating_window_placement.dart';

/// Decision trail for the in-app small window's session.
final LogModule _log = MediaCoreLog.of(LogCategory.presentation);

/// When the in-app small window should open on its own.
///
/// The same two triggers as picture-in-picture, kept separate because a viewer
/// may want one and not the other: leaving a page is a navigation choice, going
/// to the background is a system one.
final class FloatingAutoEnterPolicy {
  const FloatingAutoEnterPolicy({this.onPageExit = true, this.onAppBackground = false, this.requirePlaying = true});

  /// Caller-accepted defaults for an in-app window.
  ///
  /// Page exit only: an in-app small window is *inside* the app, so opening one
  /// because the app went to the background would show nothing — the app is not
  /// on screen. That case belongs to picture-in-picture.
  static const FloatingAutoEnterPolicy defaults = FloatingAutoEnterPolicy();

  /// Enter when the page showing the player goes away.
  final bool onPageExit;

  /// Enter when the app moves to the background.
  ///
  /// Off by default, for the reason above; a host that wants it (a keep-alive
  /// preview before the OS shows its own window) can turn it on.
  final bool onAppBackground;

  /// Require playback to be running.
  final bool requirePlaying;

  FloatingAutoEnterPolicy copyWith({bool? onPageExit, bool? onAppBackground, bool? requirePlaying}) {
    return FloatingAutoEnterPolicy(
      onPageExit: onPageExit ?? this.onPageExit,
      onAppBackground: onAppBackground ?? this.onAppBackground,
      requirePlaying: requirePlaying ?? this.requirePlaying,
    );
  }
}

/// What the small window is carrying.
final class FloatingSession {
  const FloatingSession({this.playerId, this.active = false, this.reason});

  /// Player being carried, or `null` when nothing is.
  final PlayerId? playerId;

  /// Whether the small window is up.
  final bool active;

  /// Why the last transition happened.
  final String? reason;

  @override
  String toString() => 'FloatingSession(${active ? 'active' : 'idle'}${playerId == null ? '' : ', $playerId'})';
}

/// Owns the handover between a page and the in-app small window.
///
/// Distinct from the core `presentation` module's `FloatingController`, which
/// owns the logical mode state. This class owns the session: which player is
/// carried, when the window opens on its own, and how it is rendered.
///
/// Responsibilities:
///
/// - hold the player the small window carries, above the page's lifetime
/// - decide when to show and hide it, from a [FloatingAutoEnterPolicy]
/// - build the overlay and the video surface for it
///
/// It does not:
///
/// - own the player (the kernel does)
/// - draw the window's chrome (the host composes it, or uses [buildOverlay])
/// - render danmaku (`media_core_danmaku`'s overlay session binds to
///   [FloatingDriver.onFloatingChanged])
///
/// ## The handover
///
/// See `PortablePlayer` in the core: a player belongs to the kernel, and a
/// surface is a widget built from its handle. Popping a page therefore costs
/// nothing to hand over — the page's widget goes away, this controller builds
/// another one for the same handle, and playback is untouched. The one
/// requirement on the host is to **not dispose the handle** when the page that
/// showed it goes away.
///
/// ## Why the surface is built here and the chrome is not
///
/// [buildOverlay] produces a ready small window: the package's own
/// [FloatingWindowOverlay] wrapped around the video surface, so a host with no
/// special requirements mounts one widget. A host that wants its own chrome
/// calls [buildSurface] and places it itself.
final class FloatingSessionController {
  FloatingSessionController({
    required FloatingDriver driver,
    required PortablePlayerRegistry registry,
    this.config = FloatingConfig.defaults,
    this.autoEnter = FloatingAutoEnterPolicy.defaults,
    this.surfaceBuilder,
  }) : _driver = driver,
       _registry = registry;

  /// Builds a controller over a kernel's players.
  factory FloatingSessionController.forKernel({
    required FloatingDriver driver,
    required PlayerKernel kernel,
    FloatingConfig config = FloatingConfig.defaults,
    FloatingAutoEnterPolicy autoEnter = FloatingAutoEnterPolicy.defaults,
    Widget Function(BuildContext context, PlayerId playerId)? surfaceBuilder,
  }) {
    return FloatingSessionController(
      driver: driver,
      registry: KernelPortablePlayerRegistry(kernel),
      config: config,
      autoEnter: autoEnter,
      surfaceBuilder: surfaceBuilder,
    );
  }

  final FloatingDriver _driver;
  final PortablePlayerRegistry _registry;

  /// Geometry and behaviour.
  final FloatingConfig config;

  /// When the window opens on its own.
  final FloatingAutoEnterPolicy autoEnter;

  /// Builds the small window's video surface for a player id.
  ///
  /// Defaults to the framework's [MediaPlayerView] over the carried handle. The
  /// callback takes the id rather than a handle so a host-owned player — which
  /// has no framework handle — can be rendered by the host that owns it.
  final Widget Function(BuildContext context, PlayerId playerId)? surfaceBuilder;

  final StreamController<FloatingSession> _sessionController = StreamController<FloatingSession>.broadcast();

  PlayerId? _playerId;
  bool _disposed = false;

  /// Player currently carried, or `null`.
  PlayerId? get playerId => _playerId;

  /// Whether the small window is up.
  bool get isActive => _driver.isFloating;

  /// Session changes.
  Stream<FloatingSession> get onSessionChanged => _sessionController.stream;

  /// Whether a player is being carried and still exists.
  bool get hasCarriedPlayer {
    final id = _playerId;
    if (id == null) {
      return false;
    }
    final player = _registry.find(id);
    return player != null && !player.isDisposed;
  }

  /// Takes [playerId] into the small window and shows it.
  Future<void> show(PlayerId playerId, {String reason = 'requested'}) async {
    _ensureNotDisposed();

    final player = _registry.find(playerId);
    if (player == null || player.isDisposed) {
      _log.error(
        'cannot show the small window: player is gone',
        fields: <String, Object?>{'playerId': playerId.value, 'reason': reason},
      );
      throw StateError('Player $playerId is gone: the page disposed it instead of leaving it to the kernel to carry.');
    }

    _log.info(
      'carrying the player into the small window',
      fields: <String, Object?>{
        'playerId': playerId.value,
        'reason': reason,
        'videoSize': '${player.videoWidth}x${player.videoHeight}',
      },
    );

    _playerId = playerId;
    _emit(FloatingSession(playerId: playerId, active: true, reason: reason));

    _driver.onVideoSize(player.videoWidth, player.videoHeight);
    await _driver.initialize();
    await _driver.apply(playerId, PresentationRequest.floating());
  }

  /// Hides the small window.
  ///
  /// The player keeps running unless [FloatingConfig.keepPlayingWhenHidden] is
  /// off: the viewer collapsed the window, not the video.
  Future<void> hide({String reason = 'requested'}) async {
    _ensureNotDisposed();
    _log.info('hiding the small window', fields: <String, Object?>{'playerId': _playerId?.value, 'reason': reason});
    await _driver.initialize();
    await _driver.apply(_playerId ?? PlayerId('floating-idle'), PresentationRequest.normal());
    _emit(FloatingSession(playerId: _playerId, active: false, reason: reason));
  }

  /// Shows the window if hidden, hides it if shown.
  Future<void> toggle(PlayerId playerId) =>
      isActive ? hide(reason: 'toggled off') : show(playerId, reason: 'toggled on');

  /// Reports that the page showing [playerId] is going away.
  Future<bool> onPageExit({required PlayerId playerId, required bool playing}) {
    if (!autoEnter.onPageExit) {
      return Future<bool>.value(false);
    }
    return _autoEnter(playerId, playing: playing, reason: 'page exit');
  }

  /// Reports that the app moved to the background.
  Future<bool> onAppBackgrounded({required PlayerId playerId, required bool playing}) {
    if (!autoEnter.onAppBackground) {
      return Future<bool>.value(false);
    }
    return _autoEnter(playerId, playing: playing, reason: 'app backgrounded');
  }

  /// Reports that the app came back to the foreground: nothing to undo, since
  /// an in-app window is already visible to the viewer.
  Future<void> onAppResumed() async {
    _ensureNotDisposed();
  }

  /// Builds the video surface for [playerId].
  Widget buildSurface(BuildContext context, PlayerId playerId, {BoxFit fit = BoxFit.contain}) {
    final builder = surfaceBuilder;
    if (builder != null) {
      return builder(context, playerId);
    }

    final handle = _registry.find(playerId)?.handle;
    if (handle == null) {
      throw StateError(
        'Player $playerId has no framework handle; supply surfaceBuilder to render a host-owned player.',
      );
    }
    return MediaPlayerView(handle: handle, fit: fit);
  }

  /// Builds the ready-to-mount small window for [playerId].
  ///
  /// Mount it above the page in a `Stack`; it hides itself when the driver is
  /// not floating, so a host can keep it in the tree permanently.
  Widget buildOverlay(
    BuildContext context,
    PlayerId playerId, {
    VoidCallback? onExpand,
    VoidCallback? onClose,
    BoxFit fit = BoxFit.contain,
  }) {
    return FloatingWindowOverlay(
      visible: _driver.onFloatingChanged,
      initiallyVisible: _driver.isFloating,
      placement: FloatingWindowPlacement(config: config.placement),
      videoWidth: _driver.videoWidth,
      videoHeight: _driver.videoHeight,
      onExpand: onExpand,
      onClose: onClose ?? hide,
      child: buildSurface(context, playerId, fit: fit),
    );
  }

  /// Releases the controller.
  ///
  /// The player keeps running: it belongs to the kernel.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await DisposeUtils.close(_sessionController);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<bool> _autoEnter(PlayerId playerId, {required bool playing, required String reason}) async {
    _ensureNotDisposed();
    if (autoEnter.requirePlaying && !playing) {
      _log.debug(
        'auto-show skipped: not playing',
        fields: <String, Object?>{'playerId': playerId.value, 'trigger': reason},
      );
      return false;
    }
    if (isActive && _playerId == playerId) {
      _log.debug(
        'auto-show skipped: already carrying this player',
        fields: <String, Object?>{'playerId': playerId.value, 'trigger': reason},
      );
      return true;
    }
    await show(playerId, reason: reason);
    return true;
  }

  void _emit(FloatingSession session) {
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('FloatingSessionController has been disposed.');
    }
  }
}
