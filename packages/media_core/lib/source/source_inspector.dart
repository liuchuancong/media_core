import 'source_format.dart';
import 'source_descriptor.dart';
import 'source_media_type.dart';

/// Inspects media sources.
///
/// [SourceInspector] analyzes a source and extracts
/// additional media information.
///
/// Responsibilities:
///
/// - detect media type
/// - detect format
/// - detect duration
/// - detect stream information
///
/// It does not:
///
/// - open playback sessions
/// - create players
/// - manage network retry
///
/// Those belong to:
///
/// - PlayerSession
/// - PlayerAdapter
/// - RecoveryManager
final class SourceInspector {
  /// Creates a source inspector.
  const SourceInspector();

  /// Inspects a source descriptor.
  ///
  /// Default implementation only performs
  /// lightweight inspection based on known data.
  ///
  /// Platform adapters can extend this behavior.
  Future<SourceInspectionResult> inspect(SourceDescriptor descriptor) async {
    return SourceInspectionResult(
      format: descriptor.format,
      mediaType: descriptor.mediaType,
      live: descriptor.live,
      seekable: descriptor.seekable,
    );
  }
}

/// Result of source inspection.
///
/// Contains detected media information.
///
/// This object is separate from [SourceDescriptor]
/// because inspection is an operation result,
/// not source identity.
final class SourceInspectionResult {
  /// Creates inspection result.
  const SourceInspectionResult({
    required this.format,
    required this.mediaType,
    required this.live,
    required this.seekable,
    this.duration,
    this.videoWidth,
    this.videoHeight,
    this.videoCodec,
    this.audioCodec,
  });

  /// Detected container format.
  final SourceFormat format;

  /// Detected media type.
  final SourceMediaType mediaType;

  /// Whether source is live.
  final bool live;

  /// Whether seeking is supported.
  final bool seekable;

  /// Media duration.
  final Duration? duration;

  /// Video width.
  final int? videoWidth;

  /// Video height.
  final int? videoHeight;

  /// Video codec name.
  ///
  /// Example:
  /// - h264
  /// - hevc
  final String? videoCodec;

  /// Audio codec name.
  ///
  /// Example:
  /// - aac
  /// - opus
  final String? audioCodec;

  /// Whether video information exists.
  bool get hasVideoInfo {
    return videoWidth != null && videoHeight != null;
  }

  /// Whether codec information exists.
  bool get hasCodecInfo {
    return videoCodec != null || audioCodec != null;
  }

  /// Whether duration is known.
  bool get hasDuration {
    return duration != null;
  }

  /// Creates a copy with updated information.
  SourceInspectionResult copyWith({
    SourceFormat? format,
    SourceMediaType? mediaType,
    bool? live,
    bool? seekable,
    Duration? duration,
    int? videoWidth,
    int? videoHeight,
    String? videoCodec,
    String? audioCodec,
  }) {
    return SourceInspectionResult(
      format: format ?? this.format,
      mediaType: mediaType ?? this.mediaType,
      live: live ?? this.live,
      seekable: seekable ?? this.seekable,
      duration: duration ?? this.duration,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
    );
  }
}
