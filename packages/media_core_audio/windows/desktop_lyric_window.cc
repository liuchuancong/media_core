#include "desktop_lyric_window.h"

#include <windowsx.h>  // GET_X_LPARAM / GET_Y_LPARAM

#include <algorithm>

namespace media_core_audio {
namespace {

constexpr wchar_t kWindowClassName[] = L"MediaCoreDesktopLyricWindow";

/// How long the overlay stays interactive after a lock request, so the user
/// sees what happened before it becomes click-through.
constexpr ULONGLONG kLockHintMillis = 2000;

Gdiplus::Color ToColor(std::uint32_t argb) {
  return Gdiplus::Color(static_cast<BYTE>((argb >> 24) & 0xFF),
                        static_cast<BYTE>((argb >> 16) & 0xFF),
                        static_cast<BYTE>((argb >> 8) & 0xFF),
                        static_cast<BYTE>(argb & 0xFF));
}

/// Starts GDI+ once per process.
///
/// Never shut down on purpose: shutdown during process teardown races threads
/// that may still be painting, and the OS reclaims everything at exit anyway.
void EnsureGdiplus() {
  static bool started = false;

  if (started) {
    return;
  }

  Gdiplus::GdiplusStartupInput input;
  ULONG_PTR token = 0;

  if (Gdiplus::GdiplusStartup(&token, &input, nullptr) == Gdiplus::Ok) {
    started = true;
  }
}

ATOM EnsureWindowClass() {
  static ATOM atom = 0;

  if (atom != 0) {
    return atom;
  }

  WNDCLASS window_class{};
  window_class.lpfnWndProc = DesktopLyricWindow::WindowProcThunk;
  window_class.hInstance = ::GetModuleHandle(nullptr);
  window_class.lpszClassName = kWindowClassName;
  window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);

  atom = ::RegisterClass(&window_class);

  return atom;
}

/// Draws one of the overlay's buttons.
///
/// Geometric shapes rather than an icon font: a missing icon font renders as a
/// box, while a triangle plus a bar always reads as "play" and "skip".
void DrawGlyph(Gdiplus::Graphics& graphics, const std::string& action,
               const Gdiplus::RectF& box, const Gdiplus::Color& color) {
  Gdiplus::SolidBrush brush(color);
  Gdiplus::Pen pen(color, 2.0f);
  pen.SetLineJoin(Gdiplus::LineJoinRound);

  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);

  const float cx = box.X + box.Width / 2.0f;
  const float cy = box.Y + box.Height / 2.0f;
  const float size = std::min(box.Width, box.Height) * 0.5f;

  if (action == "toggle_play") {
    Gdiplus::GraphicsPath path;
    const Gdiplus::PointF points[3] = {
        Gdiplus::PointF(cx - size * 0.6f, cy - size),
        Gdiplus::PointF(cx - size * 0.6f, cy + size),
        Gdiplus::PointF(cx + size * 0.9f, cy)};
    path.AddPolygon(points, 3);
    graphics.FillPath(&brush, &path);

    return;
  }

  if (action == "toggle_pause") {
    graphics.FillRectangle(&brush, cx - size * 0.7f, cy - size, size * 0.5f,
                           size * 2.0f);
    graphics.FillRectangle(&brush, cx + size * 0.2f, cy - size, size * 0.5f,
                           size * 2.0f);

    return;
  }

  if (action == "previous" || action == "next") {
    const float direction = action == "previous" ? -1.0f : 1.0f;

    Gdiplus::GraphicsPath path;
    const Gdiplus::PointF points[3] = {
        Gdiplus::PointF(cx + direction * size * 0.9f, cy - size),
        Gdiplus::PointF(cx + direction * size * 0.9f, cy + size),
        Gdiplus::PointF(cx - direction * size * 0.4f, cy)};
    path.AddPolygon(points, 3);
    graphics.FillPath(&brush, &path);

    // The bar that turns a triangle into a skip button.
    graphics.FillRectangle(&brush,
                           cx - direction * size * 1.1f - size * 0.12f,
                           cy - size, size * 0.24f, size * 2.0f);

    return;
  }

