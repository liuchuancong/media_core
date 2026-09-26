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
export 'src/media_kit_player_adapter.dart';
export 'src/media_kit_player_config.dart';
export 'src/media_kit_video_config.dart';
export 'src/media_kit_adapter_factory.dart';
export 'src/media_kit_video_view.dart';

// Public utils: settings UIs, diagnostics, tuning.
export 'src/utils/player_consts.dart' show PlayerConsts;
export 'src/utils/mpv_platform_profile.dart' show MpvPlatformProfile;
export 'src/utils/mpv_decode_policy.dart' show MpvDecodePolicy;
export 'src/utils/live_buffer_policy.dart' show LiveBufferPolicy;
export 'src/utils/flv_legacy_hevc_relay.dart' show FlvLegacyHevcRelay, FlvLegacyHevcTagRewriter, FlvTagFramer;
