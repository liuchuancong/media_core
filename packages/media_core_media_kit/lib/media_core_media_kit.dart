/// media_kit backend adapter for media_core.
///
/// Before using this adapter, call [MediaKitPlayerAdapter.ensureInitialized]
/// (typically in `main`) to load the native media_kit libraries.
///
/// ```dart
/// void main() {
///   MediaKitPlayerAdapter.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// Add the appropriate `media_kit_libs_*_video` package to your
/// app-level pubspec so the native libraries are bundled.
library;

export 'src/media_kit_player_adapter.dart';
export 'src/media_kit_adapter_factory.dart';
export 'src/media_kit_video_view.dart';
