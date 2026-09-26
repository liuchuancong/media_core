import 'package:media_core/media_core.dart';

import 'fvp_player_adapter.dart';
import 'fvp_player_config.dart';
import 'fvp_video_config.dart';

export 'fvp_player_config.dart' show FvpPlayerConfig, FvpProxyUrlResolver;
export 'fvp_video_config.dart' show FvpVideoConfig;

/// Backend id the fvp (libmdk) adapter registers under.
const String kFvpPlayerBackendId = 'fvp';

/// [PlayerAdapterFactory] that creates [FvpPlayerAdapter] instances.
final class FvpAdapterFactory implements PlayerAdapterFactory {
  /// [capabilities], [config] and [videoConfig] are shared by every adapter this
  /// factory creates. [configure] runs once per instance after construction for
  /// per-instance customisation.
  const FvpAdapterFactory({
    this.capabilities = FvpPlayerAdapter.defaultCapabilities,
    this.config = const FvpPlayerConfig(),
    this.videoConfig = const FvpVideoConfig(),
    this.configure,
  });

  final PlayerAdapterCapabilities capabilities;
  final FvpPlayerConfig config;
  final FvpVideoConfig videoConfig;
  final void Function(FvpPlayerAdapter adapter)? configure;

  @override
  PlayerAdapter create(String id) {
    final adapter = FvpPlayerAdapter(id: id, capabilities: capabilities, config: config, videoConfig: videoConfig);

    configure?.call(adapter);

    return adapter;
  }

  @override
  bool supports(String id) => id == kFvpPlayerBackendId;

  /// Builds a registration entry for `PlayerKernel.registerBackend` or a
  /// [PlayerAdapterRegistry]. That path carries [capabilities] on the
  /// registration entry itself, so capability-based selection works before an
  /// adapter is ever instantiated.
  PlayerAdapterRegistration registration({int priority = 80}) {
    return PlayerAdapterRegistration(
      id: kFvpPlayerBackendId,
      factory: this,
      capabilities: capabilities,
      priority: priority,
    );
  }
}

/// Registers the fvp adapter in a [DefaultPlayerAdapterFactory].
void registerFvpFactory(
  DefaultPlayerAdapterFactory factory, {
  String id = kFvpPlayerBackendId,
  PlayerAdapterCapabilities capabilities = FvpPlayerAdapter.defaultCapabilities,
  FvpPlayerConfig config = const FvpPlayerConfig(),
  FvpVideoConfig videoConfig = const FvpVideoConfig(),
  void Function(FvpPlayerAdapter adapter)? configure,
}) {
  factory.register(id, () {
    final adapter = FvpPlayerAdapter(id: id, capabilities: capabilities, config: config, videoConfig: videoConfig);

    configure?.call(adapter);

    return adapter;
  });
}

/// Registers the fvp adapter in a [PlayerAdapterRegistry].
void registerFvpRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 80,
  PlayerAdapterCapabilities capabilities = FvpPlayerAdapter.defaultCapabilities,
  FvpPlayerConfig config = const FvpPlayerConfig(),
  FvpVideoConfig videoConfig = const FvpVideoConfig(),
  void Function(FvpPlayerAdapter adapter)? configure,
}) {
  registry.register(
    FvpAdapterFactory(
      capabilities: capabilities,
      config: config,
      videoConfig: videoConfig,
      configure: configure,
    ).registration(priority: priority),
  );
}
