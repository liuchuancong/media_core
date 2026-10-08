# media_core_win32

`media_core` 桌面呈现层的底层 Win32 FFI 模块：直接调 user32 完成 snapshot/restore、frameless bounds move、screen fullscreen，绕开 `window_manager` 对 frameless 窗口的不可靠 fast path。

## 定位

[media_core](../media_core) 的 fullscreen 和 PiP 呈现需要在 Windows 上操作原生窗口状态。`window_manager` 插件对自定义 chrome（hidden title bar）的窗口走了一条 frameless fast path：进入该路径后，其原生 `setFullScreen` / `setBounds` 会**静默跳过** style 与 bounds 更新、却仍然报告成功。这使上层无法区分"生效了"和"被跳过了"。

本包用 `dart:ffi` 直接绑定 user32.dll，不经过插件、不经过 MethodChannel：

| user32 函数 | 用途 |
| --- | --- |
| `FindWindowW` / `FindWindowExW` | 按类名 `FLUTTER_RUNNER_WIN32_WINDOW` 定位本进程窗口 |
| `GetWindowThreadProcessId` | 验证找到的 hwnd 属于当前进程（多实例安全） |
| `GetWindowLongPtrW` / `SetWindowLongPtrW` | 读写 GWL_STYLE / GWL_EXSTYLE（caption、thickframe、topmost、toolwindow 等位） |
| `SetWindowPos` | 原子化移动 + resize + frame 重算（`SWP_FRAMECHANGED`） |
| `GetWindowPlacement` / `SetWindowPlacement` | 快照/恢复完整 placement（showCmd、min/max position、normal rect） |
| `MonitorFromWindow` / `GetMonitorInfoW` | 获取窗口所在 monitor 的 rcMonitor，用于 fullscreen |
| `IsZoomed` | 进入 fullscreen 前记录是否最大化，退出时决定是否先 SC_RESTORE |
| `GetWindowRect` | 读取当前窗口边界 |
| `SendMessageW` | `WM_NCLBUTTONDOWN(HTCAPTION)` 启动原生拖拽循环、`WM_SYSCOMMAND(SC_RESTORE)` 取消最大化、`WM_GETTEXT` / `WM_GETTEXTLENGTH` 读取标题 |
| `ReleaseCapture` | 在发起原生 drag 前释放 Flutter 持有的 mouse capture |

另外：
- **kernel32.dll** `GetCurrentProcessId` —— 与 `GetWindowThreadProcessId` 配合做 pid 校验。
- **dwmapi.dll** `DwmSetWindowAttribute` —— Windows 11 圆角（`DWMWA_WINDOW_CORNER_PREFERENCE`）。

## 用法

```dart
if (!Win32WindowFfi.isSupported) return;

// 找到本进程的 Flutter runner 窗口。
final hwnd = Win32WindowFfi.mainWindowHandle();
if (hwnd == null) return;

// 进入 screen fullscreen：先 snapshot，再操作。
final snapshot = Win32WindowFfi.capture(hwnd);
Win32WindowFfi.setScreenFullscreen(hwnd, fullscreen: true, snapshot: snapshot);

// 退出：replay snapshot。
Win32WindowFfi.setScreenFullscreen(hwnd, fullscreen: false, snapshot: snapshot);

// PiP 小窗：move + topmost + 圆角 + 禁止 resize。
Win32WindowFfi.setResizable(hwnd, resizable: false);
Win32WindowFfi.setRoundedCorners(hwnd, round: true);
Win32WindowFfi.applyBounds(hwnd, pipRect, topmost: true);

// 原生拖拽（无标题栏时唯一可行路径）。
Win32WindowFfi.startDragging(hwnd);

// 切换 skip-taskbar（WS_EX_TOOLWINDOW 位 + frame relayout）。
Win32WindowFfi.setSkipTaskbar(hwnd, skip: true);
```

## 设计约束

- **仅绑定 64-bit**：使用 `GetWindowLongPtrW`（非 32-bit 的 `GetWindowLongW`），与项目实际构建目标一致。
- **零 handle 容错**：所有方法在 `hwnd == 0` 时直接返回 null / false，不触碰指针。
- **`_forceRelayout`**：每次 style bit 修改后发一次同 rect 的 `SetWindowPos(SWP_FRAMECHANGED)`，确保 Windows 应用新 frame；这是 fullscreen_window 插件验证过的序列。
- **snapshot 不可变**：`Win32WindowSnapshot` 只读私有字段，restore 是唯一消费路径，防止中途状态不一致。

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Windows (x64) | ✅ 唯一目标 |
| 其他平台 | `isSupported` 返回 false；所有方法安全空转 |

## 相关文档

- [media_core_fullscreen](../media_core_fullscreen) —— 消费方：全屏呈现层
- [media_core_pip](../media_core_pip) —— 消费方：系统画中画 / compact window
- [media_core](../media_core) —— 主包 presentation 模块契约
- [项目总览](../../README.md)