  if (action == "close") {
    graphics.DrawLine(&pen, cx - size * 0.6f, cy - size * 0.6f,
                      cx + size * 0.6f, cy + size * 0.6f);
    graphics.DrawLine(&pen, cx + size * 0.6f, cy - size * 0.6f,
                      cx - size * 0.6f, cy + size * 0.6f);

    return;
  }

  // "lock": a padlock — body plus shackle.
  const float body_width = size * 1.3f;
  const float body_height = size * 0.9f;

  graphics.FillRectangle(&brush, cx - body_width / 2.0f,
                         cy - body_height * 0.15f, body_width, body_height);

  const Gdiplus::RectF shackle(cx - body_width * 0.35f, cy - size * 1.15f,
                               body_width * 0.7f, body_height * 1.4f);
  graphics.DrawArc(&pen, shackle, 180.0f, 180.0f);
}

}  // namespace

DesktopLyricWindow::DesktopLyricWindow(ActionCallback on_action)
    : on_action_(std::move(on_action)) {}

DesktopLyricWindow::~DesktopLyricWindow() {
  const HWND hwnd = hwnd_.load();

  if (hwnd) {
    ::PostMessage(hwnd, kMessageQuit, 0, 0);
  }

  if (thread_.joinable()) {
    thread_.join();
  }

  hwnd_ = nullptr;
  created_ = false;
}

LRESULT CALLBACK DesktopLyricWindow::WindowProcThunk(HWND hwnd, UINT message,
                                                     WPARAM wparam,
                                                     LPARAM lparam) {
  DesktopLyricWindow* self = nullptr;

  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
    self = static_cast<DesktopLyricWindow*>(create->lpCreateParams);
    ::SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<DesktopLyricWindow*>(
        ::GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  if (!self) {
    return ::DefWindowProc(hwnd, message, wparam, lparam);
  }

  return self->WindowProc(message, wparam, lparam);
}

LyricWindowState DesktopLyricWindow::Snapshot() {
  std::lock_guard<std::mutex> lock(mutex_);

  return state_;
}

bool DesktopLyricWindow::Show() {
  if (!created_.load()) {
    if (thread_.joinable()) {
      return false;
    }

    thread_ = std::thread([this]() { ThreadMain(); });

    // Window creation happens on the overlay thread; wait briefly so Show()
    // reports a real answer instead of an optimistic true.
    for (int attempt = 0; attempt < 300 && !created_.load(); attempt++) {
      ::Sleep(10);
    }

    if (!created_.load()) {
      return false;
    }
  }

  const HWND hwnd = hwnd_.load();

  if (!hwnd) {
    return false;
  }

  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_.visible = true;
  }

  ::PostMessage(hwnd, kMessageShow, 0, 0);

  return true;
}

void DesktopLyricWindow::Hide() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_.visible = false;
  }

  const HWND hwnd = hwnd_.load();

  if (hwnd) {
    ::PostMessage(hwnd, kMessageHide, 0, 0);
  }
}

void DesktopLyricWindow::Update(const LyricWindowState& state) {
  const HWND hwnd = hwnd_.load();

  {
    std::lock_guard<std::mutex> lock(mutex_);
    state_.text = state.text;
    state_.translation = state.translation;
    state_.next_line = state.next_line;
    state_.progress = state.progress;
    state_.playing = state.playing;
    state_.has_lyrics = state.has_lyrics;
    state_.font_family = state.font_family;
    state_.font_size = state.font_size;
    state_.text_color = state.text_color;
    state_.stroke_color = state.stroke_color;
    state_.stroke_width = state.stroke_width;
    state_.opacity = state.opacity;
    state_.alignment = state.alignment;

    // `locked` and `visible` are owned by this class: locking has to run the
    // hint timer here, and visibility belongs to Show()/Hide().
    if (state.locked != state_.locked) {
      state_.locked = state.locked;

      if (state_.locked) {
        lock_hint_active_ = true;
        lock_hint_until_ = ::GetTickCount64() + kLockHintMillis;

        if (hwnd) {
          ::SetTimer(hwnd, 1, 100, nullptr);
        }
      } else {
        lock_hint_active_ = false;
        controls_visible_ = true;

        if (hwnd) {
          ::KillTimer(hwnd, 1);
        }
      }
    }
  }

  if (hwnd) {
    ::PostMessage(hwnd, kMessageStateChanged, 0, 0);
  }
}

