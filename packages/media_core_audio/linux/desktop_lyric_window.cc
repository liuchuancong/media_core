#include "desktop_lyric_window.h"

#include <pango/pangocairo.h>

#include <algorithm>
#include <cmath>

namespace media_core_audio {
namespace {

/// How often the lock hint is checked, and how long it lasts.
constexpr guint kLockHintIntervalMs = 100;
constexpr gint64 kLockHintMicros = 2000 * 1000;

/// The build pins C++14 (`apply_standard_settings`), so no `std::clamp`, and
/// no dependency on `M_PI` being exposed by the C library.
constexpr double kPi = 3.14159265358979323846;

template <typename T>
T Clamp(T value, T low, T high) {
  return value < low ? low : (value > high ? high : value);
}

void SetSourceColor(cairo_t* cr, std::uint32_t argb, double alpha = 1.0) {
  const double a = ((argb >> 24) & 0xFF) / 255.0 * alpha;
  const double r = ((argb >> 16) & 0xFF) / 255.0;
  const double g = ((argb >> 8) & 0xFF) / 255.0;
  const double b = (argb & 0xFF) / 255.0;

  cairo_set_source_rgba(cr, r, g, b, a);
}

void RoundedRect(cairo_t* cr, double x, double y, double width, double height,
                 double radius) {
  const double r = std::min(radius, std::min(width, height) / 2.0);

  cairo_new_sub_path(cr);
  cairo_arc(cr, x + width - r, y + r, r, -kPi / 2.0, 0);
  cairo_arc(cr, x + width - r, y + height - r, r, 0, kPi / 2.0);
  cairo_arc(cr, x + r, y + height - r, r, kPi / 2.0, kPi);
  cairo_arc(cr, x + r, y + r, r, kPi, 3.0 * kPi / 2.0);
  cairo_close_path(cr);
}

/// Draws one of the overlay's buttons.
///
/// Geometric shapes rather than an icon font: a missing glyph renders as a
/// box, while a triangle plus a bar always reads as "play" and "skip".
void DrawGlyph(cairo_t* cr, const std::string& action, double x, double y,
               double size, std::uint32_t color) {
  const double cx = x + size / 2.0;
  const double cy = y + size / 2.0;
  const double radius = size * 0.5;

  SetSourceColor(cr, color);
  cairo_set_line_width(cr, std::max(1.5, radius * 0.18));

  if (action == "toggle_play") {
    cairo_move_to(cr, cx - radius * 0.6, cy - radius);
    cairo_line_to(cr, cx - radius * 0.6, cy + radius);
    cairo_line_to(cr, cx + radius * 0.9, cy);
    cairo_close_path(cr);
    cairo_fill(cr);

    return;
  }

  if (action == "toggle_pause") {
    cairo_rectangle(cr, cx - radius * 0.7, cy - radius, radius * 0.5,
                    radius * 2.0);
    cairo_rectangle(cr, cx + radius * 0.2, cy - radius, radius * 0.5,
                    radius * 2.0);
    cairo_fill(cr);

    return;
  }

  if (action == "previous" || action == "next") {
    const double direction = action == "previous" ? -1.0 : 1.0;

    cairo_move_to(cr, cx + direction * radius * 0.9, cy - radius);
    cairo_line_to(cr, cx + direction * radius * 0.9, cy + radius);
    cairo_line_to(cr, cx - direction * radius * 0.4, cy);
    cairo_close_path(cr);
    cairo_fill(cr);

    cairo_rectangle(cr, cx - direction * radius * 1.1 - radius * 0.12,
                    cy - radius, radius * 0.24, radius * 2.0);
    cairo_fill(cr);

    return;
  }

  if (action == "close") {
    cairo_move_to(cr, cx - radius * 0.6, cy - radius * 0.6);
    cairo_line_to(cr, cx + radius * 0.6, cy + radius * 0.6);
    cairo_move_to(cr, cx + radius * 0.6, cy - radius * 0.6);
    cairo_line_to(cr, cx - radius * 0.6, cy + radius * 0.6);
    cairo_stroke(cr);

    return;
  }

  // "lock": a padlock — body plus shackle.
  const double body_width = radius * 1.3;
  const double body_height = radius * 0.9;

  cairo_rectangle(cr, cx - body_width / 2.0, cy - body_height * 0.15,
                  body_width, body_height);
  cairo_fill(cr);

  cairo_arc(cr, cx, cy - body_height * 0.15, body_width * 0.35, kPi, 0);
  cairo_stroke(cr);
}

}  // namespace

DesktopLyricWindow::DesktopLyricWindow(ActionCallback on_action)
    : on_action_(std::move(on_action)) {}

DesktopLyricWindow::~DesktopLyricWindow() {
  if (lock_hint_source_ != 0) {
    g_source_remove(lock_hint_source_);
    lock_hint_source_ = 0;
  }

  if (window_ != nullptr) {
    gtk_widget_destroy(window_);
    window_ = nullptr;
  }
}

bool DesktopLyricWindow::IsSupported() const {
  return gdk_display_get_default() != nullptr;
}

void DesktopLyricWindow::EnsureWindow() {
  if (window_ != nullptr) {
    return;
  }

  window_ = gtk_window_new(GTK_WINDOW_POPUP);

  // Override-redirect popup: no frame, no focus, no taskbar entry — and it
  // stays above other applications.
  gtk_window_set_type_hint(GTK_WINDOW(window_),
                           GDK_WINDOW_TYPE_HINT_NOTIFICATION);
  gtk_window_set_keep_above(GTK_WINDOW(window_), TRUE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window_), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(window_), TRUE);
  gtk_window_set_accept_focus(GTK_WINDOW(window_), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(window_), FALSE);
  gtk_window_set_decorated(GTK_WINDOW(window_), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(window_), FALSE);

