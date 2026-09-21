import 'package:media_core/media_core.dart';
import 'video_player_adapter.dart';

/// [PlayerAdapterFactory] that creates [VideoPlayerAdapter] instances.
final class VideoPlayerAdapterFactory implements PlayerAdapterFactory {
  /// Creates the factory.
  const VideoPlayerAdapterFactory();

  /// Registration entry for `PlayerKernel.registerBackend`.
  static PlayerAdapterRegistration defaultRegistration({int priority = 80}) {
    return PlayerAdapterRegistration(
      id: 'video_player',
      factory: const VideoPlayerAdapterFactory(),
      capabilities: VideoPlayerAdapter.defaultCapabilities,
      priority: priority,
    );
  }

  @override
  PlayerAdapter create(String id) => VideoPlayerAdapter(id: id);

  @override
  bool supports(String id) => id == 'video_player' || id.isEmpty;
}

/// Registers the video_player adapter in a [DefaultPlayerAdapterFactory].
void registerVideoPlayerFactory(DefaultPlayerAdapterFactory factory) {
  factory.register('video_player', VideoPlayerAdapter.new);
}

/// Registers the video_player adapter in a [PlayerAdapterRegistry].
void registerVideoPlayerRegistry(
  PlayerAdapterRegistry registry, {
  int priority = 80,
}) {
  registry.register(
    PlayerAdapterRegistration(
      id: 'video_player',
      factory: const VideoPlayerAdapterFactory(),
      capabilities: VideoPlayerAdapter.defaultCapabilities,
      priority: priority,
    ),
  );
}
