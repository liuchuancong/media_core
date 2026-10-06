import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:media_core_floating/src/floating_window_placement.dart';

/// The in-app small window.
///
/// A video surface pinned inside the app's own widget tree: it floats above the
/// current page, follows the video's shape, can be dragged and snaps to an
/// edge. Nothing here touches the operating system's windows — the small window
/// lives inside the app, so it works the same on every platform, including ones
/// with no window API at all.
///
/// ```dart
/// Stack(
///   children: [
///     currentPage,
///     FloatingWindowOverlay(
///       visible: floatingDriver.onFloatingChanged,
///       initiallyVisible: floatingDriver.isFloating,
///       videoWidth: videoSize?.width,
///       videoHeight: videoSize?.height,
///       onExpand: floatingDriver.exit,
///       child: Video(player: floatingPlayer, controller: floatingController),
///     ),
///   ],
/// )
/// ```
///
/// The host owns the player and the video widget; this widget owns the
/// geometry, the drag and the visibility, which are the parts every host would
/// otherwise reimplement slightly differently.
class FloatingWindowOverlay extends StatefulWidget {
  const FloatingWindowOverlay({
    required this.visible,
    required this.child,
    this.initiallyVisible = false,
    this.placement = const FloatingWindowPlacement(),
    this.videoWidth,
    this.videoHeight,
    this.initialRect,
    this.onRectChanged,
    this.onExpand,
    this.onClose,
    this.expandControlKey,
    this.closeControlKey,
    this.resizeControlKey,
    super.key,
  });

  /// Visibility stream, typically `FloatingDriver.onFloatingChanged`.
  final Stream<bool> visible;

  /// Whether the window starts visible.
  ///
  /// Needed because a stream only reports changes: a window that was already
  /// floating when this widget mounted would otherwise appear one event late.
  final bool initiallyVisible;

  /// Video surface to float.
  final Widget child;

  /// Geometry rules.
  final FloatingWindowPlacement placement;

  /// Latest video size, used when the placement follows the video's shape.
  final int? videoWidth;
  final int? videoHeight;

  /// A remembered rect to restore instead of the configured anchor.
  ///
  /// Hosts feed back what [onRectChanged] reported, so a window the viewer
  /// positioned once comes back there instead of at the anchor. The rect is
  /// clamped into the current surface before use: remembered coordinates
  /// describe the surface they were captured on, which a rotation or a resized
  /// app window may have changed. Ignored when the configuration does not allow
  /// dragging, because then the window has no position of its own to keep.
  final Rect? initialRect;

  /// Reports the rect once it settles: after a move or resize ends, and once
  /// more when the window hides — the position worth remembering is the last
  /// one the viewer chose.
  final ValueChanged<Rect>? onRectChanged;

  /// Called when the viewer asks to return the video to the page.
  final VoidCallback? onExpand;

  /// Called when the viewer closes the small window.
  final VoidCallback? onClose;

  /// Keys for the two controls, so hosts and tests can address them.
  final Key? expandControlKey;
  final Key? closeControlKey;

  /// Key for the corner resize grip, addressed the same way as the other two.
  final Key? resizeControlKey;

  @override
  State<FloatingWindowOverlay> createState() => _FloatingWindowOverlayState();
}

class _FloatingWindowOverlayState extends State<FloatingWindowOverlay> {
  late bool _visible = widget.initiallyVisible;
  Rect? _rect;

  /// Surface the current rect was placed against.
  ///
  /// A rect is only reusable while the surface is unchanged: after a rotation
  /// the old coordinates describe a surface that no longer exists.
  Size? _placedForSurface;

  /// Whether a resize drag has taken ownership of the window size.
  ///
  /// Without this the next build compares the rect against the configured
  /// default size, finds them different, and puts the window back — a resize
  /// would last one frame.
  bool _userSized = false;

