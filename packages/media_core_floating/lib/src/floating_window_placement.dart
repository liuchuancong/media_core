import 'dart:ui' show Offset, Rect, Size;

/// Which corner (or edge) the small window rests against.
enum FloatingAnchor {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,

  /// Vertically centred against the left edge.
  centerLeft,

  /// Vertically centred against the right edge.
  centerRight;

  /// Whether the anchor hugs the left side of the surface.
  bool get isLeft => this == topLeft || this == bottomLeft || this == centerLeft;

  /// Whether the anchor hugs the right side of the surface.
  bool get isRight => this == topRight || this == bottomRight || this == centerRight;

  /// The horizontal edge this anchor clamps to.
  double clampLeft(Rect bounds, Size window, double margin) {
    return isLeft ? bounds.left + margin : bounds.right - window.width - margin;
  }
}

/// Which edge or corner a resize drag moves.
///
/// Every edge and every corner is addressable, so a host can offer the whole
/// frame as a grip instead of one corner: on a small window a viewer reaches
/// for whichever side is closest, and a single bottom-right grip forces a drag
/// across the picture to widen the window to the left.
enum FloatingResizeHandle {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  /// Whether the handle moves the left edge.
  bool get isLeft => this == left || this == topLeft || this == bottomLeft;

  /// Whether the handle moves the right edge.
  bool get isRight => this == right || this == topRight || this == bottomRight;

  /// Whether the handle moves the top edge.
  bool get isTop => this == top || this == topLeft || this == topRight;

  /// Whether the handle moves the bottom edge.
  bool get isBottom => this == bottom || this == bottomLeft || this == bottomRight;

  /// Whether the handle sits on a corner (both axes move).
  bool get isCorner => (isLeft || isRight) && (isTop || isBottom);

  /// Letters naming the corner for a semantics label (`topLeft` → `top left`).
  String get label => switch (this) {
    FloatingResizeHandle.left => 'left',
    FloatingResizeHandle.right => 'right',
    FloatingResizeHandle.top => 'top',
    FloatingResizeHandle.bottom => 'bottom',
    FloatingResizeHandle.topLeft => 'top left',
    FloatingResizeHandle.topRight => 'top right',
    FloatingResizeHandle.bottomLeft => 'bottom left',
    FloatingResizeHandle.bottomRight => 'bottom right',
  };

  /// All four edges and four corners: the whole frame resizes.
  static const Set<FloatingResizeHandle> all = <FloatingResizeHandle>{
    FloatingResizeHandle.left,
    FloatingResizeHandle.right,
    FloatingResizeHandle.top,
    FloatingResizeHandle.bottom,
    FloatingResizeHandle.topLeft,
    FloatingResizeHandle.topRight,
    FloatingResizeHandle.bottomLeft,
    FloatingResizeHandle.bottomRight,
  };

  /// The four corners only.
  static const Set<FloatingResizeHandle> corners = <FloatingResizeHandle>{
    FloatingResizeHandle.topLeft,
    FloatingResizeHandle.topRight,
    FloatingResizeHandle.bottomLeft,
    FloatingResizeHandle.bottomRight,
  };

  /// The four edges only.
  static const Set<FloatingResizeHandle> edges = <FloatingResizeHandle>{
    FloatingResizeHandle.left,
    FloatingResizeHandle.right,
    FloatingResizeHandle.top,
    FloatingResizeHandle.bottom,
  };
}

/// Tunables for the in-app small window's geometry.
final class FloatingPlacementConfig {
  const FloatingPlacementConfig({
    this.anchor = FloatingAnchor.bottomRight,
    this.margin = 12,
    this.width = 160,
    this.height = 90,
    this.minWidth = 96,
    this.minHeight = 54,
    this.maxWidthFraction = 0.5,
    this.snapToEdge = true,
    this.draggable = true,
    this.dragSnapThreshold = 48,
    this.resizableByDrag = false,
    this.aspectRatioFromVideo = true,
    this.resizeHandles = const <FloatingResizeHandle>{FloatingResizeHandle.bottomRight},
    this.resizeKeepsAspectRatio = true,
  });

  /// Caller-accepted defaults.
  static const FloatingPlacementConfig defaults = FloatingPlacementConfig();

  /// Where the window rests when it is not being dragged.
  final FloatingAnchor anchor;

