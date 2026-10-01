import 'package:media_core_media_kit/src/media_kit_player_adapter.dart';
import 'package:media_core/media_core.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

const String kMediaKitPlayerBackendId = 'mpv';

/// [PlayerAdapterFactory] that creates [MediaKitPlayerAdapter] instances.
///
/// [playerConfiguration] and [videoControllerConfiguration] are media_kit's
/// own configuration types, shared verbatim by every adapter this factory
/// creates. [configure] runs once per instance after construction for
/// per-instance customisation.
final class MediaKitAdapterFactory implements PlayerAdapterFactory {
  /// Creates a factory.
  const MediaKitAdapterFactory({
    this.capabilities = MediaKitPlayerAdapter.defaultCapabilities,
    this.playerConfiguration,
    this.videoControllerConfiguration,
    this.configure,
  });

  final PlayerAdapterCapabilities capabilities;

  /// Native media_kit player configuration; null uses engine defaults.
  final mk.PlayerConfiguration? playerConfiguration;

  /// Native media_kit_video controller configuration; null uses engine
  /// defaults.
  final mkv.VideoControllerConfiguration? videoControllerConfiguration;

  final void Function(MediaKitPlayerAdapter adapter)? configure;

  @override
  PlayerAdapter create(String id) {
    final adapter = MediaKitPlayerAdapter(
      id: id,
      capabilities: capabilities,
      playerConfiguration: playerConfiguration,
      videoControllerConfiguration: videoControllerConfiguration,
    );

    configure?.call(adapter);

    return adapter;
  }

  @override
  bool supports(String id) => id == kMediaKitPlayerBackendId;

  /// Builds a registration entry for `PlayerKernel.registerBackend` or
  /// a [PlayerAdapterRegistry]. That path carries [capabilities] on the
  /// registration entry itself, so capability-based selection works
  /// before an adapter is ever instantiated.
  PlayerAdapterRegistration registration({int priority = 100}) {
    return PlayerAdapterRegistration(
      id: kMediaKitPlayerBackendId,
      factory: this,
      capabilities: capabilities,
      priority: priority,
    );
  }
}

/// Registers the media_kit adapter in a [DefaultPlayerAdapterFactory].
void registerMediaKitFactory(
  DefaultPlayerAdapterFactory factory, {
  String id = kMediaKitPlayerBackendId,
  PlayerAdapterCapabilities capabilities = MediaKitPlayerAdapter.defaultCapabilities,
  mk.PlayerConfiguration? playerConfiguration,
  mkv.VideoControllerConfiguration? videoControllerConfiguration,
  void Function(MediaKitPlayerAdapter adapter)? configure,
}) {
  factory.register(id, () {
    final adapter = MediaKitPlayerAdapter(
      id: id,
      capabilities: capabilities,
      playerConfiguration: playerConfiguration,
      videoControllerConfiguration: videoControllerConfiguration,
    );

    configure?.call(adapter);

    return adapter;
  });
}

/// Registers the media_kit adapter in a [PlayerAdapterRegistry].
void registerMediaKitRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 100,
  PlayerAdapterCapabilities capabilities = MediaKitPlayerAdapter.defaultCapabilities,
  mk.PlayerConfiguration? playerConfiguration,
  mkv.VideoControllerConfiguration? videoControllerConfiguration,
  void Function(MediaKitPlayerAdapter adapter)? configure,
}) {
  registry.register(
    MediaKitAdapterFactory(
      capabilities: capabilities,
      playerConfiguration: playerConfiguration,
      videoControllerConfiguration: videoControllerConfiguration,
      configure: configure,
    ).registration(priority: priority),
  );
}
