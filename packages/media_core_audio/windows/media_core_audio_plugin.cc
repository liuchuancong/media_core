#include "media_core_audio_plugin.h"

#include <algorithm>
#include <cmath>
#include <map>

namespace media_core_audio {
namespace {

constexpr wchar_t kActionWindowClassName[] = L"MediaCoreAudioActionWindow";
constexpr char kChannelName[] = "media_core_audio/desktop_lyric";
constexpr char kHotkeysChannelName[] = "media_core_audio/global_hotkeys";

/// A combination string parsed into `RegisterHotKey` arguments.
struct ParsedCombo {
  UINT mods = 0;
  UINT vk = 0;
};

/// The non-modifier key's virtual-key code, in the caller's lower-case
/// vocabulary: letters, digits, `f1`–`f24`, the arrows and the named keys a
/// keyboard has. Unknown names fail, which surfaces as a failed registration
/// rather than a stuck key.
bool VirtualKeyOf(const std::string& key, UINT* out) {
  if (key.size() == 1) {
    const char c = key[0];

    if (c >= 'a' && c <= 'z') {
      *out = static_cast<UINT>('A') + (c - 'a');

      return true;
    }

    if (c >= '0' && c <= '9') {
      *out = static_cast<UINT>(c);

      return true;
    }

    switch (c) {
      case '-': *out = VK_OEM_MINUS; return true;
      case '=': *out = VK_OEM_PLUS; return true;
      case ',': *out = VK_OEM_COMMA; return true;
      case '.': *out = VK_OEM_PERIOD; return true;
      case '/': *out = VK_OEM_2; return true;
      case ';': *out = VK_OEM_1; return true;
      case '\'': *out = VK_OEM_7; return true;
      case '[': *out = VK_OEM_4; return true;
      case ']': *out = VK_OEM_6; return true;
      case '\\': *out = VK_OEM_5; return true;
      case '`': *out = VK_OEM_3; return true;
      default: return false;
    }
  }

  static const std::map<std::string, UINT> named = {
    {"arrowleft", VK_LEFT}, {"arrowright", VK_RIGHT},
    {"arrowup", VK_UP}, {"arrowdown", VK_DOWN},
    {"space", VK_SPACE}, {"enter", VK_RETURN}, {"escape", VK_ESCAPE},
    {"tab", VK_TAB}, {"backspace", VK_BACK}, {"delete", VK_DELETE},
    {"insert", VK_INSERT}, {"home", VK_HOME}, {"end", VK_END},
    {"pageup", VK_PRIOR}, {"pagedown", VK_NEXT},
  };

  if (const auto found = named.find(key); found != named.end()) {
    *out = found->second;

    return true;
  }

  if (key.size() >= 2 && key[0] == 'f') {
    try {
      const int number = std::stoi(key.substr(1));

      if (number >= 1 && number <= 24) {
        *out = static_cast<UINT>(VK_F1 + number - 1);

        return true;
      }
    } catch (const std::exception&) {
      // Falls through to the rejection below.
    }
  }

  return false;
}

/// Parses `mod+alt+f5`-style combination strings. `mod` reads as Ctrl, the
/// same way the caller's in-app accelerators read it.
bool ParseCombo(const std::string& text, ParsedCombo* out) {
  UINT mods = 0;
  std::string key;
  size_t start = 0;

  while (start <= text.size()) {
    const size_t plus = text.find('+', start);
    const std::string part = text.substr(
        start, plus == std::string::npos ? std::string::npos : plus - start);

    if (part == "mod" || part == "ctrl") {
      mods |= MOD_CONTROL;
    } else if (part == "alt") {
      mods |= MOD_ALT;
    } else if (part == "shift") {
      mods |= MOD_SHIFT;
    } else if (!part.empty()) {
      if (!key.empty()) {
        return false;
      }

      key = part;
    }

    if (plus == std::string::npos) {
      break;
    }

    start = plus + 1;
  }

  UINT vk = 0;

  if (key.empty() || !VirtualKeyOf(key, &vk)) {
    return false;
  }

  out->mods = mods;
  out->vk = vk;

  return true;
}

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

  // Global shortcuts talk on their own channel and share the action window:
  // `WM_HOTKEY` for a combination registered on it lands in the same
  // procedure, still on the platform thread.
  hotkeys_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kHotkeysChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  hotkeys_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleHotkeyMethodCall(call, std::move(result));
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
  ClearHotkeys();

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

