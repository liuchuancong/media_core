/// mpv_audio_kit backend adapter for media_core.
///
/// Audio-only: the engine beneath is the patched-libmpv audio player.
/// Alongside the shared PlayerAdapter contract, the adapter exposes the
/// engine itself (`adapter.player`) for the taps, effects and media
/// session that have no adapter-vocabulary equivalent.
library;

// The engine this adapter is built on, re-exported so a host reaches it
// from its single dependency on this adapter.
export 'package:media_core_mpv_audio/src/mpv_audio_adapter.dart';
export 'package:media_core_mpv_audio/src/mpv_audio_adapter_factory.dart';
export 'package:mpv_audio_kit/mpv_audio_kit.dart';
