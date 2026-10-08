## 0.1.0

Initial release.

- Direct user32 FFI bindings for window-state operations, bypassing `window_manager`'s frameless fast path that silently skips style and bounds updates on custom-chrome windows while still reporting success.
- Window discovery: `mainWindowHandle()` locates the Flutter runner window by class name (`FLUTTER_RUNNER_WIN32_WINDOW`) and verifies ownership via `GetWindowThreadProcessId` + `GetCurrentProcessId`, safe for multi-instance hosts.
- Screen fullscreen: `setScreenFullscreen` follows the proven `fullscreen_window` sequence — strip WS_CAPTION / WS_THICKFRAME / WS_MAXIMIZE, fill `MonitorFromWindow` + `GetMonitorInfoW` rcMonitor with `SetWindowPos(SWP_FRAMECHANGED)`, and restore by replaying the captured placement.
- Snapshot/restore: `capture()` reads `GetWindowPlacement`, `GetWindowLongPtrW` (style/ex-style) and `IsZoomed` into an immutable `Win32WindowSnapshot`; `restoreSnapshot()` replays via `SetWindowPlacement` + `SetWindowLongPtrW` + forced relayout.
- Frameless bounds move: `applyBounds(hwnd, rect, topmost:)` moves and resizes in a single `SetWindowPos` without touching style bits, keeping the host's custom chrome intact.
- PiP operations: `setTopmost` (HWND_TOPMOST / NOTOPMOST z-order toggle), `setResizable` (WS_THICKFRAME), `setSkipTaskbar` (WS_EX_TOOLWINDOW), `setRoundedCorners` (DWM `DWMWA_WINDOW_CORNER_PREFERENCE`), `startDragging` (`ReleaseCapture` + `SendMessageW(WM_NCLBUTTONDOWN, HTCAPTION)`).
- All methods guard against a zero handle and return false/null rather than dereferencing, verified by the test suite on non-Windows CI.
- 64-bit only: binds `GetWindowLongPtrW` / `SetWindowLongPtrW`, matching the shipped build target.
