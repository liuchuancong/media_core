#include "include/media_core_audio/media_core_audio_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "media_core_audio_plugin.h"

void MediaCoreAudioPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  media_core_audio::MediaCoreAudioPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
