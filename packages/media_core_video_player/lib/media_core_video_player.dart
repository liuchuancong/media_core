/// video_player backend adapter for media_core.
///
/// Supports network (HTTP/HTTPS/HLS), file and asset sources.
/// Desktop support requires the appropriate `video_player_*`
/// platform package in your app-level pubspec.
library;

export 'src/video_player_adapter.dart';
export 'src/video_player_adapter_factory.dart';
export 'src/video_player_surface.dart';
