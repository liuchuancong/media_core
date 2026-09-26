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
  Rect drag({
    required Rect current,
    required Offset delta,
    required Size surface,
    Size? resizeTo,
  }) {
    if (!config.draggable) {
      return current;
    }

    if (config.resizableByDrag && resizeTo != null) {
      final clamped = _clampSize(resizeTo, surface);
      final moved = current.topLeft + delta;
      return _clampRect(Rect.fromLTWH(moved.dx, moved.dy, clamped.width, clamped.height), surface);
    }

    return _clampRect(current.shift(delta), surface);
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
