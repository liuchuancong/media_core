#include "global_hotkeys_x11.h"

#include <X11/Xlib.h>

#include <sys/select.h>
#include <unistd.h>

#include <algorithm>

#include <cstring>
#include <utility>

namespace media_core_audio {
namespace {

/// Set by the error handler while a grab batch runs: a `BadAccess` on
/// `XGrabKey`/`XSync` means another client already holds the combination.
thread_local bool g_grab_failed = false;

int GrabErrorHandler(Display* display, XErrorEvent* event) {
  if (event->error_code == BadAccess) {
    g_grab_failed = true;
  }

  return 0;
}

/// The non-modifier key's keysym, in the caller's lower-case vocabulary —
/// the same names the Windows host parses (letters, digits, `f1`–`f24`, the
/// arrows and the named keys a keyboard has). Unknown names fail, which
/// surfaces as a failed registration rather than a stuck key.
KeySym KeySymOf(const std::string& key) {
  if (key.size() == 1) {
    const char c = key[0];

    if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
      return XStringToKeysym(key.c_str());
    }

    static const std::map<std::string, const char*> punctuation = {
      {"-", "minus"}, {"=", "equal"}, {",", "comma"}, {".", "period"},
      {"/", "slash"}, {";", "semicolon"}, {"'", "apostrophe"},
      {"[", "bracketleft"}, {"]", "bracketright"}, {"\\", "backslash"},
      {"`", "grave"},
    };

    if (const auto found = punctuation.find(key); found != punctuation.end()) {
      return XStringToKeysym(found->second);
    }

    return NoSymbol;
  }

  static const std::map<std::string, KeySym> named = {
    {"arrowleft", XK_Left}, {"arrowright", XK_Right},
    {"arrowup", XK_Up}, {"arrowdown", XK_Down},
    {"space", XK_space}, {"enter", XK_Return}, {"escape", XK_Escape},
    {"tab", XK_Tab}, {"backspace", XK_BackSpace}, {"delete", XK_Delete},
    {"insert", XK_Insert}, {"home", XK_Home}, {"end", XK_End},
    {"pageup", XK_Prior}, {"pagedown", XK_Next},
  };

  if (const auto found = named.find(key); found != named.end()) {
    return found->second;
  }

  if (key.size() >= 2 && key[0] == 'f') {
    try {
      const int number = std::stoi(key.substr(1));

      if (number >= 1 && number <= 24) {
        return XStringToKeysym(("F" + std::to_string(number)).c_str());
      }
    } catch (const std::exception&) {
      // Falls through to the rejection below.
    }
  }

