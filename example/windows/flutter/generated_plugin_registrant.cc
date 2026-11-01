//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h>
#include <flutter_media_session/flutter_media_session_plugin_c_api.h>
#include <media_core_audio/media_core_audio_plugin_c_api.h>
#include <media_core_native/media_core_native_plugin_c_api.h>
#include <media_kit_video/media_kit_video_plugin_c_api.h>
#include <mpv_audio_kit/mpv_audio_kit_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FfmpegKitExtendedFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FfmpegKitExtendedFlutterPlugin"));
  FlutterMediaSessionPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterMediaSessionPluginCApi"));
  MediaCoreAudioPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaCoreAudioPluginCApi"));
  MediaCoreNativePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaCoreNativePluginCApi"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  MpvAudioKitPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MpvAudioKitPluginCApi"));
}
