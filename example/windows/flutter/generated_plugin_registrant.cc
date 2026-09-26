//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audio_service_win/audio_service_win_plugin_c_api.h>
#include <ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h>
#include <media_core_audio/media_core_audio_plugin_c_api.h>
#include <media_core_native/media_core_native_plugin.h>
#include <media_kit_video/media_kit_video_plugin_c_api.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioServiceWinPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioServiceWinPluginCApi"));
  FfmpegKitExtendedFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FfmpegKitExtendedFlutterPlugin"));
  MediaCoreAudioPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaCoreAudioPluginCApi"));
  MediaCoreNativePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaCoreNativePlugin"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}
