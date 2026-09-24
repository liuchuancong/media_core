import 'bette_player_adapter.dart';
import 'package:media_core/media_core.dart';
export 'better_player_config.dart' show BetterPlayerConfig, BetterPlayerDataSourceBuilder;

const String kBetterPlayerBackendId = 'better_player';

/// [PlayerAdapterFactory] that creates [BetterPlayerAdapter] instances.
final class BetterPlayerAdapterFactory implements PlayerAdapterFactory {
  /// [capabilities] and [config] are shared by every adapter this
  /// factory creates. [configure] runs once per instance after
  /// construction for per-instance customisation.
  const BetterPlayerAdapterFactory({
    this.capabilities = BetterPlayerAdapter.defaultCapabilities,
    this.config = const BetterPlayerConfig(),
    this.configure,
  });

  final PlayerAdapterCapabilities capabilities;
  final BetterPlayerConfig config;
  final void Function(BetterPlayerAdapter adapter)? configure;

  @override
  PlayerAdapter create(String id) {
    final adapter = BetterPlayerAdapter(id: id, capabilities: capabilities, playerConfig: config);
    configure?.call(adapter);
    return adapter;
  }

  @override
  bool supports(String id) => id == kBetterPlayerBackendId;

  /// Builds a registration entry for `PlayerKernel.registerBackend` or
  /// a [PlayerAdapterRegistry]. That path carries [capabilities] on the
  /// registration entry itself, so capability-based selection works
  /// before an adapter is ever instantiated.
  PlayerAdapterRegistration registration({int priority = 80}) {
    return PlayerAdapterRegistration(
      id: kBetterPlayerBackendId,
      factory: this,
      capabilities: capabilities,
      priority: priority,
    );
  }
}

/// Registers the better_player adapter in a [DefaultPlayerAdapterFactory].
void registerBetterPlayerFactory(
  DefaultPlayerAdapterFactory factory, {
  String id = kBetterPlayerBackendId,
  PlayerAdapterCapabilities capabilities = BetterPlayerAdapter.defaultCapabilities,
  BetterPlayerConfig config = const BetterPlayerConfig(),
  void Function(BetterPlayerAdapter adapter)? configure,
}) {
  factory.register(id, () {
    final adapter = BetterPlayerAdapter(id: id, capabilities: capabilities, playerConfig: config);
    configure?.call(adapter);
    return adapter;
  });
}

/// Registers the better_player adapter in a [PlayerAdapterRegistry].
void registerBetterPlayerRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 80,
  PlayerAdapterCapabilities capabilities = BetterPlayerAdapter.defaultCapabilities,
  BetterPlayerConfig config = const BetterPlayerConfig(),
  void Function(BetterPlayerAdapter adapter)? configure,
}) {
  registry.register(
    BetterPlayerAdapterFactory(
      capabilities: capabilities,
      config: config,
      configure: configure,
    ).registration(priority: priority),
  );
}