  /// Distance kept between the window and the surface edges.
  final double margin;

  /// Width of the window at the reference aspect ratio.
  final double width;

  /// Height of the window at the reference aspect ratio.
  final double height;

  /// Smallest the window may be dragged to.
  final double minWidth;

  /// Shortest the window may be dragged to.
  final double minHeight;

  /// Largest fraction of the surface width the window may take.
  ///
  /// A small window that can grow past half the screen stops being a small
  /// window; expanding is what the full page is for.
  final double maxWidthFraction;

  /// Whether a released drag snaps to the nearest edge.
  final bool snapToEdge;

  /// Whether the window can be dragged at all.
  final bool draggable;

  /// How close to an edge a drag must end for it to snap.
  final double dragSnapThreshold;

  /// Whether dragging a corner resizes the window instead of moving it.
  final bool resizableByDrag;

  /// Whether the window's shape follows the video's aspect ratio.
  ///
  /// On by default: a small window is a video surface, and a letterboxed stripe
  /// in a fixed 16:9 box wastes most of the window on black.
  final bool aspectRatioFromVideo;

  /// Which edges and corners offer a resize grip.
  ///
  /// Only read while [resizableByDrag] is on. An empty set means "no grip at
  /// all"; the historical single bottom-right grip is the default so a host
  /// that never mentions handles keeps the window it had.
  final Set<FloatingResizeHandle> resizeHandles;

  /// Whether a resize keeps the video's shape.
  ///
  /// On by default, matching the original corner grip: the window stays a
  /// letterbox-free video surface. A host that lets the viewer choose any
  /// width and height (a freely shaped small window) turns this off together
  /// with [resizeHandles].
  final bool resizeKeepsAspectRatio;

  /// The handles actually offered: [resizeHandles] when the window resizes.
  Set<FloatingResizeHandle> get effectiveResizeHandles =>
      resizableByDrag ? resizeHandles : const <FloatingResizeHandle>{};

  FloatingPlacementConfig copyWith({
    FloatingAnchor? anchor,
    double? margin,
    double? width,
    double? height,
    double? minWidth,
    double? minHeight,
    double? maxWidthFraction,
    bool? snapToEdge,
    bool? draggable,
    double? dragSnapThreshold,
    bool? resizableByDrag,
    bool? aspectRatioFromVideo,
    Set<FloatingResizeHandle>? resizeHandles,
    bool? resizeKeepsAspectRatio,
  }) {
    return FloatingPlacementConfig(
      anchor: anchor ?? this.anchor,
      margin: margin ?? this.margin,
      width: width ?? this.width,
      height: height ?? this.height,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      maxWidthFraction: maxWidthFraction ?? this.maxWidthFraction,
      snapToEdge: snapToEdge ?? this.snapToEdge,
      draggable: draggable ?? this.draggable,
      dragSnapThreshold: dragSnapThreshold ?? this.dragSnapThreshold,
      resizableByDrag: resizableByDrag ?? this.resizableByDrag,
      aspectRatioFromVideo: aspectRatioFromVideo ?? this.aspectRatioFromVideo,
      resizeHandles: resizeHandles ?? this.resizeHandles,
      resizeKeepsAspectRatio: resizeKeepsAspectRatio ?? this.resizeKeepsAspectRatio,
    );
  }
}

/// Geometry of the in-app small window.
///
/// Responsibilities:
///
/// - size the window for the surface and the video's shape
/// - place it at its anchor, clamped inside the surface
/// - apply a drag, with edge snapping on release
///
/// It does not:
///
/// - draw anything (the widget does)
/// - know about players, rooms or playback
/// - move between surfaces (the host rebuilds it on layout changes)
///
/// Being pure geometry is what makes it worth having: the fiddly parts of a
/// small window — clamping after a rotation, a drag that ends near an edge, a
/// window that must stay reachable after the surface shrinks — are exactly the
/// parts that are painful to verify by hand and trivial to verify as maths.
final class FloatingWindowPlacement {
  const FloatingWindowPlacement({this.config = FloatingPlacementConfig.defaults});

  /// Tunables.
  final FloatingPlacementConfig config;

