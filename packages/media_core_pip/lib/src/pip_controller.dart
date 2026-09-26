import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';

import 'pip_config.dart';
import 'pip_driver.dart';

/// When the small window should open on its own.
///
/// Each flag is a decision the viewer makes in settings, and each is separate:
/// someone may want the window when they leave the page but not when they
/// switch apps, or the other way round.
final class PipAutoEnterPolicy {
  const PipAutoEnterPolicy({
    this.onPageExit = true,
    this.onAppBackground = true,
    this.requirePlaying = true,
  });

  /// Caller-accepted defaults: both triggers, and only while playing.
  static const PipAutoEnterPolicy defaults = PipAutoEnterPolicy();

  /// Enter when the page showing the player goes away.
  final bool onPageExit;

  /// Enter when the app moves to the background.
  final bool onAppBackground;

  /// Require playback to be running.
  ///
  /// On by default: opening a small window for a paused video shows a frozen
  /// frame the viewer did not ask for, which reads as a bug.
  final bool requirePlaying;

  PipAutoEnterPolicy copyWith({bool? onPageExit, bool? onAppBackground, bool? requirePlaying}) {
    return PipAutoEnterPolicy(
      onPageExit: onPageExit ?? this.onPageExit,
      onAppBackground: onAppBackground ?? this.onAppBackground,
      requirePlaying: requirePlaying ?? this.requirePlaying,
    );
  }
}

/// What the small window is currently carrying.
final class PipSession {
  const PipSession({this.playerId, this.active = false, this.reason});

  /// Player being carried, or `null` when nothing is.
  final PlayerId? playerId;

  /// Whether the small window is up.
  final bool active;

  /// Why the last transition happened, for logs and for a host that wants to
  /// explain it.
  final String? reason;

  @override
  String toString() => 'PipSession(${active ? 'active' : 'idle'}${playerId == null ? '' : ', $playerId'})';
}

/// Owns the handover between a page and the picture-in-picture window.
///
/// Distinct from the core `presentation` module's `PipController`, which owns
/// the *logical mode state* (entered, transitioning, capabilities). This class
/// owns the *session*: which player is carried, when the window opens on its
/// own, and how the carried player is rendered. The mode controller answers
/// "is the app in PiP?"; this one answers "what is playing in it, and where did
/// it come from?".
///
/// Responsibilities:
///
/// - hold the player the small window carries, above the page's lifetime
/// - decide when to enter and leave, from an [PipAutoEnterPolicy]
/// - build the surface the small window renders
///
/// It does not:
///
/// - own the player (the kernel does; see below)
/// - speak to the platform ([PipDriver] does)
/// - render chrome around the video (the host does)
///
/// ## The handover, and why nothing is re-created
///
/// A viewer who leaves the page while a stream is playing expects the picture
/// to continue — same stream, same position, no gap. That rules out creating a
/// second player for the small window: a new player would re-open the source,
/// re-buffer, and pay for a second decode of the same stream.
///
/// The framework already has the mechanism for this. A [PlayerHandle] belongs
/// to the kernel, not to a page; a video surface is a widget built *from* that
/// handle (`MediaPlayerView(handle: ...)`). So handing over is not a transfer of
/// ownership at all: the page's widget simply goes away with the page, and this
/// controller builds another widget for the same handle in the small window.
///
/// The one thing the host must do is **not dispose the handle** when the page
/// that showed it goes away. Dispose it and there is nothing to carry — the
/// controller reports that rather than opening an empty window.
///
/// ## Page exit and app background are different events
///
/// Leaving the page usually means the host is about to pop a route while the
/// app stays in the foreground; backgrounding the app can happen while the page
/// is still mounted (the viewer pressed home). Both are reported here so the
/// policy can treat them separately, and both are host-triggered because only
/// the host knows when its own navigation or lifecycle events happen. The app
/// side can be wired to the core's `AppLifecycleDriver`, which already observes
/// the platform lifecycle.
final class PipSessionController {
  PipSessionController({
    required PipDriver driver,
    required PortablePlayerRegistry registry,
    this.config = PipConfig.defaults,
    this.autoEnter = PipAutoEnterPolicy.defaults,
    this.surfaceBuilder,
  }) : _driver = driver,
       _registry = registry;

