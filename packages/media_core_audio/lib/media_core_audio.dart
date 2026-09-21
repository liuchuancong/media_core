/// Background audio and audio session capability for media_core.
///
/// Bridges the media_core kernel to:
///
/// - `audio_service` — media notification, lock screen controls,
///   background playback (Android/iOS; Windows via audio_service_win)
/// - `audio_session` — audio focus, interruptions (calls, other apps),
///   becoming-noisy (headphones unplugged)
///
/// Attach to a kernel:
///
/// ```dart
/// final audio = MediaCoreAudio();
/// await audio.initialize();
/// kernel.attachAudio(audio);
/// ```
library;

export 'src/audio_capability_config.dart';
export 'src/media_core_audio.dart';
export 'src/media_core_audio_handler.dart';
