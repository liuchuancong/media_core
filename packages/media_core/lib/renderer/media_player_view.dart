import 'dart:async';

import 'package:flutter/widgets.dart';

import '../adapter/player_video_output.dart';
import '../kernel/player_handle.dart';
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
///   ratio when the backend reports the video size.
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
    }
  }

  @override
  void dispose() {
    _unbind();

    super.dispose();
  }

  /// Follows [handle] for as long as this widget displays it.
  ///
  /// Both subscriptions are held and cancelled: without that, a widget whose
  /// handle changed kept listening to the previous player, and every rebuild
  /// added another pair that was never released.
  void _bind(PlayerHandle handle) {
    _unbind();

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

  void _unbind() {
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

    return AspectRatio(
      aspectRatio: _aspectRatio(handle),
      child: PlayerView(
        fit: widget.fit,
        alignment: widget.alignment,
        mirror: widget.mirror,
        backgroundColor: widget.backgroundColor,
        child: video?.build() ?? const SizedBox.expand(),
      ),
    );
  }

  double _aspectRatio(PlayerHandle handle) {
    final size = handle.geometryController.snapshot.videoSize;

    if (size == null || size.width <= 0 || size.height <= 0) {
      return 16 / 9;
    }

    return size.width / size.height;
  }
}