void DesktopLyricWindow::SetBounds(int x, int y, int width, int height) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    bounds_ = RECT{x, y, x + std::max(200, width), y + std::max(80, height)};
    bounds_explicit_ = true;
  }

  const HWND hwnd = hwnd_.load();

  if (hwnd) {
    ::PostMessage(hwnd, kMessageBoundsChanged, 0, 0);
  }
}

void DesktopLyricWindow::ThreadMain() {
  EnsureGdiplus();
  EnsureWindowClass();

  RECT bounds{};

  {
    std::lock_guard<std::mutex> lock(mutex_);

    if (!bounds_explicit_) {
      // Default: centred horizontally, a bit above the bottom of the primary
      // work area — where a lyric bar is expected and clear of a taskbar.
      RECT work_area{};
      ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

      // RECT members are LONG, so the expression has to come back to int for
      // std::min to find an overload.
      const int width = std::min(
          900, static_cast<int>(work_area.right - work_area.left) - 80);
      const int height = 150;
      const int x =
          work_area.left + ((work_area.right - work_area.left) - width) / 2;
      const int y = work_area.bottom - height -
                    static_cast<int>((work_area.bottom - work_area.top) * 0.12);

      bounds_ = RECT{x, y, x + width, y + height};
    }

    bounds = bounds_;
  }

  const HWND hwnd = ::CreateWindowEx(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED,
      kWindowClassName, L"MediaCore Desktop Lyric", WS_POPUP, bounds.left,
      bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top,
      nullptr, nullptr, ::GetModuleHandle(nullptr), this);

  if (!hwnd) {
    created_ = true;  // Reports failure through hwnd_ == nullptr.

    return;
  }

  hwnd_ = hwnd;
  dpi_scale_ = static_cast<float>(::GetDpiForWindow(hwnd)) / 96.0f;
  created_ = true;

  Paint();

  MSG message{};

  while (::GetMessage(&message, nullptr, 0, 0)) {
    ::TranslateMessage(&message);
    ::DispatchMessage(&message);
  }

  hwnd_ = nullptr;
}

void DesktopLyricWindow::ApplyClickThrough() {
  const HWND hwnd = hwnd_.load();

  if (!hwnd) {
    return;
  }

  const bool click_through = state_.locked && !lock_hint_active_;

  LONG_PTR ex_style = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);

  if (click_through) {
    ex_style |= WS_EX_TRANSPARENT;
  } else {
    ex_style &= ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT);
  }

  ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex_style);

  controls_visible_ = !state_.locked || lock_hint_active_;
}

std::string DesktopLyricWindow::HitTestControls(int x, int y) const {
  if (!controls_visible_) {
    return std::string();
  }

  for (const auto& entry : control_hit_areas_) {
    const Gdiplus::RectF& box = entry.second;

    if (x >= box.X && x <= box.X + box.Width && y >= box.Y &&
        y <= box.Y + box.Height) {
      return entry.first;
    }
  }

  return std::string();
}

