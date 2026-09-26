import 'package:flutter/widgets.dart';

import 'floating_window_placement.dart';

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
    this.onExpand,
    this.onClose,
    this.expandControlKey,
    this.closeControlKey,
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

  /// Called when the viewer asks to return the video to the page.
  final VoidCallback? onExpand;

  /// Called when the viewer closes the small window.
  final VoidCallback? onClose;

  /// Keys for the two controls, so hosts and tests can address them.
  final Key? expandControlKey;
  final Key? closeControlKey;

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

  @override
  void initState() {
    super.initState();
    widget.visible.listen((value) {
      if (!mounted || value == _visible) {
        return;
      }
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
    if (current != null && _placedForSurface == surface && current.size == window) {
      return current;
    }
    final placed = widget.placement.rectFor(surface: surface, window: window);
    _rect = placed;
    _placedForSurface = surface;
    return placed;
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

    if (!widget.placement.config.draggable) {
      return surface;
    }

    return GestureDetector(
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
      },
      child: surface,
    );
  }
}

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