  return NoSymbol;
}

/// A parsed combination: the key's keycode plus the modifier mask it was
/// registered with. Lock states are not part of the mask — grabs are planted
/// for every Caps/Num lock shape so the shortcut works with either lit.
struct ParsedCombo {
  KeyCode keycode = 0;
  unsigned int mods = 0;
};

bool ParseCombo(Display* display, const std::string& text, ParsedCombo* out) {
  unsigned int mods = 0;
  std::string key;
  size_t start = 0;

  while (start <= text.size()) {
    const size_t plus = text.find('+', start);
    const std::string part = text.substr(
        start, plus == std::string::npos ? std::string::npos : plus - start);

    if (part == "mod" || part == "ctrl") {
      mods |= ControlMask;
    } else if (part == "alt") {
      mods |= Mod1Mask;
    } else if (part == "shift") {
      mods |= ShiftMask;
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

  const KeySym keysym = KeySymOf(key);

  if (keysym == NoSymbol) {
    return false;
  }

  out->keycode = XKeysymToKeycode(display, keysym);
  out->mods = mods;

  return out->keycode != 0;
}

/// Num Lock and Caps Lock each change the state word, so every combination is
/// planted four times — the shape X11 passive grabs have always needed.
constexpr unsigned int kLockMasks[] = {0, LockMask, Mod2Mask,
                                       LockMask | Mod2Mask};

/// The modifier bits reported in a `KeyPress` state, lock bits stripped.
constexpr unsigned int kModMask = ShiftMask | ControlMask | Mod1Mask;

}  // namespace

GlobalHotkeysX11::GlobalHotkeysX11() = default;

GlobalHotkeysX11::~GlobalHotkeysX11() {
  StopThread();
}

void GlobalHotkeysX11::SetFireCallback(FireCallback callback) {
  fire_ = std::move(callback);
}

bool GlobalHotkeysX11::IsSupported() {
  if (display_ != nullptr) {
    return true;
  }

  // Opened on the calling thread, used exclusively by the event thread after
  // this returns: no Xlib call ever races another on this connection.
  display_ = XOpenDisplay(nullptr);

  if (display_ == nullptr) {
    return false;
  }

  StartThread();

  return true;
}

std::map<std::string, bool> GlobalHotkeysX11::Replace(
    const std::map<std::string, std::string>& combos) {
  if (display_ == nullptr) {
    return {};
  }

  std::promise<std::map<std::string, bool>> reply;
  std::future<std::map<std::string, bool>> answer = reply.get_future();

  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    commands_.push_back({CommandKind::kReplace, combos, &reply});
  }

  return answer.get();
}

void GlobalHotkeysX11::Clear() {
  if (display_ == nullptr) {
    return;
  }

  std::lock_guard<std::mutex> lock(command_mutex_);
  commands_.push_back({CommandKind::kClear, {}, nullptr});
}

void GlobalHotkeysX11::StartThread() {
  if (running_.load()) {
    return;
  }

  running_.store(true);

  thread_ = std::thread([this] {
    auto* display = static_cast<Display*>(display_);
    // Held combos are owned by this thread alone; rebuilt on every replace.
    std::vector<std::pair<ParsedCombo, std::pair<std::string, std::string>>>
        held;

    // A self-pipe wakes the select below when a command lands while the
    // thread sits blocked with nothing on the X connection.
    int wake_pipe[2] = {-1, -1};

    if (::pipe(wake_pipe) != 0) {
      wake_pipe[0] = -1;
      wake_pipe[1] = -1;
    }

    while (true) {
      Command command{};

      {
        std::lock_guard<std::mutex> lock(command_mutex_);

        if (!commands_.empty()) {
          command = commands_.front();
          commands_.erase(commands_.begin());
        }
      }

      if (command.kind == CommandKind::kReplace) {
        // Release everything first, then re-plant: the atomic-replace
        // contract the Dart interface promises.
        for (const auto& entry : held) {
          for (const unsigned int lock : kLockMasks) {
            XUngrabKey(display, entry.first.keycode,
                       entry.first.mods | lock, DefaultRootWindow(display));
          }
        }

        held.clear();

        XErrorHandler previous = XSetErrorHandler(GrabErrorHandler);
        std::map<std::string, bool> answer;

        for (const auto& entry : command.combos) {
          ParsedCombo parsed{};

          if (!ParseCombo(display, entry.first, &parsed)) {
            answer[entry.first] = false;

            continue;
          }

          g_grab_failed = false;

          for (const unsigned int lock : kLockMasks) {
            XGrabKey(display, parsed.keycode, parsed.mods | lock,
                     DefaultRootWindow(display), True, GrabModeAsync,
                     GrabModeAsync);
          }

          XSync(display, False);

          if (g_grab_failed) {
            for (const unsigned int lock : kLockMasks) {
              XUngrabKey(display, parsed.keycode, parsed.mods | lock,
                         DefaultRootWindow(display));
            }
          }

          answer[entry.first] = !g_grab_failed;

          if (!g_grab_failed) {
            held.push_back({parsed, entry});
          }
        }

        XSetErrorHandler(previous);
        XSync(display, False);

        if (command.reply != nullptr) {
          command.reply->set_value(std::move(answer));
        }

        continue;
      }

      if (command.kind == CommandKind::kClear) {
        for (const auto& entry : held) {
          for (const unsigned int lock : kLockMasks) {
            XUngrabKey(display, entry.first.keycode,
                       entry.first.mods | lock, DefaultRootWindow(display));
          }
        }

        held.clear();
        XSync(display, False);

        continue;
      }

      if (command.kind == CommandKind::kStop) {
        for (const auto& entry : held) {
          for (const unsigned int lock : kLockMasks) {
            XUngrabKey(display, entry.first.keycode,
                       entry.first.mods | lock, DefaultRootWindow(display));
          }
        }

        XSync(display, False);

        if (command.reply != nullptr) {
          command.reply->set_value({});
        }

        break;
      }

      // No command pending: wait for an X event (a grabbed key) or a command
      // wake, then drain whatever arrived.
      fd_set read_fds;
      FD_ZERO(&read_fds);
      FD_SET(ConnectionNumber(display), &read_fds);

      if (wake_pipe[0] >= 0) {
        FD_SET(wake_pipe[0], &read_fds);
      }

      const int max_fd = std::max(ConnectionNumber(display), wake_pipe[0]);

      if (select(max_fd + 1, &read_fds, nullptr, nullptr, nullptr) <= 0) {
        continue;
      }

      if (wake_pipe[0] >= 0 && FD_ISSET(wake_pipe[0], &read_fds)) {
        char drop = 0;

        if (::read(wake_pipe[0], &drop, 1) < 0) {
          // The pipe never blocks the loop; an empty read just falls through.
        }
      }

      if (!FD_ISSET(ConnectionNumber(display), &read_fds)) {
        continue;
      }

      while (XPending(display) > 0) {
        XEvent event{};

        XNextEvent(display, &event);

        if (event.type != KeyPress) {
          continue;
        }

        const unsigned int state = event.xkey.state & kModMask;

        for (const auto& entry : held) {
          if (entry.first.keycode != event.xkey.keycode ||
              entry.first.mods != state) {
            continue;
          }

          if (fire_) {
            fire_(entry.second.first, entry.second.second);
          }

          break;
        }
      }
    }

    if (wake_pipe[0] >= 0) {
      ::close(wake_pipe[0]);
    }

    if (wake_pipe[1] >= 0) {
      ::close(wake_pipe[1]);
    }

    XCloseDisplay(display);
  });
}

void GlobalHotkeysX11::StopThread() {
  if (display_ == nullptr || !running_.load()) {
    return;
  }

  std::promise<std::map<std::string, bool>> reply;
  std::future<std::map<std::string, bool>> answer = reply.get_future();

  {
    std::lock_guard<std::mutex> lock(command_mutex_);
    commands_.push_back({CommandKind::kStop, {}, &reply});
  }

  answer.get();
  thread_.join();
  running_.store(false);
  display_ = nullptr;
}

}  // namespace media_core_audio