LRESULT DesktopLyricWindow::WindowProc(UINT message, WPARAM wparam,
                                       LPARAM lparam) {
  const HWND hwnd = hwnd_.load();

  switch (message) {
    case kMessageStateChanged:
    case kMessageBoundsChanged:
    case kMessageShow: {
      if (!hwnd) {
        return 0;
      }

      if (message == kMessageBoundsChanged) {
        RECT bounds{};

        {
          std::lock_guard<std::mutex> lock(mutex_);
          bounds = bounds_;
        }

        // SWP_NOACTIVATE keeps the overlay from stealing focus.
        ::SetWindowPos(hwnd, HWND_TOPMOST, bounds.left, bounds.top,
                       bounds.right - bounds.left, bounds.bottom - bounds.top,
                       SWP_NOACTIVATE);
      }

      if (message == kMessageShow) {
        ::ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        visible_ = true;
      }

      if (visible_.load()) {
        // Re-assert topmost: another topmost window may have appeared since.
        ::SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
      }

      Paint();

      return 0;
    }

    case kMessageHide: {
      if (hwnd) {
        ::ShowWindow(hwnd, SW_HIDE);
      }

      visible_ = false;

      return 0;
    }

    case kMessageQuit: {
      if (hwnd) {
        ::DestroyWindow(hwnd);
      }

      return 0;
    }

    case WM_MOUSEMOVE: {
      const int x = GET_X_LPARAM(lparam);
      const int y = GET_Y_LPARAM(lparam);

      if (dragging_) {
        POINT cursor{};
        ::GetCursorPos(&cursor);

        ::SetWindowPos(hwnd, HWND_TOPMOST,
                       drag_window_.left + (cursor.x - drag_origin_.x),
                       drag_window_.top + (cursor.y - drag_origin_.y),
                       drag_window_.right - drag_window_.left,
                       drag_window_.bottom - drag_window_.top,
                       SWP_NOACTIVATE);

        return 0;
      }

      if (!hovered_) {
        hovered_ = true;

        TRACKMOUSEEVENT track{};
        track.cbSize = sizeof(track);
        track.dwFlags = TME_LEAVE;
        track.hwndTrack = hwnd;
        ::TrackMouseEvent(&track);

        Paint();
      }

      return 0;
    }

    case WM_MOUSELEAVE: {
      hovered_ = false;
      Paint();

      return 0;
    }

    case WM_LBUTTONDOWN: {
      const int x = GET_X_LPARAM(lparam);
      const int y = GET_Y_LPARAM(lparam);

      pressed_action_ = HitTestControls(x, y);

      if (!pressed_action_.empty()) {
        return 0;
      }

      if (!Snapshot().locked) {
        dragging_ = true;
        ::GetCursorPos(&drag_origin_);

        RECT window{};
        ::GetWindowRect(hwnd, &window);
        drag_window_ = window;
        ::SetCapture(hwnd);
      }

      return 0;
    }

    case WM_LBUTTONUP: {
      if (dragging_) {
        dragging_ = false;
        ::ReleaseCapture();

        return 0;
      }

      if (!pressed_action_.empty()) {
        const std::string action = pressed_action_;
        pressed_action_.clear();

        SetPendingAction(action);
      }

      return 0;
    }

    case WM_TIMER: {
      if (wparam != 1) {
        break;
      }

      if (::GetTickCount64() < lock_hint_until_) {
        break;
      }

      ::KillTimer(hwnd, 1);
      lock_hint_active_ = false;
      ApplyClickThrough();
      Paint();

      return 0;
    }

    case WM_DESTROY:
      ::PostQuitMessage(0);

      return 0;

    case WM_NCHITTEST:
      return HTCLIENT;

    default:
      break;
  }

  return ::DefWindowProc(hwnd, message, wparam, lparam);
}

void DesktopLyricWindow::SetPendingAction(const std::string& action) {
  // The overlay's buttons speak the same action vocabulary as the Dart
  // protocol; only the play/pause pair is drawn from the playing state and has
  // to collapse back to "toggle".
  std::string resolved = action;

  if (resolved == "toggle_play" || resolved == "toggle_pause") {
    resolved = "toggle";
  }

  if (on_action_) {
    on_action_(resolved);
  }
}

