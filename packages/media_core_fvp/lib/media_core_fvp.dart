/// fvp (libmdk) backend adapter for media_core.
///
/// fvp ships libmdk, a current FFmpeg build with platform hardware decoders
/// first and FFmpeg/dav1d as software fallbacks. It reads streams the older
/// bundled engines drop, so an app registers it as the engine to recover a
/// source that only plays audio elsewhere.
///
/// ```dart
/// final registry = PlayerAdapterRegistry();
/// registerFvpRegistry(registry);
/// ```
///
/// The adapter owns its Flutter `Texture`; render it with [FvpVideoView] or
/// drive it from `FvpPlayerAdapter.textureListenable`.
library;

// Adapter, configs, factory, view.
export 'src/fvp_player_adapter.dart' show FvpPlayerAdapter;
export 'src/fvp_player_config.dart' show FvpPlayerConfig, FvpProxyUrlResolver;
export 'src/fvp_video_config.dart' show FvpVideoConfig;
export 'src/fvp_video_view.dart' show FvpVideoView;
export 'src/fvp_adapter_factory.dart'
    show FvpAdapterFactory, kFvpPlayerBackendId, registerFvpFactory, registerFvpRegistry;
