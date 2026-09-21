import 'package:media_core/media_core.dart';
import 'media_kit_player_adapter.dart';

/// [PlayerAdapterFactory] that creates [MediaKitPlayerAdapter] instances.
final class MediaKitAdapterFactory implements PlayerAdapterFactory {
  /// Creates the factory.
  const MediaKitAdapterFactory();

  /// Registration entry for `PlayerKernel.registerBackend`.
  static PlayerAdapterRegistration defaultRegistration({int priority = 100}) {
    return PlayerAdapterRegistration(
      id: 'media_kit',
      factory: const MediaKitAdapterFactory(),
      capabilities: MediaKitPlayerAdapter.defaultCapabilities,
      priority: priority,
    );
  }

  @override
  PlayerAdapter create(String id) => MediaKitPlayerAdapter(id: id);

  @override
  bool supports(String id) => id == 'media_kit' || id.isEmpty;
}

/// Registers the media_kit adapter in a [DefaultPlayerAdapterFactory].
///
/// After registration, `factory.create('media_kit')` returns a
/// [MediaKitPlayerAdapter].
void registerMediaKitFactory(DefaultPlayerAdapterFactory factory) {
  factory.register('media_kit', MediaKitPlayerAdapter.new);
}

/// Registers the media_kit adapter in a [PlayerAdapterRegistry].
///
/// The adapter is added with [priority] (higher = preferred) and
/// can be selected by a [PlayerAdapterSelector] at runtime.
void registerMediaKitRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 100,
}) {
  registry.register(
    PlayerAdapterRegistration(
      id: 'media_kit',
      factory: const MediaKitAdapterFactory(),
      capabilities: MediaKitPlayerAdapter.defaultCapabilities,
      priority: priority,
    ),
  );
}
