import 'package:equatable/equatable.dart';

/// Describes capabilities of a player adapter.
///
/// [PlayerAdapterCapabilities] represents static
/// features supported by a playback backend.
///
/// Examples:
///
/// - media_kit supports hardware decoding
/// - native player supports platform PiP
/// - simple backend may not support seeking
///
/// Responsibilities:
///
/// - describe backend features
/// - support adapter selection
///
/// It does not:
///
/// - store runtime state
/// - track playback metrics
/// - manage resources
///
/// Those belong to:
///
/// - PlayerAdapterState
/// - PlayerAdapterMetrics
final class PlayerAdapterCapabilities extends Equatable {
  /// Creates adapter capabilities.
  const PlayerAdapterCapabilities({
    this.supportsLive = false,
    this.supportsSeek = false,
    this.supportsPause = false,
    this.supportsRateControl = false,
    this.supportsVolumeControl = false,
    this.supportsHardwareDecoder = false,
    this.supportsSoftwareDecoder = true,
    this.supportsPictureInPicture = false,
    this.supportsFullscreen = false,
    this.supportedProtocols = const {},
    this.supportedFormats = const {},
  });

  /// Whether live playback is supported.
  final bool supportsLive;

  /// Whether seeking is supported.
  final bool supportsSeek;

  /// Whether pause is supported.
  final bool supportsPause;

  /// Whether playback speed control is supported.
  final bool supportsRateControl;

  /// Whether volume control is supported.
  final bool supportsVolumeControl;

  /// Whether hardware decoding is supported.
  final bool supportsHardwareDecoder;

  /// Whether software decoding is supported.
  final bool supportsSoftwareDecoder;

  /// Whether Picture-in-Picture is supported.
  final bool supportsPictureInPicture;

  /// Whether fullscreen presentation is supported.
  final bool supportsFullscreen;

  /// Supported protocols.
  ///
  /// Example:
  ///
  /// - http
  /// - https
  /// - rtmp
  final Set<String> supportedProtocols;

  /// Supported formats.
  ///
  /// Example:
  ///
  /// - hls
  /// - flv
  /// - mp4
  final Set<String> supportedFormats;

  /// Whether adapter can handle protocol.
  bool supportsProtocol(String protocol) {
    return supportedProtocols.contains(protocol.toLowerCase());
  }

  /// Whether adapter can handle format.
  bool supportsFormat(String format) {
    return supportedFormats.contains(format.toLowerCase());
  }

  /// Creates a copy with modifications.
  PlayerAdapterCapabilities copyWith({
    bool? supportsLive,
    bool? supportsSeek,
    bool? supportsPause,
    bool? supportsRateControl,
    bool? supportsVolumeControl,
    bool? supportsHardwareDecoder,
    bool? supportsSoftwareDecoder,
    bool? supportsPictureInPicture,
    bool? supportsFullscreen,
    Set<String>? supportedProtocols,
    Set<String>? supportedFormats,
  }) {
    return PlayerAdapterCapabilities(
      supportsLive: supportsLive ?? this.supportsLive,
      supportsSeek: supportsSeek ?? this.supportsSeek,
      supportsPause: supportsPause ?? this.supportsPause,
      supportsRateControl: supportsRateControl ?? this.supportsRateControl,
      supportsVolumeControl: supportsVolumeControl ?? this.supportsVolumeControl,
      supportsHardwareDecoder: supportsHardwareDecoder ?? this.supportsHardwareDecoder,
      supportsSoftwareDecoder: supportsSoftwareDecoder ?? this.supportsSoftwareDecoder,
      supportsPictureInPicture: supportsPictureInPicture ?? this.supportsPictureInPicture,
      supportsFullscreen: supportsFullscreen ?? this.supportsFullscreen,
      supportedProtocols: supportedProtocols ?? this.supportedProtocols,
      supportedFormats: supportedFormats ?? this.supportedFormats,
    );
  }

  @override
  List<Object?> get props => [
    supportsLive,
    supportsSeek,
    supportsPause,
    supportsRateControl,
    supportsVolumeControl,
    supportsHardwareDecoder,
    supportsSoftwareDecoder,
    supportsPictureInPicture,
    supportsFullscreen,
    supportedProtocols,
    supportedFormats,
  ];
}