  /// Size of the window for [surface], following the video shape when the
  /// configuration asks for it.
  Size sizeFor({required Size surface, int? videoWidth, int? videoHeight}) {
    if (!config.aspectRatioFromVideo || videoWidth == null || videoHeight == null || videoWidth <= 0 || videoHeight <= 0) {
      return _clampSize(Size(config.width, config.height), surface);
    }

    final ratio = videoWidth / videoHeight;
    // Keep the configured long side and let the short side follow the video, so
    // a portrait stream gets a tall window rather than a squashed wide one.
    final landscape = ratio >= 1;
    final height = landscape ? config.height : config.width / ratio;
    final width = landscape ? config.height * ratio : config.width;
    return _clampSize(Size(width, height), surface);
  }

  /// Where the window sits inside [surface] for the configured anchor.
  Rect rectFor({
    required Size surface,
    required Size window,
    FloatingAnchor? anchor,
  }) {
    final resolved = anchor ?? config.anchor;
    final left = resolved.clampLeft(_bounds(surface), window, config.margin);
    final top = switch (resolved) {
      FloatingAnchor.topLeft || FloatingAnchor.topRight => config.margin,
      FloatingAnchor.bottomLeft || FloatingAnchor.bottomRight => surface.height - window.height - config.margin,
      FloatingAnchor.centerLeft || FloatingAnchor.centerRight => (surface.height - window.height) / 2,
    };
    return Rect.fromLTWH(left, top, window.width, window.height);
  }

  /// Rect for [connector]: the video rectangle the window was expanded from.
  ///
  /// Only used to animate the entrance; a caller that has no source rectangle
  /// passes the placed rect and gets no animation.
  Rect entranceFrom({required Rect placed}) => placed;

  /// Applies a drag [delta] to [current], clamped inside [surface].
  ///
  /// [window] is the size after the drag: with [FloatingPlacementConfig
  /// .resizableByDrag] a corner drag resizes, otherwise it moves.
  ///
  /// [resizeTo] is the size the grip asked for. [aspectRatio] keeps a resize on
  /// the video's shape: a small window is a video surface, and a free-form box
  /// letterboxes the picture inside it. The size floors still win when they
  /// conflict, so a window dragged to the smallest allowed width may end up a
  /// little wider than the source.
  Rect drag({
    required Rect current,
    required Offset delta,
    required Size surface,
    Size? resizeTo,
    double? aspectRatio,
  }) {
    if (!config.draggable) {
      return current;
    }

    if (config.resizableByDrag && resizeTo != null) {
      final target = _onAspectRatio(resizeTo, current.size, aspectRatio);
      final clamped = _clampSize(target, surface);
      final moved = current.topLeft + delta;
      return _clampRect(Rect.fromLTWH(moved.dx, moved.dy, clamped.width, clamped.height), surface);
    }

    return _clampRect(current.shift(delta), surface);
  }

  /// Applies a resize drag of [handle] to [current] by [delta].
  ///
  /// The opposite edge (or edges) of the dragged one stay put, which is what
  /// makes an edge grip feel attached to the side the viewer grabbed. The
  /// result is clamped the same way a placement is: no smaller than the
  /// configured floors, no wider than the surface fraction, and always inside
  /// [surface].
  ///
  /// With [FloatingPlacementConfig.resizeKeepsAspectRatio] the window keeps the
  /// video's shape: the axis the finger moved further drives both sides, the
  /// dragged edge stays under the finger, and the perpendicular axis grows
  /// around the window's centre (a corner keeps its opposite corner fixed).
  Rect resize({
    required Rect current,
    required Offset delta,
    required Size surface,
    required FloatingResizeHandle handle,
    double? aspectRatio,
  }) {
    final ratio = config.resizeKeepsAspectRatio ? aspectRatio : null;
    final locked = ratio != null && ratio.isFinite && ratio > 0;

    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;

    if (locked) {
      final requested = Size(
        handle.isLeft
            ? current.width - delta.dx
            : handle.isRight
            ? current.width + delta.dx
            : current.width,
        handle.isTop
            ? current.height - delta.dy
            : handle.isBottom
            ? current.height + delta.dy
            : current.height,
      );
      final target = _clampSize(_onAspectRatio(requested, current.size, ratio), surface);
      final horizontal = handle.isLeft || handle.isRight;
      final vertical = handle.isTop || handle.isBottom;
      // The dragged edge follows the finger; the opposite one is the anchor.
      final leftEdge = horizontal
          ? (handle.isLeft ? right - target.width : left)
          : current.center.dx - target.width / 2;
      final topEdge = vertical
          ? (handle.isTop ? bottom - target.height : top)
          : current.center.dy - target.height / 2;
      return _clampRect(Rect.fromLTWH(leftEdge, topEdge, target.width, target.height), surface);
    }

    if (handle.isLeft) left += delta.dx;
    if (handle.isRight) right += delta.dx;
    if (handle.isTop) top += delta.dy;
    if (handle.isBottom) bottom += delta.dy;

    final maxWidth = surface.width * config.maxWidthFraction.clamp(0.1, 1.0);
    final minWidth = config.minWidth;
    final minHeight = config.minHeight;
    final width = (right - left).clamp(minWidth, maxWidth > minWidth ? maxWidth : minWidth);
    final height = (bottom - top).clamp(minHeight, surface.height > minHeight ? surface.height : minHeight);
    // A clamped size pushes back the edge that was dragged, not the anchor.
    final anchoredLeft = handle.isLeft ? right - width : left;
    final anchoredTop = handle.isTop ? bottom - height : top;
    return _clampRect(Rect.fromLTWH(anchoredLeft, anchoredTop, width, height), surface);
  }

