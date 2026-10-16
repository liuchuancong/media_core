//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_service
import audio_session
import ffmpeg_kit_extended_flutter
import media_core_audio
import media_core_native
import media_kit_video
import package_info_plus
import screen_retriever_macos
import sqflite_darwin
import wakelock_plus
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioServicePlugin.register(with: registry.registrar(forPlugin: "AudioServicePlugin"))
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  FfmpegKitExtendedFlutterPlugin.register(with: registry.registrar(forPlugin: "FfmpegKitExtendedFlutterPlugin"))
  MediaCoreAudioPlugin.register(with: registry.registrar(forPlugin: "MediaCoreAudioPlugin"))
  MediaCoreNativePlugin.register(with: registry.registrar(forPlugin: "MediaCoreNativePlugin"))
  MediaKitVideoPlugin.register(with: registry.registrar(forPlugin: "MediaKitVideoPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  WakelockPlusMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