  // Transparency needs an RGBA visual plus a paint handler that does not fill
  // the background.
  gtk_widget_set_app_paintable(window_, TRUE);

  GdkScreen* screen = gtk_widget_get_screen(window_);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);

  if (visual != nullptr) {
    gtk_widget_set_visual(window_, visual);
  }

  gtk_widget_add_events(window_,
                        GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                            GDK_POINTER_MOTION_MASK | GDK_LEAVE_NOTIFY_MASK |
                            GDK_ENTER_NOTIFY_MASK);

  g_signal_connect(window_, "draw", G_CALLBACK(OnDraw), this);
  g_signal_connect(window_, "button-press-event", G_CALLBACK(OnButtonPress),
                   this);
  g_signal_connect(window_, "button-release-event", G_CALLBACK(OnButtonRelease),
                   this);
  g_signal_connect(window_, "motion-notify-event", G_CALLBACK(OnMotion), this);
  g_signal_connect(window_, "leave-notify-event", G_CALLBACK(OnLeave), this);

  if (!bounds_explicit_) {
    GdkDisplay* display = gdk_display_get_default();
    GdkMonitor* monitor =
        display != nullptr ? gdk_display_get_primary_monitor(display) : nullptr;

    GdkRectangle geometry{};

    if (monitor != nullptr) {
      gdk_monitor_get_geometry(monitor, &geometry);
    } else {
      geometry.width = 1920;
      geometry.height = 1080;
    }

    width_ = std::min(900, geometry.width - 80);
    height_ = 150;
    x_ = geometry.x + (geometry.width - width_) / 2;
    y_ = geometry.y + geometry.height - height_ -
         static_cast<int>(geometry.height * 0.12);
  }
}

bool DesktopLyricWindow::Show() {
  if (!IsSupported()) {
    return false;
  }

  EnsureWindow();

  // Size before mapping, position after: gtk_window_move is documented as
  // unreliable on an unmapped toplevel, and an override-redirect popup is
  // exactly the case where it must stick.
  gtk_window_resize(GTK_WINDOW(window_), width_, height_);
  gtk_widget_show(window_);
  gtk_window_move(GTK_WINDOW(window_), x_, y_);

  shown_ = true;

  gtk_widget_queue_draw(window_);

  return true;
}

void DesktopLyricWindow::Hide() {
  if (window_ == nullptr) {
    return;
  }

  gtk_widget_hide(window_);
  shown_ = false;
}