  /// Held so it can be cancelled: hosts build a fresh overlay for every
  /// open/close cycle, and an uncancelled listener accumulates one per cycle on
  /// a stream that outlives the widget.
  StreamSubscription<bool>? _visibilitySubscription;

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    _visibilitySubscription = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _visibilitySubscription = widget.visible.listen((value) {
      if (!mounted || value == _visible) {
        return;
      }
      final lastRect = _rect;
      setState(() {
        _visible = value;
        if (!value) {
          // Forgetting the rect on hide means the next appearance uses the
          // configured anchor again instead of an old drag position on a
          // surface that may have changed shape.
          _rect = null;
          _placedForSurface = null;
        }
      });
      if (!value && lastRect != null) {
        // Reported after the state settles: the host persists it, and a host
        // that rebuilds this overlay in response must not run inside setState.
        widget.onRectChanged?.call(lastRect);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FloatingWindowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement.config != widget.placement.config) {
      _rect = null;
      _placedForSurface = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = Size(constraints.maxWidth, constraints.maxHeight);
        final window = widget.placement.sizeFor(
          surface: surface,
          videoWidth: widget.videoWidth,
          videoHeight: widget.videoHeight,
        );
        final rect = _resolveRect(surface, window);
        return Stack(
          children: [
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: _buildWindow(),
            ),
          ],
        );
      },
    );
  }

  Rect _resolveRect(Size surface, Size window) {
    final current = _rect;
    if (current != null && _placedForSurface == surface && (_userSized || current.size == window)) {
      return current;
    }
    if (_placedForSurface != surface) {
      final restored = _restoreRect(surface);
      if (restored != null) {
        _rect = restored;
        _placedForSurface = surface;
        _userSized = true;
        return restored;
      }
    }
    final placed = widget.placement.rectFor(surface: surface, window: window);
    _rect = placed;
    _placedForSurface = surface;
    return placed;
  }

  /// The remembered rect, clamped back into the current surface.
  ///
  /// [FloatingWindowPlacement.drag] with a zero delta is exactly that clamp: it
  /// keeps the rect inside the surface, and with `resizableByDrag` it also brings
  /// the size back within the configured floor and the width cap.
  Rect? _restoreRect(Size surface) {
    if (!widget.placement.config.draggable) return null;
    final saved = widget.initialRect;
    if (saved == null || !saved.isFinite || saved.isEmpty) return null;
    if (!surface.isFinite || surface.isEmpty) return null;
    return widget.placement.drag(current: saved, delta: Offset.zero, surface: surface, resizeTo: saved.size);
  }

  /// The video's shape while the configuration asks the window to follow it.
  ///
  /// Null before the first frame reports a size, and for hosts that opted out
  /// of [FloatingPlacementConfig.aspectRatioFromVideo]: those windows keep the
  /// free-form resize the grip always had.
  double? get _videoAspectRatio {
    if (!widget.placement.config.aspectRatioFromVideo) {
      return null;
    }
    final width = widget.videoWidth;
    final height = widget.videoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  void _reportRect() {
    final rect = _rect;
    if (rect == null) return;
    widget.onRectChanged?.call(rect);
  }

  Widget _buildWindow() {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: widget.child,
    );

    final expandable = widget.onExpand != null;
    final closable = widget.onClose != null;

    Widget surface = child;
    if (expandable || closable) {
      surface = Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 2,
            right: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expandable)
                  _SmallWindowControl(
                    key: widget.expandControlKey,
                    semanticLabel: 'Expand',
                    onPressed: widget.onExpand!,
                    child: const Text('⤢', textAlign: TextAlign.center),
                  ),
                if (closable)
                  _SmallWindowControl(
                    key: widget.closeControlKey,
                    semanticLabel: 'Close small window',
                    onPressed: widget.onClose!,
                    child: const Text('✕', textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    Widget result = surface;
    if (widget.placement.config.draggable) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final surface = _placedForSurface;
          final current = _rect;
          if (surface == null || current == null) {
            return;
          }
          setState(() {
            _rect = widget.placement.drag(current: current, delta: details.delta, surface: surface);
          });
        },
        onPanEnd: (_) {
          final surface = _placedForSurface;
          final current = _rect;
          if (surface == null || current == null) {
            return;
          }
          setState(() {
            _rect = widget.placement.snap(rect: current, surface: surface);
          });
          _reportRect();
        },
        child: surface,
      );
    }

    if (widget.placement.config.resizableByDrag) {
      // The grips are siblings above the move recognizer, not inside it: as a
      // descendant the grip lost every pan to the window-move recognizer, which
      // then slid the window instead of resizing it.
      result = Stack(fit: StackFit.expand, children: [result, _buildResizeGrips()]);
    }

    return result;
  }

  /// A grip for every configured edge and corner.
  ///
  /// A single corner grip forces the viewer to drag across the picture to
  /// widen the window to the left; the whole frame being draggable is what a
  /// small window wants, so the host asks for the handles it wants (all of
  /// them by default in the app) and this widget draws one grip each.
  Widget _buildResizeGrips() {
    final handles = widget.placement.config.effectiveResizeHandles;
    if (handles.isEmpty) {
      return const SizedBox.shrink();
    }
    // Corners after edges: a corner's own area belongs to the corner.
    final ordered = <FloatingResizeHandle>[
      ...handles.where((handle) => !handle.isCorner),
      ...handles.where((handle) => handle.isCorner),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [for (final handle in ordered) _buildResizeHandle(handle)],
    );
  }

  /// One resize grip: an edge strip or a corner square.
  ///
  /// The top strip stops short of the window controls, so a tap meant for
  /// close or expand is never read as a resize.
  Widget _buildResizeHandle(FloatingResizeHandle handle) {
    final controlsReserved = (widget.onExpand != null || widget.onClose != null) ? 2 * _minTargetSize : 0.0;
    final key = handle == FloatingResizeHandle.bottomRight && widget.resizeControlKey != null
        ? widget.resizeControlKey
        : ValueKey<String>('floating-resize-${handle.name}');
    final grip = GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        final current = _rect;
        final surface = _placedForSurface;
        if (current == null || surface == null) {
          return;
        }
        setState(() {
          _userSized = true;
          _rect = widget.placement.resize(
            current: current,
            delta: details.delta,
            surface: surface,
            handle: handle,
            aspectRatio: _videoAspectRatio,
          );
        });
      },
      onPanEnd: (_) => _reportRect(),
      onPanCancel: _reportRect,
      child: Semantics(
        button: true,
        label: 'Resize small window ${handle.label}',
        // Invisible on purpose: a small window is a picture, and strips or
        // corner squares drawn on top of it read as dirt on the frame. The hit
        // region is what matters — dragging an edge still resizes.
        child: SizedBox(
          width: handle.isCorner ? _resizeCornerSize : null,
          height: handle.isCorner ? _resizeCornerSize : null,
        ),
      ),
    );

    if (handle.isLeft) {
      return Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: _resizeEdgeThickness,
        child: grip,
      );
    }
    if (handle.isRight) {
      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: _resizeEdgeThickness,
        child: grip,
      );
    }
    if (handle.isTop) {
      return Positioned(
        left: 0,
        top: 0,
        right: controlsReserved,
        height: _resizeEdgeThickness,
        child: grip,
      );
    }
    if (handle.isBottom) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _resizeEdgeThickness,
        child: grip,
      );
    }
    // Corners: the square sits in the corner its name says; the top-right one
    // again keeps clear of the controls.
    return Positioned(
      left: handle.isLeft ? 0 : null,
      right: handle.isRight ? (handle.isTop ? controlsReserved : 0) : null,
      top: handle.isTop ? 0 : null,
      bottom: handle.isBottom ? 0 : null,
      child: grip,
    );
  }
}

/// Thickness of an edge resize strip, in logical pixels.
const double _resizeEdgeThickness = 18;

/// Size of a corner resize square, in logical pixels.
const double _resizeCornerSize = 32;

/// Smallest comfortable touch target, kept local so this package does not have
/// to depend on the material library for one number.
const double _minTargetSize = 48;

class _SmallWindowControl extends StatelessWidget {
  const _SmallWindowControl({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTapDown: (_) {},
        onTap: onPressed,
        child: Container(
          width: _minTargetSize,
          height: _minTargetSize,
          alignment: Alignment.center,
          color: const Color(0x66000000),
          child: DefaultTextStyle(
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, height: 1),
            child: child,
          ),
        ),
      ),
    );
  }
}
