import 'dart:async';

import 'package:flutter/widgets.dart';

import '../adapter/player_video_output.dart';
import '../kernel/player_handle.dart';
import '../screenshot/screenshot_surface.dart';
import 'player_view.dart';

/// Application-facing video widget for a [PlayerHandle].
///
/// This is the missing bridge between the kernel and the renderer
/// module: a consumer holds a [PlayerHandle], puts a [MediaPlayerView]
/// in the widget tree, and the view
///
/// - asks the attached adapter for its video widget through the
///   [PlayerVideo] interface (every video-capable adapter implements
///   it; adapters without video render the background only),
/// - re-builds when the recovery ladder swaps the backend, because it
///   follows [PlayerHandle.backendChanges] instead of holding on to the
///   previous adapter instance,
/// - fits the surface according to the geometry controller's aspect
///   ratio when the backend reports the video size,
/// - offers its video layer as a screenshot surface, so
///   [PlayerHandle.captureScreenshot] works on engines that have no
///   frame-capture API of their own.
///
/// The view never controls playback. Pausing, muting, recovery and
/// lifecycle belong to the handle; this widget only renders.
final class MediaPlayerView extends StatefulWidget {
  const MediaPlayerView({
    required this.handle,
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.mirror = false,
    this.backgroundColor = const Color(0xFF000000),
    this.captureBoundary = true,
  });

  /// The player whose video is rendered.
  final PlayerHandle handle;

  /// How the video is fitted into the view.
  final BoxFit fit;

  /// Alignment of the rendered content.
  final AlignmentGeometry alignment;

  /// Whether to mirror the rendered image horizontally.
  final bool mirror;

  /// Background color while no video widget is available.
  final Color? backgroundColor;

  /// Whether this view offers its video layer for screenshots.
  ///
  /// A [RepaintBoundary] around the video is what makes a surface capture
  /// possible, and it costs one extra composited layer. Disable it in a host
  /// that never takes screenshots and renders many players at once.
  final bool captureBoundary;

  @override
  State<MediaPlayerView> createState() => _MediaPlayerViewState();
}

final class _MediaPlayerViewState extends State<MediaPlayerView> {
  @override
  void initState() {
    super.initState();

    _bind(widget.handle);
  }

  StreamSubscription<void>? _backendSubscription;
  StreamSubscription<void>? _geometrySubscription;

  /// Boundary wrapping the video layer, used as a screenshot surface.
  ///
  /// Wraps the video only: everything the host stacks on top of this view
  /// stays out of a capture, which is what a "save this frame" action should
  /// produce.
  final GlobalKey _captureKey = GlobalKey();

  /// Surface handed to the handle while this view is bound to it.
  late final ScreenshotSurface _surface = ScreenshotSurface(boundaryKey: _captureKey);

  /// The video output currently attached, so its surface lifecycle can be
  /// released when the widget goes away or the handle changes.
  PlayerVideo? _attached;

  /// The video output the current build wants.
  PlayerVideo? _desired;

  bool _surfaceSyncScheduled = false;

  @override
  void didUpdateWidget(MediaPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.handle, widget.handle)) {
      _bind(widget.handle);

      return;
    }

    // The capture boundary may have been switched off (or on) for the same
    // handle; the surface has to follow, or a capture would read a boundary
    // that is no longer in the tree.
    if (oldWidget.captureBoundary != widget.captureBoundary) {
      _syncSurfaceAttachment(widget.handle);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Refreshed on every dependency change so a window moved to another
    // display captures at that display's density.
    _surface.devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context);
  }

  @override
  void dispose() {
    _unbind();

    super.dispose();
  }

  /// The handle this view registered its screenshot surface with, if any.
  PlayerHandle? _surfaceHost;

  /// Follows [handle] for as long as this widget displays it.
  ///
  /// Both subscriptions are held and cancelled: without that, a widget whose
  /// handle changed kept listening to the previous player, and every rebuild
  /// added another pair that was never released.
  void _bind(PlayerHandle handle) {
    _unbind();

    _syncSurfaceAttachment(handle);

    _backendSubscription = handle.backendChanges.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _geometrySubscription = handle.geometryController.state.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Keeps the handle's screenshot surface in sync with this widget.
  ///
  /// A surface is offered only while this widget renders the player *and* the
  /// capture boundary is enabled: attaching one whose boundary is not in the
  /// tree would make a capture report a surface it can never read.
  void _syncSurfaceAttachment(PlayerHandle handle) {
    if (_surfaceHost != null && !identical(_surfaceHost, handle)) {
      _releaseSurface();
    }

    if (!widget.captureBoundary || identical(_surfaceHost, handle)) {
      return;
    }

    _surfaceHost = handle;

    handle.attachScreenshotSurface(_surface);
  }

  void _releaseSurface() {
    _surfaceHost?.detachScreenshotSurface(_surface);

    _surfaceHost = null;
  }

  void _unbind() {
    _releaseSurface();

    _backendSubscription?.cancel();
    _backendSubscription = null;

    _geometrySubscription?.cancel();
    _geometrySubscription = null;

    // `attach`/`detach` exist for surfaces with an explicit lifecycle
    // (SurfaceTexture / PlatformView based engines); they are no-ops for the
    // engines that own their texture, which is why calling them
    // unconditionally is safe.
    final attached = _attached;

    _attached = null;
    _desired = null;

    if (attached != null) {
      unawaited(attached.detach());
    }
  }

  /// Attaches/detaches the surface after the frame.
  ///
  /// The transition is decided in `build` but performed here: `attach` can hit
  /// a platform channel, and a build pass must not.
  void _scheduleSurfaceSync() {
    if (_surfaceSyncScheduled) {
      return;
    }

    _surfaceSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _surfaceSyncScheduled = false;

      if (!mounted) {
        return;
      }

      final desired = _desired;
      final previous = _attached;

      if (identical(desired, previous)) {
        return;
      }

      _attached = desired;

      if (previous != null) {
        unawaited(previous.detach());
      }

      if (desired != null) {
        unawaited(desired.attach());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    final PlayerVideo? video = switch (handle.adapter) {
      final PlayerVideo output when output.available => output,
      _ => null,
    };

    _desired = video;

    if (!identical(video, _attached)) {
      _scheduleSurfaceSync();
    }

    // Without a video widget there is nothing to fit: [PlayerSurface] would
    // hand an expanding placeholder to a [FittedBox], which lays its child out
    // unbounded and asserts on the infinite scale that follows. An adapter
    // without video — an audio-only player, or one whose surface is not ready
    // yet — must render its background instead of crashing the frame.
    final Widget picture = video == null
        ? ColoredBox(color: _backgroundColor, child: const SizedBox.expand())
        : PlayerView(
            fit: widget.fit,
            alignment: widget.alignment,
            mirror: widget.mirror,
            backgroundColor: widget.backgroundColor,
            child: video.build(),
          );

    return AspectRatio(
      aspectRatio: _aspectRatio(handle),
      child: widget.captureBoundary ? RepaintBoundary(key: _captureKey, child: picture) : picture,
    );
  }

  Color get _backgroundColor => widget.backgroundColor ?? const Color(0xFF000000);

  double _aspectRatio(PlayerHandle handle) {
    final size = handle.geometryController.snapshot.videoSize;

    if (size == null || size.width <= 0 || size.height <= 0) {
      return 16 / 9;
    }

    return size.width / size.height;
  }
}