void DesktopLyricWindow::Update(const LyricWindowState& state) {
  if (window_ == nullptr) {
    // Keep the state for the window that Show() will create later.
    const bool lock_changed = state.locked != state_.locked;
    state_ = state;

    if (lock_changed && state_.locked) {
      // The hint timer has to start here too: a lock that lands before the
      // first show would otherwise never expire, and the shown window would
      // stay interactive forever.
      lock_hint_active_ = true;
      lock_hint_deadline_ = g_get_monotonic_time() + kLockHintMicros;

      if (lock_hint_source_ == 0) {
        lock_hint_source_ = g_timeout_add(kLockHintIntervalMs,
                                          OnLockHintTimeout, this);
      }
    }

    return;
  }

  const bool lock_changed = state.locked != state_.locked;

  state_ = state;

  if (lock_changed) {
    if (state_.locked) {
      // Show the hint first: after it expires the window stops taking input,
      // and the user should have seen why.
      lock_hint_active_ = true;
      lock_hint_deadline_ = g_get_monotonic_time() + kLockHintMicros;

      if (lock_hint_source_ == 0) {
        lock_hint_source_ = g_timeout_add(kLockHintIntervalMs,
                                          OnLockHintTimeout, this);
      }
    } else {
      lock_hint_active_ = false;

      if (lock_hint_source_ != 0) {
        g_source_remove(lock_hint_source_);
        lock_hint_source_ = 0;
      }

      controls_visible_ = true;
    }
  }

  ApplyClickThrough();

  if (shown_) {
    gtk_widget_queue_draw(window_);
  }
}

void DesktopLyricWindow::SetBounds(int x, int y, int width, int height) {
  x_ = x;
  y_ = y;
  width_ = std::max(200, width);
  height_ = std::max(80, height);
  bounds_explicit_ = true;

  if (window_ != nullptr) {
    gtk_window_move(GTK_WINDOW(window_), x_, y_);
    gtk_window_resize(GTK_WINDOW(window_), width_, height_);
    gtk_widget_queue_draw(window_);
  }
}

void DesktopLyricWindow::ApplyClickThrough() {
  if (window_ == nullptr) {
    return;
  }

  controls_visible_ = !state_.locked || lock_hint_active_;

  if (state_.locked && !lock_hint_active_) {
    // An empty input shape makes the whole window transparent to input. This
    // is X11 behaviour; under Wayland the shape is ignored and the locked
    // overlay simply hides its controls.
    cairo_region_t* empty = cairo_region_create();

    gtk_widget_input_shape_combine_region(window_, empty);
    cairo_region_destroy(empty);

    return;
  }

  gtk_widget_input_shape_combine_region(window_, nullptr);
}

gboolean DesktopLyricWindow::OnLockHintTimeout(gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  if (!self->lock_hint_active_) {
    self->lock_hint_source_ = 0;

    return G_SOURCE_REMOVE;
  }

  if (g_get_monotonic_time() < self->lock_hint_deadline_) {
    return G_SOURCE_CONTINUE;
  }

  // The hint has been visible long enough: go click-through.
  self->lock_hint_active_ = false;
  self->lock_hint_source_ = 0;
  self->ApplyClickThrough();

  if (self->window_ != nullptr) {
    gtk_widget_queue_draw(self->window_);
  }

  return G_SOURCE_REMOVE;
}

gboolean DesktopLyricWindow::OnDraw(GtkWidget* widget, cairo_t* cr,
                                    gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  self->Paint(cr);

  return TRUE;
}

