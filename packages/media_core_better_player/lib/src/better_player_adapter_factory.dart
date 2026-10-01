import 'package:media_core_better_player/src/better_player_adapter.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:media_core/media_core.dart';

const String kBetterPlayerBackendId = 'better_player';

/// [PlayerAdapterFactory] that creates [BetterPlayerAdapter] instances.
final class BetterPlayerAdapterFactory implements PlayerAdapterFactory {
  /// [capabilities] and the native configuration fields are shared by
  /// every adapter this factory creates. [configure] runs once per
  /// instance after construction for per-instance customisation.
  const BetterPlayerAdapterFactory({
    this.capabilities = BetterPlayerAdapter.defaultCapabilities,
    this.configuration,
    this.playlistConfiguration,
    this.dataSource,
    this.configureDataSource,
    this.configure,
  });

  final PlayerAdapterCapabilities capabilities;
  final BetterPlayerConfiguration? configuration;
  final BetterPlayerPlaylistConfiguration? playlistConfiguration;
  final BetterPlayerDataSource? dataSource;
  final BetterPlayerDataSourceBuilder? configureDataSource;
  final void Function(BetterPlayerAdapter adapter)? configure;

  @override
  PlayerAdapter create(String id) {
    final adapter = BetterPlayerAdapter(
      id: id,
      capabilities: capabilities,
      configuration: configuration,
      playlistConfiguration: playlistConfiguration,
      dataSource: dataSource,
      configureDataSource: configureDataSource,
    );
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
  BetterPlayerConfiguration? configuration,
    BetterPlayerPlaylistConfiguration? playlistConfiguration,
    BetterPlayerDataSource? dataSource,
    BetterPlayerDataSourceBuilder? configureDataSource,
  void Function(BetterPlayerAdapter adapter)? configure,
}) {
  factory.register(id, () {
    final adapter = BetterPlayerAdapter(
        id: id,
        capabilities: capabilities,
        configuration: configuration,
        playlistConfiguration: playlistConfiguration,
        dataSource: dataSource,
        configureDataSource: configureDataSource,
      );
    configure?.call(adapter);
    return adapter;
  });
}

/// Registers the better_player adapter in a [PlayerAdapterRegistry].
void registerBetterPlayerRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 80,
  PlayerAdapterCapabilities capabilities = BetterPlayerAdapter.defaultCapabilities,
  BetterPlayerConfiguration? configuration,
    BetterPlayerPlaylistConfiguration? playlistConfiguration,
    BetterPlayerDataSource? dataSource,
    BetterPlayerDataSourceBuilder? configureDataSource,
  void Function(BetterPlayerAdapter adapter)? configure,
}) {
  registry.register(
    BetterPlayerAdapterFactory(
      capabilities: capabilities,
      configuration: configuration,
      playlistConfiguration: playlistConfiguration,
      dataSource: dataSource,
      configureDataSource: configureDataSource,
      configure: configure,
    ).registration(priority: priority),
  );
}
