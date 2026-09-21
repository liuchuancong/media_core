import 'package:media_core/media_core.dart';
import 'ijk_player_adapter.dart';

/// [PlayerAdapterFactory] that creates [IjkPlayerAdapter] instances.
final class IjkPlayerAdapterFactory implements PlayerAdapterFactory {
  /// Creates the factory.
  const IjkPlayerAdapterFactory();

  /// Registration entry for `PlayerKernel.registerBackend`.
  static PlayerAdapterRegistration defaultRegistration({int priority = 90}) {
    return PlayerAdapterRegistration(
      id: 'ijk',
      factory: const IjkPlayerAdapterFactory(),
      capabilities: IjkPlayerAdapter.defaultCapabilities,
      priority: priority,
    );
  }

  @override
  PlayerAdapter create(String id) => IjkPlayerAdapter(id: id);

  @override
  bool supports(String id) => id == 'ijk' || id.isEmpty;
}

/// Registers the ijkplayer adapter in a [DefaultPlayerAdapterFactory].
///
/// After registration, `factory.create('ijk')` returns an
/// [IjkPlayerAdapter].
void registerIjkFactory(DefaultPlayerAdapterFactory factory) {
  factory.register('ijk', IjkPlayerAdapter.new);
}

/// Registers the ijkplayer adapter in a [PlayerAdapterRegistry].
///
/// The adapter is added with [priority] (higher = preferred) and
/// can be selected by a [PlayerAdapterSelector] at runtime.
void registerIjkRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 90,
}) {
  registry.register(
    PlayerAdapterRegistration(
      id: 'ijk',
      factory: const IjkPlayerAdapterFactory(),
      capabilities: IjkPlayerAdapter.defaultCapabilities,
      priority: priority,
    ),
  );
}