  if (hotkeys_channel_) {
    hotkeys_channel_->SetMethodCallHandler(nullptr);
    hotkeys_channel_.reset();
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

  return self->ActionWindowProc(hwnd, message, wparam, lparam);
}

LRESULT MediaCoreAudioPlugin::ActionWindowProc(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam) {
  if (message == kMessageDrainActions) {
    DrainActions();

    return 0;
  }

  if (message == kMessageDrainHotkeys) {
    DrainHotkeys();

    return 0;
  }

  if (message == WM_HOTKEY) {
    // `wparam` is the id `RegisterHotKey` was given; the table is a small
    // vector, a scan is cheaper than a map.
    const int id = static_cast<int>(wparam);

    for (const HotkeyEntry& entry : hotkeys_) {
      if (entry.id == id) {
        QueueHotkey(entry.combo, entry.action);

        break;
      }
    }

    return 0;
  }

  // The hwnd the message arrived on, not the cached action_window_: during
  // CreateWindowEx that member is still null, and DefWindowProc failing
  // WM_NCCREATE aborts the window's creation outright.
  return ::DefWindowProc(hwnd, message, wparam, lparam);
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

void MediaCoreAudioPlugin::QueueHotkey(const std::string& combo,
                                       const std::string& action) {
  const HWND target = action_window_;

  if (!target) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(hotkey_events_mutex_);
    pending_hotkey_events_.emplace_back(combo, action);
  }

  ::PostMessage(target, kMessageDrainHotkeys, 0, 0);
}

void MediaCoreAudioPlugin::DrainHotkeys() {
  for (;;) {
    std::pair<std::string, std::string> fired;

    {
      std::lock_guard<std::mutex> lock(hotkey_events_mutex_);

      if (pending_hotkey_events_.empty()) {
        return;
      }

      fired = pending_hotkey_events_.front();
      pending_hotkey_events_.erase(pending_hotkey_events_.begin());
    }

    if (!hotkeys_channel_) {
      return;
    }

    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("combo")] =
        flutter::EncodableValue(fired.first);
    arguments[flutter::EncodableValue("action")] =
        flutter::EncodableValue(fired.second);

    hotkeys_channel_->InvokeMethod(
        "fired", std::make_unique<flutter::EncodableValue>(arguments));
  }
}

void MediaCoreAudioPlugin::ClearHotkeys() {
  if (!action_window_) {
    hotkeys_.clear();

    return;
  }

  for (const HotkeyEntry& entry : hotkeys_) {
    ::UnregisterHotKey(action_window_, entry.id);
  }

  hotkeys_.clear();
}

void MediaCoreAudioPlugin::HandleReplaceHotkeys(
    const flutter::EncodableMap& combos,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  ClearHotkeys();

  flutter::EncodableMap answer;
  int id = 1;

  for (const auto& entry : combos) {
    const std::string* combo = std::get_if<std::string>(&entry.first);
    const std::string* action = std::get_if<std::string>(&entry.second);

    if (!combo || !action) {
      continue;
    }

    ParsedCombo parsed;

    bool registered = ParseCombo(*combo, &parsed) &&
                      action_window_ != nullptr &&
                      ::RegisterHotKey(action_window_, id, parsed.mods,
                                       parsed.vk) != 0;

    if (registered) {
      hotkeys_.push_back({id, *combo, *action});

      ++id;
    }

    answer[flutter::EncodableValue(*combo)] =
        flutter::EncodableValue(registered);
  }

  result->Success(flutter::EncodableValue(answer));
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
        state.line_gap = NumberAt(*style, "lineGap", state.line_gap);
        state.bold_line = BoolAt(*style, "boldLine", state.bold_line);
        state.bold_extended = BoolAt(*style, "boldExtended", state.bold_extended);
      }
    }

    if (window_) {
      window_->Update(state);
    }

    result->Success();

    return;
  }

  if (method == "setLevels") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    if (!arguments) {
      result->Success();

      return;
    }

    if (window_) {
      window_->SetLevels(NumberAt(*arguments, "momentary", -70.0),
                         NumberAt(*arguments, "shortTerm", -70.0),
                         BoolAt(*arguments, "active", false));
    }

    result->Success();

    return;
  }

  result->NotImplemented();
}

void MediaCoreAudioPlugin::HandleHotkeyMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "isSupported") {
    result->Success(flutter::EncodableValue(true));

    return;
  }

  if (method == "replace") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    if (!arguments) {
      result->Success(flutter::EncodableValue(flutter::EncodableMap()));

      return;
    }

    const auto combos_iterator =
        arguments->find(flutter::EncodableValue("combos"));

    if (combos_iterator == arguments->end()) {
      result->Success(flutter::EncodableValue(flutter::EncodableMap()));

      return;
    }

    if (const auto* combos =
            std::get_if<flutter::EncodableMap>(&combos_iterator->second)) {
      HandleReplaceHotkeys(*combos, std::move(result));
    } else {
      result->Success(flutter::EncodableValue(flutter::EncodableMap()));
    }

    return;
  }

  if (method == "clear") {
    ClearHotkeys();
    result->Success();

    return;
  }

  result->NotImplemented();
}

}  // namespace media_core_audio
