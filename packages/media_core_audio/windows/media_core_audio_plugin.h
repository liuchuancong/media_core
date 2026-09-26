#ifndef MEDIA_CORE_AUDIO_PLUGIN_H_
#define MEDIA_CORE_AUDIO_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "desktop_lyric_window.h"

namespace media_core_audio {

/// Windows side of `media_core_audio`'s desktop-lyric overlay.
///
/// Wire protocol (see `MethodChannelDesktopLyricTransport` on the Dart side,
/// which is the source of truth):
///
/// | direction | method | arguments | result |
/// |---|---|---|---|
/// | Dart → host | `isSupported` | – | true |
/// | Dart → host | `show` | – | window shown |
/// | Dart → host | `hide` | – | – |
/// | Dart → host | `update` | state map | – |
/// | Dart → host | `setBounds` | {x, y, width, height} | – |
/// | host → Dart | `action` | {action: previous/toggle/next/close/lock/unlock} | – |
///
/// The overlay lives on its own thread, so its button presses cannot call into
/// Flutter directly. They are queued and reposted to a message-only window that
/// the plugin creates on the platform thread, and only that window's procedure
/// touches the method channel — which is what keeps the "platform thread only"
/// rule of the Flutter embedder intact.
class MediaCoreAudioPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit MediaCoreAudioPlugin(flutter::PluginRegistrarWindows* registrar);
  ~MediaCoreAudioPlugin() override;

  MediaCoreAudioPlugin(const MediaCoreAudioPlugin&) = delete;
  MediaCoreAudioPlugin& operator=(const MediaCoreAudioPlugin&) = delete;

  /// Window procedure entry point; public because the window class is
  /// registered from a file-local helper.
  static LRESULT CALLBACK ActionWindowProcThunk(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam);

 private:
  static constexpr UINT kMessageDrainActions = WM_APP + 301;

  LRESULT ActionWindowProc(UINT message, WPARAM wparam, LPARAM lparam);

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Queues an action from the overlay thread and wakes the platform thread.
  void QueueAction(const std::string& action);

  /// Sends queued actions to Dart; only ever runs on the platform thread.
  void DrainActions();

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<DesktopLyricWindow> window_;

  HWND action_window_ = nullptr;
  std::mutex actions_mutex_;
  std::vector<std::string> pending_actions_;
};

}  // namespace media_core_audio

#endif  // MEDIA_CORE_AUDIO_PLUGIN_H_
