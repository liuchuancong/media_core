import 'video_size.dart';
import 'pixel_ratio.dart';
import 'display_size.dart';
import 'aspect_ratio.dart';
import 'video_rotation.dart';
import 'video_orientation.dart';
import 'package:equatable/equatable.dart';

/// Complete video geometry information.
///
/// Immutable value object.
///
/// Contains:
///
/// - source video dimension
/// - display output dimension
/// - aspect ratio
/// - orientation
/// - rotation metadata
/// - pixel ratio
///
/// Used by:
///
/// - GeometryController
/// - Renderer
/// - PlayerSnapshot
///
/// Does not:
///
/// - perform layout
/// - resize surface
/// - control renderer
final class VideoGeometry extends Equatable {
  const VideoGeometry({
    required this.videoSize,
    required this.displaySize,
    required this.aspectRatio,
    required this.orientation,
    required this.rotation,
    required this.pixelRatio,
  });

  /// Empty geometry.
  const VideoGeometry.empty()
    : videoSize = const VideoSize.zero(),
      displaySize = const DisplaySize.zero(),
      aspectRatio = const AspectRatioValue.zero(),
      orientation = const VideoOrientationInfo(orientation: VideoOrientation.unknown),
      rotation = const VideoRotationInfo.none(),
      pixelRatio = const PixelRatioValue.one();

  /// Source media size.
  final VideoSize videoSize;

  /// Render target size.
  final DisplaySize displaySize;

  /// Video aspect ratio.
  final AspectRatioValue aspectRatio;

  /// Video orientation metadata.
  final VideoOrientationInfo orientation;

  /// Rotation metadata.
  final VideoRotationInfo rotation;

  /// Device pixel density.
  final PixelRatioValue pixelRatio;

  /// Whether video size is valid.
  bool get hasVideo {
    return videoSize.isValid;
  }

  /// Whether display size is valid.
  bool get hasDisplay {
    return displaySize.isValid;
  }

  /// Whether geometry can be rendered.
  bool get canRender {
    return hasVideo && hasDisplay && aspectRatio.isValid;
  }

  /// Width after rotation.
  double get effectiveWidth {
    if (rotation.swapsAspectRatio) {
      return videoSize.height.toDouble();
    }

    return videoSize.width.toDouble();
  }

  /// Height after rotation.
  double get effectiveHeight {
    if (rotation.swapsAspectRatio) {
      return videoSize.width.toDouble();
    }

    return videoSize.height.toDouble();
  }

  /// Effective aspect ratio after rotation.
  double get effectiveAspectRatio {
    final height = effectiveHeight;

    if (height <= 0) {
      return 0;
    }

    return effectiveWidth / height;
  }

  /// Whether portrait.
  bool get isPortrait {
    return orientation.effectiveOrientation == VideoOrientation.portrait;
  }

  /// Whether landscape.
  bool get isLandscape {
    return orientation.effectiveOrientation == VideoOrientation.landscape;
  }

  /// Whether square.
  bool get isSquare {
    return orientation.effectiveOrientation == VideoOrientation.square;
  }

  /// Whether rotated.
  bool get isRotated {
    return rotation.swapsAspectRatio;
  }

  /// Whether mirrored.
  bool get isMirrored {
    return orientation.mirrored;
  }

  /// Creates geometry with new video size.
  VideoGeometry copyWithVideoSize(VideoSize size) {
    return VideoGeometry(
      videoSize: size,
      displaySize: displaySize,
      aspectRatio: AspectRatioValue.fromSize(size),
      orientation: VideoOrientationInfo.fromSize(size.width, size.height),
      rotation: rotation,
      pixelRatio: pixelRatio,
    );
  }

  /// Creates geometry with new display size.
  VideoGeometry copyWithDisplaySize(DisplaySize size) {
    return VideoGeometry(
      videoSize: videoSize,
      displaySize: size,
      aspectRatio: aspectRatio,
      orientation: orientation,
      rotation: rotation,
      pixelRatio: pixelRatio,
    );
  }

  /// Creates geometry with new rotation.
  VideoGeometry copyWithRotation(VideoRotationInfo value) {
    return VideoGeometry(
      videoSize: videoSize,
      displaySize: displaySize,
      aspectRatio: aspectRatio,
      orientation: orientation,
      rotation: value,
      pixelRatio: pixelRatio,
    );
  }

  /// Creates geometry with new pixel ratio.
  VideoGeometry copyWithPixelRatio(PixelRatioValue value) {
    return VideoGeometry(
      videoSize: videoSize,
      displaySize: displaySize,
      aspectRatio: aspectRatio,
      orientation: orientation,
      rotation: rotation,
      pixelRatio: value,
    );
  }

  /// Creates geometry with all values recalculated.
  VideoGeometry copyWith({
    VideoSize? videoSize,
    DisplaySize? displaySize,
    VideoRotationInfo? rotation,
    PixelRatioValue? pixelRatio,
  }) {
    final newVideoSize = videoSize ?? this.videoSize;

    final newRotation = rotation ?? this.rotation;

    return VideoGeometry(
      videoSize: newVideoSize,
      displaySize: displaySize ?? this.displaySize,
      aspectRatio: AspectRatioValue.fromSize(newVideoSize),
      orientation: VideoOrientationInfo.fromSize(newVideoSize.width, newVideoSize.height),
      rotation: newRotation,
      pixelRatio: pixelRatio ?? this.pixelRatio,
    );
  }

  /// Debug serialization.
  Map<String, dynamic> toMap() {
    return {
      'videoSize': videoSize.toMap(),
      'displaySize': displaySize.toMap(),
      'aspectRatio': aspectRatio.value,
      'orientation': orientation.toMap(),
      'rotation': rotation.toMap(),
      'pixelRatio': pixelRatio.value,
    };
  }

  factory VideoGeometry.fromMap(Map<String, dynamic> map) {
    return VideoGeometry(
      videoSize: VideoSize.fromMap(map['videoSize'] as Map<String, dynamic>),
      displaySize: DisplaySize.fromMap(map['displaySize'] as Map<String, dynamic>),
      aspectRatio: AspectRatioValue(map['aspectRatio'] as double? ?? 0),
      orientation: VideoOrientationInfo.fromMap(map['orientation'] as Map<String, dynamic>),
      rotation: VideoRotationInfo.fromMap(map['rotation'] as Map<String, dynamic>),
      pixelRatio: PixelRatioValue(map['pixelRatio'] as double? ?? 1),
    );
  }

  @override
  List<Object?> get props => [videoSize, displaySize, aspectRatio, orientation, rotation, pixelRatio];

  @override
  String toString() {
    return 'VideoGeometry('
        'video=$videoSize, '
        'display=$displaySize, '
        'orientation=$orientation, '
        'rotation=$rotation'
        ')';
  }
}
