import 'package:built_value/built_value.dart';

part 'player_adapter_config.g.dart';

/// Configuration for a player adapter.
///
/// [PlayerAdapterConfig] contains backend-independent
/// initialization options.
///
/// Different adapters may map these values to their
/// native backend options.
///
/// Responsibilities:
///
/// - describe adapter configuration
/// - provide playback preferences
///
/// It does not:
///
/// - store runtime state
/// - select backend
/// - manage lifecycle
///
/// Those belong to:
///
/// - PlayerAdapterState
/// - BackendSelector
/// - PlayerAdapterFactory
abstract class PlayerAdapterConfig implements Built<PlayerAdapterConfig, PlayerAdapterConfigBuilder> {
  /// Builds PlayerAdapterConfig from a [updates] callback — the codegen entry.
  factory PlayerAdapterConfig([void Function(PlayerAdapterConfigBuilder)? updates]) = _$PlayerAdapterConfig;

  /// Creates adapter configuration.
  factory PlayerAdapterConfig.of({
    bool hardwareAcceleration = true,
    bool audioEnabled = true,
    double volume = 1.0,
    double playbackRate = 1.0,
    Duration networkTimeout = const Duration(seconds: 15),
    Duration bufferDuration = const Duration(seconds: 5),
    int? maxBufferBytes,
    String? preferredDecoder,
    Map<String, Object?> options = const <String, Object?>{},
  }) {
    return PlayerAdapterConfig(
      (builder) => builder
        ..hardwareAcceleration = hardwareAcceleration
        ..audioEnabled = audioEnabled
        ..volume = volume
        ..playbackRate = playbackRate
        ..networkTimeout = networkTimeout
        ..bufferDuration = bufferDuration
        ..maxBufferBytes = maxBufferBytes
        ..preferredDecoder = preferredDecoder
        ..options = options,
    );
  }

  /// Creates default configuration.
  factory PlayerAdapterConfig.defaults() {
    return PlayerAdapterConfig.of();
  }

  PlayerAdapterConfig._();

  /// A backend decodes in hardware, plays audio, starts at unit volume and
  /// rate, and buffers five seconds inside a fifteen-second network timeout
  /// unless the host narrows any of that.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerAdapterConfigBuilder builder) => builder
    ..hardwareAcceleration = true
    ..audioEnabled = true
    ..volume = 1.0
    ..playbackRate = 1.0
    ..networkTimeout = const Duration(seconds: 15)
    ..bufferDuration = const Duration(seconds: 5)
    ..options = const <String, Object?>{};

  /// Enable hardware decoding.
  bool get hardwareAcceleration;

  /// Enable audio output.
  bool get audioEnabled;

  /// Initial volume.
  double get volume;

  /// Initial playback rate.
  double get playbackRate;

  /// Network timeout.
  Duration get networkTimeout;

  /// Buffer duration target.
  Duration get bufferDuration;

  /// Maximum buffer size in bytes.
  ///
  /// Null means backend default.
  int? get maxBufferBytes;

  /// Preferred decoder name.
  ///
  /// Example:
  /// - h264
  /// - hevc
  String? get preferredDecoder;

  /// Backend-specific options.
  Map<String, Object?> get options;
}

/// Extensions for [PlayerAdapterConfig].
extension PlayerAdapterConfigExtension on PlayerAdapterConfig {
  /// Whether volume value is valid.
  bool get hasValidVolume {
    return volume >= 0 && volume <= 1;
  }

  /// Whether playback rate is valid.
  bool get hasValidRate {
    return playbackRate > 0;
  }

  /// Whether configuration is valid.
  bool get isValid {
    return hasValidVolume && hasValidRate && !networkTimeout.isNegative && !bufferDuration.isNegative;
  }
}