  /// Builds a controller over a kernel's players.
  factory PipSessionController.forKernel({
    required PipDriver driver,
    required PlayerKernel kernel,
    PipConfig config = PipConfig.defaults,
    PipAutoEnterPolicy autoEnter = PipAutoEnterPolicy.defaults,
    Widget Function(BuildContext context, PlayerId playerId)? surfaceBuilder,
  }) {
    return PipSessionController(
      driver: driver,
      registry: KernelPortablePlayerRegistry(kernel),
      config: config,
      autoEnter: autoEnter,
      surfaceBuilder: surfaceBuilder,
    );
  }

  final PipDriver _driver;
  final PortablePlayerRegistry _registry;

  /// Geometry and platform tunables.
  final PipConfig config;

  /// When the window opens on its own.
  final PipAutoEnterPolicy autoEnter;

  /// Builds the small window's video surface for a player id.
  ///
  /// Defaults to the framework's own [MediaPlayerView] over the carried handle.
  /// A host overrides it to add controls, a danmaku layer or gestures — or to
  /// render a player the framework does not own, which is why the callback takes
  /// the id rather than a handle: an id always exists, a handle does not.
  final Widget Function(BuildContext context, PlayerId playerId)? surfaceBuilder;

  final StreamController<PipSession> _sessionController = StreamController<PipSession>.broadcast();

  PlayerId? _playerId;
  bool _disposed = false;

  /// Player currently carried, or `null`.
  PlayerId? get playerId => _playerId;

  /// Whether the small window is up.
  bool get isActive => _driver.isPip;

  /// Session changes.
  Stream<PipSession> get onSessionChanged => _sessionController.stream;

  /// Whether a player is being carried and still exists in the kernel.
  bool get hasCarriedPlayer {
    final id = _playerId;
    if (id == null) {
      return false;
    }
    final player = _registry.find(id);
    return player != null && !player.isDisposed;
  }

  /// Takes [playerId] into the small window and shows it.
  ///
  /// The handle must still exist: a page that disposed its player has nothing
  /// to hand over, and pretending otherwise would show a window with no video.
  Future<void> enter(PlayerId playerId, {String reason = 'requested'}) async {
    _ensureNotDisposed();

    final player = _registry.find(playerId);
    if (player == null || player.isDisposed) {
      throw StateError(
        'Player $playerId is gone: the page disposed it instead of leaving it to the kernel to carry.',
      );
    }

    _playerId = playerId;
    _emit(PipSession(playerId: playerId, active: true, reason: reason));

    _driver.onVideoSize(player.videoWidth, player.videoHeight);
    await _driver.initialize();
    await _driver.apply(playerId, PresentationRequest.pip());
  }

  /// Leaves the small window. The player stays alive for the host to re-attach.
  Future<void> exit({String reason = 'requested'}) async {
    _ensureNotDisposed();
    await _driver.initialize();
    await _driver.apply(_playerId ?? PlayerId('pip-idle'), PresentationRequest.normal());
    _emit(PipSession(playerId: _playerId, active: false, reason: reason));
  }

  /// Enters if idle, leaves if active.
  Future<void> toggle(PlayerId playerId) => isActive ? exit(reason: 'toggled off') : enter(playerId, reason: 'toggled on');

  /// Reports that the page showing [playerId] is going away.
  ///
  /// Returns whether the window was opened, so a host can log or react.
  Future<bool> onPageExit({required PlayerId playerId, required bool playing}) {
    if (!autoEnter.onPageExit) {
      return Future<bool>.value(false);
    }
    return _autoEnter(playerId, playing: playing, reason: 'page exit');
  }

  /// Reports that the app moved to the background while showing [playerId].
  Future<bool> onAppBackgrounded({required PlayerId playerId, required bool playing}) {
    if (!autoEnter.onAppBackground) {
      return Future<bool>.value(false);
    }
    return _autoEnter(playerId, playing: playing, reason: 'app backgrounded');
  }

  /// Reports that the app came back to the foreground.
  ///
  /// The window is left alone: the viewer may have started it deliberately, and
  /// closing it here would undo a choice they made.
  Future<void> onAppResumed() async {
    _ensureNotDisposed();
  }

  /// Builds the small window's surface for [playerId].
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

  /// Releases the controller.
  ///
  /// The player is left running: it belongs to the kernel, and a host that
  /// disposes this controller while the window is up is closing the window, not
  /// stopping playback.
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
      return false;
    }
    if (isActive && _playerId == playerId) {
      return true;
    }
    await enter(playerId, reason: reason);
    return true;
  }

  void _emit(PipSession session) {
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PipSessionController has been disposed.');
    }
  }
}
