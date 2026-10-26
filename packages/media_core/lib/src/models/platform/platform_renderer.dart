import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/platform/platform_renderer_type.dart' show PlatformRendererType;

part 'platform_renderer.g.dart';

/// Describes video rendering capabilities.
///
/// [PlatformRenderer] defines how video frames
/// can be presented on the current platform.
///
/// Responsibilities:
///
/// - describe rendering backend
/// - describe hardware acceleration support
/// - describe texture/surface support
///
/// It does not:
///
/// - create renderer
/// - manage rendering lifecycle
///
/// Those belong to:
///
/// - VideoOutput
/// - Backend
abstract class PlatformRenderer implements Built<PlatformRenderer, PlatformRendererBuilder> {
  /// Builds PlatformRenderer from a [updates] callback — the codegen entry.
  factory PlatformRenderer([void Function(PlatformRendererBuilder)? updates]) = _$PlatformRenderer;

  /// Creates PlatformRenderer from the fields it describes.
  factory PlatformRenderer.of({
    PlatformRendererType type = PlatformRendererType.texture,
    bool hardwareAcceleration = true,
    bool gpuRendering = true,
    bool supportsSurface = false,
    bool supportsTexture = true,
    bool supportsOverlay = false,
  }) {
    return PlatformRenderer(
      (builder) => builder
        ..type = type
        ..hardwareAcceleration = hardwareAcceleration
        ..gpuRendering = gpuRendering
        ..supportsSurface = supportsSurface
        ..supportsTexture = supportsTexture
        ..supportsOverlay = supportsOverlay,
    );
  }

  PlatformRenderer._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformRendererBuilder builder) => builder
    ..type = PlatformRendererType.texture
    ..hardwareAcceleration = true
    ..gpuRendering = true
    ..supportsSurface = false
    ..supportsTexture = true
    ..supportsOverlay = false;

  /// Renderer type.
  PlatformRendererType get type;

  /// Whether hardware acceleration is available.
  bool get hardwareAcceleration;

  /// Whether GPU rendering is supported.
  bool get gpuRendering;

  /// Whether native surface rendering is supported.
  ///
  /// Example:
  ///
  /// - Android SurfaceView
  /// - MediaCodec Surface
  bool get supportsSurface;

  /// Whether Flutter texture rendering is supported.
  ///
  /// Example:
  ///
  /// - Texture widget
  /// - media_kit_video
  bool get supportsTexture;

  /// Whether native overlay rendering is supported.
  ///
  /// Example:
  ///
  /// - Windows video overlay
  /// - Direct rendering
  bool get supportsOverlay;

  /// Whether renderer can display video.
  bool get canRender {
    return supportsSurface || supportsTexture || supportsOverlay;
  }

  /// Whether GPU rendering is preferred.
  bool get preferHardware {
    return hardwareAcceleration && gpuRendering;
  }
}

/// Video rendering backend type.
