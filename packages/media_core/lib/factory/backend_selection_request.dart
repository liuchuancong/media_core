import '../source/source_descriptor.dart';

/// Request used to select a playback backend.
///
/// A [BackendSelectionRequest] describes the
/// requirements and preferences for backend selection.
///
/// It is consumed by:
///
/// - BackendSelector
///
/// It does not:
///
/// - select backend
/// - create backend
///
/// Those belong to:
///
/// - BackendSelector
/// - BackendFactory
final class BackendSelectionRequest {
  /// Creates a backend selection request.
  const BackendSelectionRequest({
    required this.source,

    this.platform,

    this.requireLive = false,
    this.requireSeek = false,
    this.requireHardwareDecode = false,

    this.preferHardwareDecode = false,
    this.preferLowLatency = false,

    this.preferredBackend,
  });

  /// Source information.
  final SourceDescriptor source;

  /// Current platform.
  ///
  /// Example:
  ///
  /// android
  /// windows
  /// macos
  final String? platform;

  /// Whether live playback is required.
  final bool requireLive;

  /// Whether seeking is required.
  final bool requireSeek;

  /// Whether hardware decoding is mandatory.
  final bool requireHardwareDecode;

  /// Prefer hardware decoding.
  final bool preferHardwareDecode;

  /// Prefer low latency backend.
  ///
  /// Important for:
  ///
  /// - live streaming
  /// - interactive playback
  final bool preferLowLatency;

  /// Explicit backend preference.
  ///
  /// Example:
  ///
  /// media_kit
  /// vlc
  final String? preferredBackend;

  /// Whether request has explicit backend.
  bool get hasPreferredBackend {
    return preferredBackend != null && preferredBackend!.isNotEmpty;
  }

  /// Returns whether request requires
  /// advanced capability matching.
  bool get requiresCapabilityCheck {
    return requireLive || requireSeek || requireHardwareDecode;
  }

  @override
  String toString() {
    return 'BackendSelectionRequest('
        'source=${source.id}, '
        'platform=$platform, '
        'preferred=$preferredBackend'
        ')';
  }
}
