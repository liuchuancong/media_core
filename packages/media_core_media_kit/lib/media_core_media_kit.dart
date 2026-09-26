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

// Adapter, configs, factory, view.
export 'package:media_core_media_kit/src/media_kit_player_adapter.dart';
export 'package:media_core_media_kit/src/media_kit_player_config.dart';
export 'package:media_core_media_kit/src/media_kit_video_config.dart';
export 'package:media_core_media_kit/src/media_kit_adapter_factory.dart';
export 'package:media_core_media_kit/src/media_kit_video_view.dart';

// Public utils: settings UIs, diagnostics, tuning.
export 'package:media_core_media_kit/src/utils/player_consts.dart' show PlayerConsts;
export 'package:media_core_media_kit/src/utils/mpv_platform_profile.dart' show MpvPlatformProfile;
export 'package:media_core_media_kit/src/utils/mpv_decode_policy.dart' show MpvDecodePolicy;
export 'package:media_core_media_kit/src/utils/live_buffer_policy.dart' show LiveBufferPolicy;
