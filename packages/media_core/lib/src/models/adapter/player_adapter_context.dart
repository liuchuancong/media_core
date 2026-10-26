import 'package:built_value/built_value.dart';
import 'package:media_core/src/core/config/player_config.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/models/adapter/player_adapter_config.dart';
import 'package:media_core/src/platform/capability/platform_capabilities.dart';
import 'package:media_core/src/platform/capability/platform_codec_capabilities.dart';
import 'package:media_core/src/platform/capability/platform_device_profile.dart';

part 'player_adapter_context.g.dart';

/// Configuration context passed to a player adapter.
///
/// [PlayerAdapterContext] bundles the identity, session,
/// configuration, and options required by a backend adapter.
///
/// Responsibilities:
///
/// - identify the player
/// - identify the session
/// - carry adapter configuration
/// - carry backend options
/// - describe platform capabilities and device facts
///
/// It does not:
///
/// - create a player
/// - manage playback state
/// - select backend
///
/// Those belong to:
///
/// - PlayerAdapterState
/// - PlayerAdapterFactory
abstract class PlayerAdapterContext implements Built<PlayerAdapterContext, PlayerAdapterContextBuilder> {
  /// Builds PlayerAdapterContext from a [updates] callback — the codegen entry.
  factory PlayerAdapterContext([void Function(PlayerAdapterContextBuilder)? updates]) = _$PlayerAdapterContext;

  /// Creates adapter context.
  ///
  /// A null [config] means the default adapter configuration, which is what
  /// the field's `@Default` used to stand for; a built value cannot be a
  /// default parameter value, so the omission is carried instead.
  factory PlayerAdapterContext.of({
    required PlayerId playerId,
    required SessionId sessionId,
    PlayerAdapterConfig? config,
    PlayerConfig? playerConfig,
    Map<String, Object?> options = const <String, Object?>{},
    PlatformCapabilities platform = const PlatformCapabilities(),
    PlatformDeviceProfile device = PlatformDeviceProfile.unknown,
    PlatformCodecCapabilities codecs = PlatformCodecCapabilities.unknown,
    bool debug = false,
  }) {
    return PlayerAdapterContext((builder) {
      builder
        ..playerId = playerId
        ..sessionId = sessionId
        ..playerConfig = playerConfig
        ..options = options
        ..platform = platform
        ..device = device
        ..codecs = codecs
        ..debug = debug;

      if (config != null) {
        builder.config = config.toBuilder();
      }
    });
  }

  /// Creates minimal context.
  factory PlayerAdapterContext.basic({required PlayerId playerId, required SessionId sessionId}) {
    return PlayerAdapterContext.of(playerId: playerId, sessionId: sessionId);
  }

  PlayerAdapterContext._();

  /// A context nobody configured runs the default adapter configuration with
  /// unreported platform capabilities, an unknown device and unknown codec
  /// profile, no backend options, and debug off.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerAdapterContextBuilder builder) => builder
    ..config = PlayerAdapterConfig().toBuilder()
    ..options = const <String, Object?>{}
    ..platform = const PlatformCapabilities()
    ..device = PlatformDeviceProfile.unknown
    ..codecs = PlatformCodecCapabilities.unknown
    ..debug = false;

  /// PlayerIdentity identifier.
  PlayerId get playerId;

  /// Playback session identifier.
  SessionId get sessionId;

  /// Adapter configuration.
  PlayerAdapterConfig get config;

  /// PlayerIdentity configuration.
  PlayerConfig? get playerConfig;

  /// Backend specific options.
  Map<String, Object?> get options;

  /// Capabilities reported by the running device.
  ///
  /// Filled from the platform probe the kernel was given; the defaults are
  /// what a host that attached no provider gets, and they report themselves
  /// as [PlatformCapabilities.reported] `false` so a backend can tell.
  PlatformCapabilities get platform;

  /// Device facts of the running device (cores, memory, ABI width).
  PlatformDeviceProfile get device;

  /// What the device can decode, and in hardware or not.
  PlatformCodecCapabilities get codecs;

  /// Debug mode.
  bool get debug;
}

/// Extensions for adapter context.
extension PlayerAdapterContextExtension on PlayerAdapterContext {
  /// Whether custom options exist.
  bool get hasOptions {
    return options.isNotEmpty;
  }

  /// Gets backend option.
  T? option<T>(String key) {
    final value = options[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  /// Creates context with option.
  PlayerAdapterContext putOption(String key, Object? value) {
    return rebuild((builder) => builder..options = <String, Object?>{...options, key: value});
  }
}
