#ifndef MEDIA_CORE_AUDIO_GLOBAL_HOTKEYS_X11_H_
#define MEDIA_CORE_AUDIO_GLOBAL_HOTKEYS_X11_H_

#include <atomic>
#include <functional>
#include <future>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace media_core_audio {

/// System-wide shortcuts over X11 passive grabs.
///
/// Every X11 call runs on one dedicated thread owning one dedicated display
/// connection — grabs deliver their `KeyPress` events on the connection that
/// registered them, and Xlib is not thread-safe, so the platform thread never
/// touches the display directly: `Replace`/`Clear`/`Stop` are marshalled to
/// that thread and answered through a promise.
///
/// On Wayland sessions the grabs still work through XWayland for as long as
/// XWayland sees the keys; without an X display at all, `IsSupported` answers
/// false and the caller degrades.
class GlobalHotkeysX11 {
 public:
  /// Called on the X11 thread when a registered combination fires; hops to
  /// the GTK main loop on its own if it wants to touch Flutter.
  using FireCallback = std::function<void(const std::string& combo,
                                          const std::string& action)>;

  GlobalHotkeysX11();
  ~GlobalHotkeysX11();

  GlobalHotkeysX11(const GlobalHotkeysX11&) = delete;
  GlobalHotkeysX11& operator=(const GlobalHotkeysX11&) = delete;

  void SetFireCallback(FireCallback callback);

  /// Whether an X display is reachable; the connection (and the event thread)
  /// is opened/lazily started here and lives until destruction.
  bool IsSupported();

  /// Releases everything currently held, then registers [combos]
  /// (`mod+alt+f5` notation, same vocabulary as the Windows host). Each entry
  /// answers whether the grab was accepted — a false usually means another
  /// client already holds the combination.
  std::map<std::string, bool> Replace(
      const std::map<std::string, std::string>& combos);

  /// Releases every combination.
  void Clear();

 private:
  void StartThread();
  void StopThread();

  enum class CommandKind { kReplace, kClear, kStop };

  struct Command {
    CommandKind kind;
    std::map<std::string, std::string> combos;
    std::promise<std::map<std::string, bool>>* reply = nullptr;
  };

  std::map<std::string, bool> RunReplace(
      const std::map<std::string, std::string>& combos);

  FireCallback fire_;
  void* display_ = nullptr;  // XDisplay*, kept opaque to keep the header clean.
  std::thread thread_;
  std::mutex command_mutex_;
  std::vector<Command> commands_;
  std::atomic<bool> running_{false};
};

}  // namespace media_core_audio

#endif  // MEDIA_CORE_AUDIO_GLOBAL_HOTKEYS_X11_H_