void DesktopLyricWindow::Paint(cairo_t* cr) {
  const int width = width_;
  const int height = height_;

  // Clear to fully transparent: a layered/popup window is not opaque, and the
  // stale frame would otherwise stay visible around the panel.
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 0, 0, 0, 0);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

  // Panel.
  RoundedRect(cr, 0, 0, width, height, 14);
  cairo_set_source_rgba(cr, 0, 0, 0, 0.6 * Clamp(state_.opacity, 0.0, 1.0));
  cairo_fill(cr);

  LayoutControls();

  const bool strip = controls_visible_ && (hovering_ || lock_hint_active_);
  const double top = strip ? 34.0 : 8.0;

  if (strip) {
    DrawControls(cr);
  }

  if (state_.vertical) {
    // Vertical-rl: the slots sit side by side, the current line owning the
    // right edge, each slot's columns flowing leftwards.
    const double column_area =
        std::max(40.0, static_cast<double>(height) - top - 40.0);
    const double inset = 16.0;
    double right = static_cast<double>(width) - inset;

    const double main_taken = DrawVerticalText(
        cr, state_.text, right, top, column_area, state_.font_size,
        state_.bold_line, state_.text_color);
    right -= main_taken + state_.line_gap;

    if (state_.has_lyrics && !state_.translation.empty()) {
      const double taken =
          DrawVerticalText(cr, state_.translation, right, top, column_area,
                           state_.font_size * 0.42, state_.bold_extended,
                           0xCCFFFFFF);
      right -= taken + state_.line_gap;
    }

    if (state_.has_lyrics && !state_.next_line.empty() && width > 120) {
      DrawVerticalText(cr, state_.next_line, right, top, column_area,
                       state_.font_size * 0.34, false, 0x88FFFFFF);
    }
  } else {
    double cursor = top;

    DrawText(cr, state_.text, cursor, state_.font_size, state_.bold_line,
             state_.text_color);
    cursor += state_.font_size * 1.3 + state_.line_gap;

    if (state_.has_lyrics && !state_.translation.empty()) {
      DrawText(cr, state_.translation, cursor, state_.font_size * 0.42,
               state_.bold_extended, 0xCCFFFFFF);
      cursor += state_.font_size * 0.55 + state_.line_gap;
    }

    if (state_.has_lyrics && !state_.next_line.empty() && height > 120) {
      DrawText(cr, state_.next_line, cursor, state_.font_size * 0.34, false,
               0x88FFFFFF);
    }
  }

  if (lock_hint_active_) {
    DrawText(cr, "Locked", 6, 14, false, 0xE6FFFFFF);
  }

  DrawProgress(cr);
}

double DesktopLyricWindow::DrawVerticalText(cairo_t* cr,
                                            const std::string& text,
                                            double right, double top,
                                            double area_height, double size,
                                            bool bold, std::uint32_t color) {
  if (text.empty() || size <= 0.0 || area_height <= size) {
    return 0.0;
  }

  const double pitch = size * 1.3;
  const double bottom = top + area_height;
  double column = right - pitch;
  double y = top;
  double start_column = column;

  PangoFontDescription* description = pango_font_description_new();
  pango_font_description_set_family(description, state_.font_family.c_str());
  pango_font_description_set_absolute_size(description, size * PANGO_SCALE);
  pango_font_description_set_weight(description,
                                    bold ? PANGO_WEIGHT_BOLD
                                         : PANGO_WEIGHT_NORMAL);

  cairo_set_line_width(cr, std::max(1.0, state_.stroke_width));
  cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND);

  std::uint32_t cp = 0;
  std::uint8_t continuation = 0;
  for (const char byte : text) {
    const std::uint8_t b = static_cast<std::uint8_t>(byte);
    if (continuation > 0) {
      cp = (cp << 6) | (b & 0x3F);
      --continuation;
      if (continuation > 0) {
        continue;
      }
    } else if (b >= 0xF0) {
      cp = b & 0x07;
      continuation = 3;
      continue;
    } else if (b >= 0xE0) {
      cp = b & 0x0F;
      continuation = 2;
      continue;
    } else if (b >= 0xC0) {
      cp = b & 0x1F;
      continuation = 1;
      continue;
    } else {
      cp = b;
    }

    const bool upright = (cp >= 0x2E80 && cp <= 0x9FFF) ||
                         (cp >= 0xAC00 && cp <= 0xD7AF) ||
                         (cp >= 0xF900 && cp <= 0xFAFF) ||
                         (cp >= 0xFF00 && cp <= 0xFF60) ||
                         (cp >= 0x3000 && cp <= 0x303F);

    char utf8[5];
    gint utf8_len;
    if (cp < 0x80) {
      utf8[0] = static_cast<char>(cp);
      utf8_len = 1;
    } else if (cp < 0x800) {
      utf8[0] = static_cast<char>(0xC0 | (cp >> 6));
      utf8[1] = static_cast<char>(0x80 | (cp & 0x3F));
      utf8_len = 2;
    } else if (cp < 0x10000) {
      utf8[0] = static_cast<char>(0xE0 | (cp >> 12));
      utf8[1] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      utf8[2] = static_cast<char>(0x80 | (cp & 0x3F));
      utf8_len = 3;
    } else {
      utf8[0] = static_cast<char>(0xF0 | (cp >> 18));
      utf8[1] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
      utf8[2] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      utf8[3] = static_cast<char>(0x80 | (cp & 0x3F));
      utf8_len = 4;
    }

    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_text(layout, utf8, utf8_len);
    pango_layout_set_font_description(layout, description);
    PangoRectangle ink;
    PangoRectangle logical;
    pango_layout_get_pixel_extents(layout, &ink, &logical);

    const double step = upright
                            ? std::max(static_cast<double>(logical.height),
                                       size * 0.6)
                            : std::max(static_cast<double>(logical.width),
                                       size * 0.3);
    if (y + step > bottom) {
      column -= pitch;
      y = top;
      if (column < -pitch) {
        g_object_unref(layout);
        break;  // the slot spent the whole window width; clipping is honest
      }
    }

    if (upright) {
      cairo_move_to(cr, column + (pitch - logical.width) * 0.5 - ink.x, y - ink.y);
      pango_cairo_layout_path(cr, layout);
      SetSourceColor(cr, state_.stroke_color);
      cairo_stroke_preserve(cr);
      SetSourceColor(cr, color);
      cairo_fill(cr);
    } else {
      // Horizontal scripts rotate a quarter turn, reading downwards the way
      // vertical-rl sets Latin text.
      cairo_save(cr);
      cairo_translate(cr, column + pitch * 0.5, y + step * 0.5);
      cairo_rotate(cr, kPi * 0.5);
      cairo_move_to(cr, -logical.width * 0.5 - ink.x, -logical.height * 0.5 - ink.y);
      pango_cairo_layout_path(cr, layout);
      SetSourceColor(cr, state_.stroke_color);
      cairo_stroke_preserve(cr);
      SetSourceColor(cr, color);
      cairo_fill(cr);
      cairo_restore(cr);
    }

    g_object_unref(layout);
    y += step;
  }

  pango_font_description_free(description);

  const double consumed = start_column - column + pitch;
  return consumed > 0.0 ? std::min(consumed, right) : 0.0;
}