void DesktopLyricWindow::Paint() {
  const HWND hwnd = hwnd_.load();

  if (!hwnd) {
    return;
  }

  RECT window{};
  ::GetWindowRect(hwnd, &window);

  const int width = window.right - window.left;
  const int height = window.bottom - window.top;

  if (width <= 0 || height <= 0) {
    return;
  }

  const LyricWindowState state = Snapshot();

  ApplyClickThrough();

  HDC screen_dc = ::GetDC(nullptr);
  HDC memory_dc = ::CreateCompatibleDC(screen_dc);

  BITMAPINFO bitmap_info{};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;  // Top-down.
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP bitmap = ::CreateDIBSection(memory_dc, &bitmap_info, DIB_RGB_COLORS,
                                      &bits, nullptr, 0);

  if (!bitmap) {
    ::DeleteDC(memory_dc);
    ::ReleaseDC(nullptr, screen_dc);

    return;
  }

  HGDIOBJ previous = ::SelectObject(memory_dc, bitmap);

  {
    Gdiplus::Graphics graphics(memory_dc);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAlias);
    // The DIB arrives uninitialised; without clearing, the transparent parts
    // of the overlay show garbage.
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));

    const BYTE panel_alpha = static_cast<BYTE>(
        std::clamp(state.opacity, 0.0, 1.0) * 0x99);

    Gdiplus::SolidBrush panel(Gdiplus::Color(panel_alpha, 0, 0, 0));
    Gdiplus::GraphicsPath panel_path;
    const float radius = 14.0f * dpi_scale_;
    panel_path.AddArc(0.0f, 0.0f, radius * 2, radius * 2, 180.0f, 90.0f);
    panel_path.AddArc(width - radius * 2.0f, 0.0f, radius * 2, radius * 2, 270.0f,
                      90.0f);
    panel_path.AddArc(width - radius * 2.0f, height - radius * 2.0f, radius * 2,
                      radius * 2, 0.0f, 90.0f);
    panel_path.AddArc(0.0f, height - radius * 2.0f, radius * 2, radius * 2, 90.0f,
                      90.0f);
    panel_path.CloseFigure();
    graphics.FillPath(&panel, &panel_path);

    LayoutControls();

    const bool strip = controls_visible_ && (hovered_ || lock_hint_active_);
    const float base = static_cast<float>(state.font_size) * dpi_scale_;
    const float top = strip ? 34.0f * dpi_scale_ : 8.0f * dpi_scale_;

    if (strip) {
      DrawControls(graphics, state);
    }

    const float text_height = base * 1.3f;
    DrawLine(graphics, state.text,
             Gdiplus::RectF(0.0f, top, static_cast<Gdiplus::REAL>(width),
                            text_height),
             base, true, state.text_color, state);

    float cursor = top + text_height;

    if (state.has_lyrics && !state.translation.empty()) {
      DrawLine(graphics, state.translation,
               Gdiplus::RectF(0.0f, cursor, static_cast<Gdiplus::REAL>(width),
                              base * 0.55f),
               base * 0.42f, false, 0xCCFFFFFF, state);
      cursor += base * 0.55f;
    }

    if (state.has_lyrics && !state.next_line.empty() && height > 120) {
      DrawLine(graphics, state.next_line,
               Gdiplus::RectF(0.0f, cursor, static_cast<Gdiplus::REAL>(width),
                              base * 0.45f),
               base * 0.34f, false, 0x88FFFFFF, state);
    }

    if (lock_hint_active_) {
      DrawLine(graphics, L"Locked",
               Gdiplus::RectF(0.0f, 6.0f * dpi_scale_,
                              static_cast<Gdiplus::REAL>(width),
                              22.0f * dpi_scale_),
               14.0f * dpi_scale_, false, 0xE6FFFFFF, state);
    }

    DrawProgress(graphics, state);
  }

  POINT destination{window.left, window.top};
  POINT source{0, 0};
  SIZE size{width, height};
  BLENDFUNCTION blend{};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;

  ::UpdateLayeredWindow(hwnd, screen_dc, &destination, &size, memory_dc, &source,
                        0, &blend, ULW_ALPHA);

  ::SelectObject(memory_dc, previous);
  ::DeleteObject(bitmap);
  ::DeleteDC(memory_dc);
  ::ReleaseDC(nullptr, screen_dc);
}

void DesktopLyricWindow::LayoutControls() {
  control_hit_areas_.clear();

  RECT window{};
  const HWND hwnd = hwnd_.load();

  if (hwnd) {
    ::GetWindowRect(hwnd, &window);
  }

  const float width = static_cast<float>(window.right - window.left);
  const float size = 26.0f * dpi_scale_;
  const float gap = 8.0f * dpi_scale_;
  const char* actions[] = {"previous", "toggle_play", "next", "lock", "close"};
  const size_t count = sizeof(actions) / sizeof(actions[0]);

  const float total =
      static_cast<float>(count) * size + static_cast<float>(count - 1) * gap;
  float x = (width - total) / 2.0f;
  const float y = 4.0f * dpi_scale_;

  for (size_t index = 0; index < count; index++) {
    control_hit_areas_.emplace_back(std::string(actions[index]),
                                    Gdiplus::RectF(x, y, size, size));
    x += size + gap;
  }
}

