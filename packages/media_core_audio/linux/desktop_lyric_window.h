#ifndef MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_
#define MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_

#include <gtk/gtk.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace media_core_audio {

/// Everything the overlay draws. Text is UTF-8: Pango consumes UTF-8 directly,
/// so no wide-character conversion is involved on this platform.
struct LyricWindowState {
  std::string text = "♪";
  std::string translation;
  std::string next_line;
  double progress = 0.0;
  bool playing = false;
  bool locked = false;
  bool has_lyrics = true;

  std::string font_family = "Sans";
  double font_size = 40.0;
  std::uint32_t text_color = 0xFFFFFFFF;
  std::uint32_t stroke_color = 0xFF000000;
  double stroke_width = 2.0;
  double opacity = 1.0;
  std::string alignment = "center";
};

/// The desktop lyric overlay on Linux (X11/Wayland) through GTK.
///
/// A `GTK_WINDOW_POPUP` — override-redirect, so the window manager gives it no
/// frame, no focus and no taskbar entry — kept above everything else with
/// `gtk_window_set_keep_above`, drawn with Cairo/Pango on an RGBA visual so the
/// background can be genuinely transparent.
///
/// Everything here runs on the GTK main thread, which *is* the Flutter platform
/// thread on Linux: unlike Windows, no second thread or message hop is needed.
///
/// Click-through (the locked state) uses an empty input shape, which is an X11
/// feature. Under Wayland a locked overlay still passes no input through, so
/// the lock only hides the controls there.
class DesktopLyricWindow {
 public:
  /// Receives `previous`, `toggle`, `next`, `close`, `lock`, `unlock`.
  using ActionCallback = std::function<void(const std::string& action)>;

  explicit DesktopLyricWindow(ActionCallback on_action);
  ~DesktopLyricWindow();

  DesktopLyricWindow(const DesktopLyricWindow&) = delete;
  DesktopLyricWindow& operator=(const DesktopLyricWindow&) = delete;

  /// Whether a display is available (false on a headless run).
  bool IsSupported() const;

  /// Creates and shows the window; false when GTK has no display.
  bool Show();

  /// Hides the window, keeping it alive.
  void Hide();

  /// Replaces the drawn state and repaints.
  void Update(const LyricWindowState& state);

  /// Moves/resizes the window.
  void SetBounds(int x, int y, int width, int height);

 private:
  static gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer user_data);
  static gboolean OnButtonPress(GtkWidget* widget, GdkEventButton* event,
                                gpointer user_data);
  static gboolean OnButtonRelease(GtkWidget* widget, GdkEventButton* event,
                                  gpointer user_data);
  static gboolean OnMotion(GtkWidget* widget, GdkEventMotion* event,
                           gpointer user_data);
  static gboolean OnLeave(GtkWidget* widget, GdkEventCrossing* event,
                          gpointer user_data);
  static gboolean OnLockHintTimeout(gpointer user_data);

  void EnsureWindow();
  void Paint(cairo_t* cr);
  void DrawText(cairo_t* cr, const std::string& text, double y, double size,
                bool bold, std::uint32_t color);
  void DrawControls(cairo_t* cr);
  void DrawProgress(cairo_t* cr);
  void LayoutControls();
  void ApplyClickThrough();
  void SetPendingAction(const std::string& action);

  std::string HitTestControls(double x, double y) const;

  ActionCallback on_action_;

  GtkWidget* window_ = nullptr;
  LyricWindowState state_;

  int width_ = 900;
  int height_ = 150;
  int x_ = 0;
  int y_ = 0;
  bool bounds_explicit_ = false;
  bool shown_ = false;
  bool hovering_ = false;
  bool dragging_ = false;
  bool controls_visible_ = true;
  bool lock_hint_active_ = false;
  guint lock_hint_source_ = 0;
  gint64 lock_hint_deadline_ = 0;

  /// Window origin when the current drag started, and the pointer position at
  /// that moment: the move is computed from these, so a drag never accumulates
  /// rounding drift.
  int drag_origin_x_ = 0;
  int drag_origin_y_ = 0;
  double drag_offset_x_ = 0;
  double drag_offset_y_ = 0;
  std::string pressed_action_;

  struct ControlArea {
    std::string action;
    double x = 0;
    double y = 0;
    double size = 0;
  };

  std::vector<ControlArea> control_areas_;
};

}  // namespace media_core_audio

#endif  // MEDIA_CORE_AUDIO_DESKTOP_LYRIC_WINDOW_H_