void DesktopLyricWindow::DrawText(cairo_t* cr, const std::string& text,
                                  double y, double size, bool bold,
                                  std::uint32_t color) {
  if (text.empty()) {
    return;
  }

  PangoLayout* layout = pango_cairo_create_layout(cr);

  pango_layout_set_text(layout, text.c_str(), -1);

  PangoFontDescription* description = pango_font_description_new();
  pango_font_description_set_family(description, state_.font_family.c_str());
  pango_font_description_set_absolute_size(description, size * PANGO_SCALE);
  pango_font_description_set_weight(description,
                                    bold ? PANGO_WEIGHT_BOLD
                                         : PANGO_WEIGHT_NORMAL);
  pango_layout_set_font_description(layout, description);
  pango_font_description_free(description);

  pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);

  const double inset = 24.0;
  pango_layout_set_width(layout,
                         static_cast<int>((width_ - inset * 2) * PANGO_SCALE));
  pango_layout_set_alignment(
      layout, state_.alignment == "left"
                  ? PANGO_ALIGN_LEFT
                  : state_.alignment == "right" ? PANGO_ALIGN_RIGHT
                                                : PANGO_ALIGN_CENTER);

  cairo_move_to(cr, inset, y);

  // Stroke first (keeping the path), then fill: that is what gives the text
  // the outline that keeps it readable over a bright video.
  pango_cairo_layout_path(cr, layout);
  SetSourceColor(cr, state_.stroke_color);
  cairo_set_line_width(cr, std::max(1.0, state_.stroke_width));
  cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND);
  cairo_stroke_preserve(cr);
  SetSourceColor(cr, color);
  cairo_fill(cr);

  g_object_unref(layout);
}

void DesktopLyricWindow::LayoutControls() {
  control_areas_.clear();

  const double size = 26.0;
  const double gap = 8.0;
  const std::vector<std::string> actions = {"previous", "toggle_play", "next",
                                            "lock", "close"};

  const double total = static_cast<double>(actions.size()) * size +
                       static_cast<double>(actions.size() - 1) * gap;
  double x = (width_ - total) / 2.0;
  const double y = 4.0;

  for (const auto& action : actions) {
    control_areas_.push_back(ControlArea{action, x, y, size});
    x += size + gap;
  }
}

