import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/platform/platform_surface_type.dart' show PlatformSurfaceType;

part 'platform_surface.g.dart';

/// Describes video output surface.
///
/// [PlatformSurface] represents the rendering
/// surface requirements and capabilities.
///
/// Responsibilities:
///
/// - describe surface type
/// - describe texture support
/// - describe lifecycle behavior
///
/// It does not:
///
/// - create surface
/// - own native resources
///
/// Those belong to:
///
/// - VideoOutput
/// - Renderer implementation
abstract class PlatformSurface implements Built<PlatformSurface, PlatformSurfaceBuilder> {
  /// Builds PlatformSurface from a [updates] callback — the codegen entry.
  factory PlatformSurface([void Function(PlatformSurfaceBuilder)? updates]) = _$PlatformSurface;

  /// Creates PlatformSurface from the fields it describes.
  factory PlatformSurface.of({
    PlatformSurfaceType type = PlatformSurfaceType.texture,
    bool supportsResize = true,
    bool supportsRotation = true,
    bool requiresRecreationOnSizeChange = false,
    bool persistent = true,
    int? id,
  }) {
    return PlatformSurface(
      (builder) => builder
        ..type = type
        ..supportsResize = supportsResize
        ..supportsRotation = supportsRotation
        ..requiresRecreationOnSizeChange = requiresRecreationOnSizeChange
        ..persistent = persistent
        ..id = id,
    );
  }

  PlatformSurface._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformSurfaceBuilder builder) => builder
    ..type = PlatformSurfaceType.texture
    ..supportsResize = true
    ..supportsRotation = true
    ..requiresRecreationOnSizeChange = false
    ..persistent = true;

  /// Surface type.
  PlatformSurfaceType get type;

  /// Runtime surface identifier.
  ///
  /// Example:
  ///
  /// - Flutter texture id
  /// - native surface handle
  int? get id;

  /// Whether surface supports resize.
  bool get supportsResize;

  /// Whether surface supports rotation changes.
  bool get supportsRotation;

  /// Whether surface must be recreated
  /// when video size changes.
  ///
  /// Some Android rendering pipelines require
  /// recreation when switching:
  ///
  /// - portrait video
  /// - landscape video
  bool get requiresRecreationOnSizeChange;

  /// Whether surface can survive source changes.
  bool get persistent;

  /// Whether this is a texture surface.
  bool get isTexture {
    return type == PlatformSurfaceType.texture;
  }

  /// Whether this is native surface.
  bool get isNative {
    return type == PlatformSurfaceType.surface;
  }

  /// Whether surface can be reused.
  bool get canReuse {
    return persistent && !requiresRecreationOnSizeChange;
  }
}

/// Video output surface type.