void DesktopLyricWindow::DrawControls(Gdiplus::Graphics& graphics,
                                     const LyricWindowState& state) {
  for (const auto& entry : control_hit_areas_) {
    std::string action = entry.first;

    if (action == "toggle_play") {
      action = state.playing ? "toggle_pause" : "toggle_play";
    }

    DrawGlyph(graphics, action, entry.second, Gdiplus::Color(0xE6, 255, 255, 255));
  }
}

void DesktopLyricWindow::DrawProgress(Gdiplus::Graphics& graphics,
                                      const LyricWindowState& state) {
  if (!state.has_lyrics) {
    return;
  }

  RECT window{};
  const HWND hwnd = hwnd_.load();

  if (hwnd) {
    ::GetWindowRect(hwnd, &window);
  }

  const float width = static_cast<float>(window.right - window.left);
  const float height = static_cast<float>(window.bottom - window.top);
  const float progress =
      static_cast<float>(std::clamp(state.progress, 0.0, 1.0));

  const float margin = 16.0f * dpi_scale_;
  const float bar_height = 3.0f * dpi_scale_;
  const float y = height - bar_height - 6.0f * dpi_scale_;

  Gdiplus::SolidBrush track(Gdiplus::Color(0x40, 255, 255, 255));
  Gdiplus::SolidBrush fill(Gdiplus::Color(0xCC, 255, 255, 255));

  graphics.FillRectangle(&track, margin, y, width - margin * 2.0f, bar_height);
  graphics.FillRectangle(&fill, margin, y,
                         (width - margin * 2.0f) * progress, bar_height);
}

void DesktopLyricWindow::DrawLine(Gdiplus::Graphics& graphics,
                                  const std::wstring& text,
                                  const Gdiplus::RectF& bounds, float size,
                                  bool bold, std::uint32_t color,
                                  const LyricWindowState& state) {
  if (text.empty()) {
    return;
  }

  const INT style = bold ? Gdiplus::FontStyleBold : Gdiplus::FontStyleRegular;

  // The installed GDI+ only offers AddString(FontFamily*, style, emSize, …) —
  // there is no Font*-based overload — so the family, style and size are passed
  // separately, and the family is chosen before the call.
  Gdiplus::FontFamily family(state.font_family.c_str());
  Gdiplus::FontFamily fallback(L"Segoe UI");
  Gdiplus::FontFamily& effective = family.IsAvailable() ? family : fallback;

  Gdiplus::StringFormat format;
  // The host chooses the anchoring; "center" is the default a lyric line is
  // expected to use, but a left/right setting has to actually do something.
  format.SetAlignment(state.alignment == L"left"
                          ? Gdiplus::StringAlignmentNear
                          : state.alignment == L"right" ? Gdiplus::StringAlignmentFar
                                                        : Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);

  // Inset so left/right anchored text does not touch the panel edge.
  const float inset = 24.0f * dpi_scale_;
  Gdiplus::RectF layout(bounds.X + inset, bounds.Y,
                        std::max(1.0f, bounds.Width - inset * 2.0f),
                        bounds.Height);

  Gdiplus::GraphicsPath path;
  path.AddString(text.c_str(), -1, &effective, style,
                 static_cast<Gdiplus::REAL>(size), layout, &format);

  Gdiplus::SolidBrush brush(ToColor(color));
  Gdiplus::Pen pen(ToColor(state.stroke_color),
                   static_cast<Gdiplus::REAL>(
                       std::max(1.0, state.stroke_width) * dpi_scale_));
  pen.SetLineJoin(Gdiplus::LineJoinRound);

  graphics.FillPath(&brush, &path);
  graphics.DrawPath(&pen, &path);
}

}  // namespace media_core_audio
