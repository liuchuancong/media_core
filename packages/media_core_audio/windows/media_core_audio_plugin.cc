#include "media_core_audio_plugin.h"

#include <algorithm>
#include <cmath>

namespace media_core_audio {
namespace {

constexpr wchar_t kActionWindowClassName[] = L"MediaCoreAudioActionWindow";
constexpr char kChannelName[] = "media_core_audio/desktop_lyric";

/// Reads a string member out of an encoded map.
std::string StringAt(const flutter::EncodableMap& map, const char* key) {
  const auto iterator = map.find(flutter::EncodableValue(key));

  if (iterator == map.end()) {
    return std::string();
  }

  if (const auto* value = std::get_if<std::string>(&iterator->second)) {
    return *value;
  }

  return std::string();
}

bool BoolAt(const flutter::EncodableMap& map, const char* key,
            bool fallback) {
  const auto iterator = map.find(flutter::EncodableValue(key));

  if (iterator == map.end()) {
    return fallback;
  }

  if (const auto* value = std::get_if<bool>(&iterator->second)) {
    return *value;
  }

  return fallback;
}

double NumberAt(const flutter::EncodableMap& map, const char* key,
                double fallback) {
  const auto iterator = map.find(flutter::EncodableValue(key));

  if (iterator == map.end()) {
    return fallback;
  }

  if (const auto* value = std::get_if<double>(&iterator->second)) {
    return *value;
  }

  if (const auto* value = std::get_if<int32_t>(&iterator->second)) {
    return static_cast<double>(*value);
  }

  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<double>(*value);
  }

  return fallback;
}

std::wstring WideFromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size = ::MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0);

  if (size <= 0) {
    return std::wstring();
  }

  std::wstring result(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                        static_cast<int>(value.size()), result.data(), size);

  return result;
}

ATOM EnsureActionWindowClass() {
  static ATOM atom = 0;

  if (atom != 0) {
    return atom;
  }

  WNDCLASS window_class{};
  window_class.lpfnWndProc = MediaCoreAudioPlugin::ActionWindowProcThunk;
  window_class.hInstance = ::GetModuleHandle(nullptr);
  window_class.lpszClassName = kActionWindowClassName;

  atom = ::RegisterClass(&window_class);

  return atom;
}

}  // namespace

void MediaCoreAudioPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<MediaCoreAudioPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

MediaCoreAudioPlugin::MediaCoreAudioPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  // Message-only window used to hop from the overlay thread onto the platform
  // thread; it is never shown and exists purely for its message queue.
  EnsureActionWindowClass();

  action_window_ = ::CreateWindowEx(
      0, kActionWindowClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
      ::GetModuleHandle(nullptr), this);

  window_ = std::make_unique<DesktopLyricWindow>(
      [this](const std::string& action) { QueueAction(action); });
}

MediaCoreAudioPlugin::~MediaCoreAudioPlugin() {
  if (window_) {
    window_->Hide();
    window_.reset();
  }

  if (action_window_) {
    ::DestroyWindow(action_window_);
    action_window_ = nullptr;
  }

  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
}

LRESULT CALLBACK MediaCoreAudioPlugin::ActionWindowProcThunk(HWND hwnd,
                                                             UINT message,
                                                             WPARAM wparam,
                                                             LPARAM lparam) {
  MediaCoreAudioPlugin* self = nullptr;

  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
    self = static_cast<MediaCoreAudioPlugin*>(create->lpCreateParams);
    ::SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<MediaCoreAudioPlugin*>(
        ::GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  if (!self) {
    return ::DefWindowProc(hwnd, message, wparam, lparam);
  }

  return self->ActionWindowProc(message, wparam, lparam);
}

LRESULT MediaCoreAudioPlugin::ActionWindowProc(UINT message, WPARAM wparam,
                                               LPARAM lparam) {
  if (message == kMessageDrainActions) {
    DrainActions();

    return 0;
  }

  return ::DefWindowProc(action_window_, message, wparam, lparam);
}

void MediaCoreAudioPlugin::QueueAction(const std::string& action) {
  const HWND target = action_window_;

  if (!target) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(actions_mutex_);
    pending_actions_.push_back(action);
  }

  // PostMessage is the thread hop: the window procedure runs on the platform
  // thread, which is the only thread allowed to touch the method channel.
  ::PostMessage(target, kMessageDrainActions, 0, 0);
}

void MediaCoreAudioPlugin::DrainActions() {
  for (;;) {
    std::string action;

    {
      std::lock_guard<std::mutex> lock(actions_mutex_);

      if (pending_actions_.empty()) {
        return;
      }

      action = pending_actions_.front();
      pending_actions_.erase(pending_actions_.begin());
    }

    if (!channel_) {
      return;
    }

    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("action")] = flutter::EncodableValue(action);

    channel_->InvokeMethod("action", std::make_unique<flutter::EncodableValue>(arguments));
  }
}

void MediaCoreAudioPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "isSupported") {
    result->Success(flutter::EncodableValue(true));

    return;
  }

  if (method == "show") {
    const bool shown = window_ && window_->Show();

    result->Success(flutter::EncodableValue(shown));

    return;
  }

  if (method == "hide") {
    window_->Hide();
    result->Success();

    return;
  }

  if (method == "setBounds") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    if (arguments) {
      window_->SetBounds(
          static_cast<int>(NumberAt(*arguments, "x", 0)),
          static_cast<int>(NumberAt(*arguments, "y", 0)),
          static_cast<int>(NumberAt(*arguments, "width", 900)),
          static_cast<int>(NumberAt(*arguments, "height", 150)));
    }

    result->Success();

    return;
  }

  if (method == "update") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    if (!arguments) {
      result->Success();

      return;
    }

    LyricWindowState state;

    state.text = WideFromUtf8(StringAt(*arguments, "text"));
    state.translation = WideFromUtf8(StringAt(*arguments, "translation"));
    state.next_line = WideFromUtf8(StringAt(*arguments, "nextLine"));
    state.progress = NumberAt(*arguments, "progress", 0.0);
    state.playing = BoolAt(*arguments, "playing", false);
    state.locked = BoolAt(*arguments, "locked", false);
    state.has_lyrics = BoolAt(*arguments, "hasLyrics", true);

    // The Dart state's `style` key carries the visual properties.
    const auto style_iterator =
        arguments->find(flutter::EncodableValue("style"));

    if (style_iterator != arguments->end()) {
      if (const auto* style =
              std::get_if<flutter::EncodableMap>(&style_iterator->second)) {
        const std::string family = StringAt(*style, "fontFamily");

        if (!family.empty()) {
          state.font_family = WideFromUtf8(family);
        }

        state.font_size = NumberAt(*style, "fontSize", state.font_size);

        const double text_color = NumberAt(*style, "textColor", 0xFFFFFFFF);
        const double stroke_color = NumberAt(*style, "strokeColor", 0xFF000000);

        state.text_color = static_cast<std::uint32_t>(text_color);
        state.stroke_color = static_cast<std::uint32_t>(stroke_color);
        state.stroke_width = NumberAt(*style, "strokeWidth", state.stroke_width);
        state.opacity = NumberAt(*style, "opacity", state.opacity);
        state.alignment = WideFromUtf8(StringAt(*style, "alignment"));
      }
    }

    if (window_) {
      window_->Update(state);
    }

    result->Success();

    return;
  }

  result->NotImplemented();
}

}  // namespace media_core_audio
