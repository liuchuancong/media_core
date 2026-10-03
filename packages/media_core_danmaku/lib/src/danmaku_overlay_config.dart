import 'package:flame_barrage/flame_barrage.dart';

/// User-facing configuration for a danmaku overlay on a small surface.
///
/// A small window is not a small player: a 320-pixel-wide picture-in-picture
/// window with desktop-sized danmaku is unreadable, and a full-screen danmaku
/// count would flood it in seconds. Every knob here exists because the same
/// value that works on the main surface is wrong on the small one — which is
/// why the overlay carries its own configuration instead of reusing the main
/// session's.
///
/// The rendering knobs are the engine's vocabulary, and [toBarrageConfig] is
/// the single place that speaks it: a host that renders this surface with
/// flame_barrage gets one set of values instead of translating `area` to
/// `displayAreaFraction` by hand in two directions.
final class DanmakuOverlayConfig {
  const DanmakuOverlayConfig({
    this.enabled = true,
    this.maxMessages = 12,
    this.fps = 30,
    this.speedMultiplier = 1,
    this.fontSize = 14,
    this.opacity = 0.9,
    this.displayAreaFraction = 0.6,
    this.scaleWithSurface = true,
    this.referenceWidth = 360,
    this.minScale = 0.7,
    this.maxScale = 1.6,
    this.showStroke = true,
    this.strokeWidth = 1,
    this.clearOnHide = true,
  });

  /// Caller-accepted defaults: tuned for a small window, not for a page.
  static const DanmakuOverlayConfig defaults = DanmakuOverlayConfig();

  /// Whether the overlay renders at all.
  ///
  /// Turning it off stops the overlay from accepting messages; the main
  /// surface is unaffected.
  final bool enabled;

  /// Maximum messages kept on the small surface.
  ///
  /// Small on purpose: a small window is read at a glance, and an unbounded
  /// queue behind it only builds a backlog that arrives late.
  final int maxMessages;

  /// Render rate the host should drive the overlay at.
  final int fps;

  /// Multiplier applied to the message's own speed.
  ///
  /// Small surfaces need slower text: the same pixels-per-second that reads
  /// well across a desktop window crosses a small window in a blink.
  final double speedMultiplier;

  /// Base font size, before [scaleWithSurface].
  final double fontSize;

  /// Overlay opacity, applied on top of the message's own opacity.
  final double opacity;

  /// Fraction of the surface height danmaku may use, measured from the top.
  ///
  /// Keeps the bottom of a small window clear for controls, which on a small
  /// surface are proportionally larger.
  final double displayAreaFraction;

  /// Whether [fontSize] is scaled by the surface width.
  final bool scaleWithSurface;

  /// Surface width at which [fontSize] is used unscaled.
  final double referenceWidth;

  /// Lower bound for the surface scale factor.
  final double minScale;

  /// Upper bound for the surface scale factor.
  final double maxScale;

  /// Whether text is stroked, which is what keeps it readable over video.
  final bool showStroke;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// Whether the overlay is emptied when its surface is hidden.
  ///
  /// On by default: a danmaku queue that survives the small window would replay
  /// its backlog the next time the window appears, which reads as a glitch.
  final bool clearOnHide;

  DanmakuOverlayConfig copyWith({
    bool? enabled,
    int? maxMessages,
    int? fps,
    double? speedMultiplier,
    double? fontSize,
    double? opacity,
    double? displayAreaFraction,
    bool? scaleWithSurface,
    double? referenceWidth,
    double? minScale,
    double? maxScale,
    bool? showStroke,
    double? strokeWidth,
    bool? clearOnHide,
  }) {
    return DanmakuOverlayConfig(
      enabled: enabled ?? this.enabled,
      maxMessages: maxMessages ?? this.maxMessages,
      fps: fps ?? this.fps,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      displayAreaFraction: displayAreaFraction ?? this.displayAreaFraction,
      scaleWithSurface: scaleWithSurface ?? this.scaleWithSurface,
      referenceWidth: referenceWidth ?? this.referenceWidth,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
      showStroke: showStroke ?? this.showStroke,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      clearOnHide: clearOnHide ?? this.clearOnHide,
    );
  }

  /// The same rendering decisions, in the engine's vocabulary.
  ///
  /// [baseSpeed] is the pixels-per-second that [speedMultiplier] multiplies.
  /// The engine's speed is absolute and this config's is relative, so the
  /// reference has to come from somewhere: pass the main surface's speed and
  /// the small window keeps the relationship the multiplier expresses.
  ///
  /// Four fields have no engine counterpart and stay here, because they are
  /// about this surface rather than about how a message looks:
  ///
  /// - [enabled] and [clearOnHide] are policy the session applies.
  /// - [scaleWithSurface], [referenceWidth], [minScale] and [maxScale] scale
  ///   the font by the surface width, and the engine is never told how wide
  ///   its surface is. A host that wants the scaled size computes it (the
  ///   session already does, in `DanmakuOverlaySession.fontSizeFor`) and
  ///   passes the result as `fontSize` on the returned config's `copyWith`.
  BarrageConfig toBarrageConfig({double baseSpeed = 120}) {
    return BarrageConfig(
      fontSize: fontSize,
      opacity: opacity,
      fps: fps,
      area: displayAreaFraction,
      showStroke: showStroke,
      strokeWidth: strokeWidth,
      baseSpeed: baseSpeed * speedMultiplier,
      maxVisibleCount: maxMessages,
    );
  }
}