  /// The [requested] size, refitted to [ratio] from [from].
  ///
  /// Whichever axis the finger moved further drives the result, so the grip
  /// follows the hand instead of jumping to the other edge.
  Size _onAspectRatio(Size requested, Size from, double? ratio) {
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return requested;
    }
    final widthDriven = (requested.width - from.width).abs() >= (requested.height - from.height).abs();
    final width = widthDriven ? requested.width : requested.height * ratio;
    return Size(width, width / ratio);
  }

  /// Snaps [rect] to the nearest edge after a drag ends.
  ///
  /// Snapping only happens when the window was released near an edge, and only
  /// when the configuration allows it: a window that always teleports back to a
  /// corner fights the viewer.
  Rect snap({required Rect rect, required Size surface}) {
    if (!config.snapToEdge) {
      return _clampRect(rect, surface);
    }

    final bounds = _bounds(surface);
    final distanceToLeft = rect.left - bounds.left;
    final distanceToRight = bounds.right - rect.right;

    final nearest = distanceToLeft <= distanceToRight ? FloatingAnchor.centerLeft : FloatingAnchor.centerRight;
    if (distanceToLeft > config.dragSnapThreshold && distanceToRight > config.dragSnapThreshold) {
      return _clampRect(rect, surface);
    }

    return Rect.fromLTWH(
      nearest.clampLeft(bounds, rect.size, config.margin),
      rect.top,
      rect.width,
      rect.height,
    );
  }

  /// The anchor [rect] is currently closest to.
  FloatingAnchor nearestAnchor({required Rect rect, required Size surface}) {
    final bounds = _bounds(surface);
    final horizontal = rect.center.dx < bounds.center.dx ? FloatingAnchor.centerLeft : FloatingAnchor.centerRight;
    final vertical = rect.center.dy < bounds.center.dy;
    return switch (horizontal) {
      FloatingAnchor.centerLeft => vertical ? FloatingAnchor.topLeft : FloatingAnchor.bottomLeft,
      _ => vertical ? FloatingAnchor.topRight : FloatingAnchor.bottomRight,
    };
  }

  Rect _bounds(Size surface) => Rect.fromLTWH(0, 0, surface.width, surface.height);

  Size _clampSize(Size size, Size surface) {
    final bounds = _bounds(surface);
    final maxWidth = surface.width * config.maxWidthFraction.clamp(0.1, 1.0);
    return Size(
      size.width.clamp(config.minWidth, maxWidth > config.minWidth ? maxWidth : config.minWidth),
      size.height.clamp(config.minHeight, bounds.height),
    );
  }

  Rect _clampRect(Rect rect, Size surface) {
    final bounds = _bounds(surface);
    final maxLeft = bounds.right - rect.width;
    final maxTop = bounds.bottom - rect.height;
    return Rect.fromLTWH(
      rect.left.clamp(bounds.left, maxLeft < bounds.left ? bounds.left : maxLeft),
      rect.top.clamp(bounds.top, maxTop < bounds.top ? bounds.top : maxTop),
      rect.width,
      rect.height,
    );
  }
}
