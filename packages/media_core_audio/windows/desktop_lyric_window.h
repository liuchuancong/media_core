#ifndef MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_
#define MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_

// windows.h defines min/max as macros unless this is set, which breaks every
// std::min/std::max/std::clamp in this file.
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <gdiplus.h>

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace media_core_audio {

/// Everything the overlay draws.
///
/// A whole state rather than deltas: the window lives on its own thread and
/// repaints from this struct under a mutex, so a half-applied update can never
/// be painted.
struct LyricWindowState {
  std::wstring text = L"♪";
  std::wstring translation;
  std::wstring next_line;
  double progress = 0.0;
  bool playing = false;
  bool locked = false;
  bool has_lyrics = true;
  bool visible = false;

  // Style.
  std::wstring font_family = L"Microsoft YaHei UI";
  double font_size = 40.0;
  std::uint32_t text_color = 0xFFFFFFFF;
  std::uint32_t stroke_color = 0xFF000000;
  double stroke_width = 2.0;
  double opacity = 1.0;
  std::wstring alignment = L"center";
};

/// The desktop lyric overlay window on Windows.
///
/// A borderless, always-on-top, per-pixel-alpha (layered) window drawn with
/// GDI+. It is *not* part of the Flutter window: a lyric overlay must sit above
/// other applications while the user works in them, which the Flutter view
/// cannot do from inside its own window.
///
/// It runs on its own thread with its own message loop, because the Flutter
/// platform thread must never be blocked by a second window's message pump.
/// State crosses that boundary through [Update] (mutex + a posted message), and
/// user actions come back through the action callback — which the plugin
/// marshals onto the platform thread before touching any Dart API.
class DesktopLyricWindow {
 public:
  /// Receives `previous`, `toggle`, `next`, `close`, `lock`, `unlock`.
  using ActionCallback = std::function<void(const std::string& action)>;

  explicit DesktopLyricWindow(ActionCallback on_action);
  ~DesktopLyricWindow();

  DesktopLyricWindow(const DesktopLyricWindow&) = delete;
  DesktopLyricWindow& operator=(const DesktopLyricWindow&) = delete;

  /// Windows always has the API; whether the window shows is another matter.
  bool IsSupported() const { return true; }

  /// Creates the window (once) and shows it. False when creation failed.
  bool Show();

  /// Hides the window without destroying it.
  void Hide();

  /// Replaces the drawn state and repaints.
  void Update(const LyricWindowState& state);

  /// Moves/resizes the window in physical pixels.
  void SetBounds(int x, int y, int width, int height);

  /// Window procedure entry point; public because the window class is
  /// registered from a file-local helper.
  static LRESULT CALLBACK WindowProcThunk(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);

 private:
  static constexpr UINT kMessageStateChanged = WM_APP + 201;
  static constexpr UINT kMessageBoundsChanged = WM_APP + 202;
  static constexpr UINT kMessageShow = WM_APP + 203;
  static constexpr UINT kMessageHide = WM_APP + 204;
  static constexpr UINT kMessageQuit = WM_APP + 205;

  LRESULT WindowProc(UINT message, WPARAM wparam, LPARAM lparam);

  void ThreadMain();
  void Paint();
  void LayoutControls();
  void ApplyClickThrough();
  void SetPendingAction(const std::string& action);

  /// Snapshots the drawn state; every reader takes this lock.
  LyricWindowState Snapshot();

  /// Hit-tests the controls; returns the action or an empty string.
  std::string HitTestControls(int x, int y) const;

  /// Paints one line of text with its outline.
  void DrawLine(Gdiplus::Graphics& graphics, const std::wstring& text,
                const Gdiplus::RectF& bounds, float size, bool bold,
                std::uint32_t color, const LyricWindowState& state);

  void DrawControls(Gdiplus::Graphics& graphics, const LyricWindowState& state);
  void DrawProgress(Gdiplus::Graphics& graphics, const LyricWindowState& state);

  ActionCallback on_action_;

  std::thread thread_;
  std::atomic<HWND> hwnd_{nullptr};
  std::atomic<bool> created_{false};
  std::atomic<bool> visible_{false};

  std::mutex mutex_;
  LyricWindowState state_;
  RECT bounds_{0, 0, 900, 150};
  bool bounds_explicit_ = false;

  // Interaction state (window thread only).
  bool dragging_ = false;
  POINT drag_origin_{0, 0};
  RECT drag_window_{0, 0, 0, 0};
  bool hovered_ = false;
  std::string pressed_action_;
  bool controls_visible_ = true;
  bool lock_hint_active_ = false;
  ULONGLONG lock_hint_until_ = 0;
  float dpi_scale_ = 1.0f;

  std::vector<std::pair<std::string, Gdiplus::RectF>> control_hit_areas_;
};

}  // namespace media_core_audio

#endif  // MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_
