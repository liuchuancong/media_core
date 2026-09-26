#include "media_core_native_plugin.h"

#include <flutter/plugin_registrar_windows.h>

#include "platform_probe.h"

namespace media_core_native {

namespace {

/// Method the probe is requested through; kept in sync with the Dart side.
constexpr char kProbeMethod[] = "probe";

/// Channel name; kept in sync with the Dart side.
constexpr char kChannelName[] = "media_core_native";

}  // namespace

void MediaCoreNativePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<MediaCoreNativePlugin>();

  plugin->channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), kChannelName, &flutter::StandardMethodCodec::GetInstance());

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

MediaCoreNativePlugin::MediaCoreNativePlugin() = default;

MediaCoreNativePlugin::~MediaCoreNativePlugin() = default;

void MediaCoreNativePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != kProbeMethod) {
    result->NotImplemented();
    return;
  }

  result->Success(flutter::EncodableValue(ProbePlatform()));
}

}  // namespace media_core_native