void DesktopLyricWindow::DrawControls(cairo_t* cr) {
  for (const auto& area : control_areas_) {
    std::string action = area.action;

    if (action == "toggle_play") {
      action = state_.playing ? "toggle_pause" : "toggle_play";
    }

    DrawGlyph(cr, action, area.x, area.y, area.size, 0xE6FFFFFF);
  }
}

void DesktopLyricWindow::DrawProgress(cairo_t* cr) {
  if (!state_.has_lyrics) {
    return;
  }

  const double margin = 16.0;
  const double bar_height = 3.0;
  const double y = height_ - bar_height - 6.0;
  const double progress = Clamp(state_.progress, 0.0, 1.0);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.25);
  cairo_rectangle(cr, margin, y, width_ - margin * 2, bar_height);
  cairo_fill(cr);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.8);
  cairo_rectangle(cr, margin, y, (width_ - margin * 2) * progress, bar_height);
  cairo_fill(cr);
}

std::string DesktopLyricWindow::HitTestControls(double x, double y) const {
  if (!controls_visible_) {
    return std::string();
  }

  for (const auto& area : control_areas_) {
    if (x >= area.x && x <= area.x + area.size && y >= area.y &&
        y <= area.y + area.size) {
      return area.action;
    }
  }

  return std::string();
}

gboolean DesktopLyricWindow::OnButtonPress(GtkWidget* widget,
                                           GdkEventButton* event,
                                           gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  self->pressed_action_ = self->HitTestControls(event->x, event->y);

  if (!self->pressed_action_.empty()) {
    return TRUE;
  }

  if (!self->state_.locked) {
    self->dragging_ = true;
    self->drag_origin_x_ = self->x_;
    self->drag_origin_y_ = self->y_;
    self->drag_offset_x_ = event->x_root;
    self->drag_offset_y_ = event->y_root;
  }

  return TRUE;
}

gboolean DesktopLyricWindow::OnMotion(GtkWidget* widget, GdkEventMotion* event,
                                      gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  if (self->dragging_) {
    self->x_ = self->drag_origin_x_ +
               static_cast<int>(event->x_root - self->drag_offset_x_);
    self->y_ = self->drag_origin_y_ +
               static_cast<int>(event->y_root - self->drag_offset_y_);

    gtk_window_move(GTK_WINDOW(self->window_), self->x_, self->y_);

    return TRUE;
  }

  if (!self->hovering_) {
    self->hovering_ = true;

    if (self->window_ != nullptr) {
      gtk_widget_queue_draw(self->window_);
    }
  }

  return FALSE;
}

gboolean DesktopLyricWindow::OnLeave(GtkWidget* widget,
                                     GdkEventCrossing* event,
                                     gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  self->hovering_ = false;

  if (self->window_ != nullptr) {
    gtk_widget_queue_draw(self->window_);
  }

  return FALSE;
}

gboolean DesktopLyricWindow::OnButtonRelease(GtkWidget* widget,
                                             GdkEventButton* event,
                                             gpointer user_data) {
  auto* self = static_cast<DesktopLyricWindow*>(user_data);

  if (self->dragging_) {
    self->dragging_ = false;

    // The move is already reflected in x_/y_; this only makes the drag end
    // observable to a host that queries the position afterwards.
    gint x = 0;
    gint y = 0;

    gtk_window_get_position(GTK_WINDOW(self->window_), &x, &y);

    self->x_ = x;
    self->y_ = y;

    return TRUE;
  }

  if (!self->pressed_action_.empty()) {
    const std::string action = self->pressed_action_;
    self->pressed_action_.clear();

    self->SetPendingAction(action);
  }

  return TRUE;
}

void DesktopLyricWindow::SetPendingAction(const std::string& action) {
  // The overlay's buttons speak the same vocabulary as the Dart protocol; only
  // the play/pause pair is drawn from the playing state and collapses back to
  // "toggle".
  std::string resolved = action;

  if (resolved == "toggle_play" || resolved == "toggle_pause") {
    resolved = "toggle";
  }

  if (on_action_) {
    on_action_(resolved);
  }
}

}  // namespace media_core_audio
