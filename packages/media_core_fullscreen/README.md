# media_core_fullscreen

`media_core` 的全屏能力包：一个驱动同时管住两种"全屏"，并按视频朝向回答该用哪种铺法。

## 定位

两种全屏，缺一不可：

```text
PresentationMode.fullscreen        平台全屏（桌面窗口盖住整屏；移动端隐藏系统 UI）
PresentationMode.windowFullscreen  视频铺满应用窗口，而窗口仍然是一个窗口
```

`FullscreenDriver` 实现 `KernelPresentationDriver`，同时拥有这两种模式，因而也是唯一能保证它们互斥的地方：系统全屏激活时进入窗口全屏会先把系统全屏退掉——这种交接无法交给 `PresentationDriverChain`，它只认识**不同的驱动**。

`FullscreenPlatform`（desktop / mobile / unsupported）解析自 `PlatformUtils`：

- **桌面**：系统全屏是窗口状态，走 `FullscreenWindow` 接口。默认实现是 `WindowManagerFullscreenWindow`（`window_manager`）。宿主窗口若用隐藏标题栏创建，`window_manager.setFullScreen` 的无边框快路径会静默跳过样式与边界更新却仍返回成功——那种窗口必须改用 `Win32FullscreenWindow`：直接 user32 快照 placement、剥掉 caption/thickframe、一次 `SetWindowPos(FRAMECHANGED)` 铺满所在显示器（依赖 [media_core_win32](../media_core_win32)）。
- **移动**：没有窗口可全屏，"全屏"即驱动自己做 `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` 隐藏状态/导航栏；退出恢复。要锁哪个朝向、状态栏样式是演示策略，留在宿主。
- **Web / 其他**：`unsupported`，两种全屏都抛 `UnsupportedError`。

朝向回答通过 `strategy`（`FullscreenFitStrategy`）给出：竖屏视频用 `config.portraitStrategy`、横屏用 `config.landscapeStrategy`；驱动只答不问，宿主把它施加到自己的全屏表面上。

## 用法

```dart
// 装成演示链里负责两个全屏模式的一环。
final fullscreen = FullscreenDriver();
await fullscreen.initialize();
kernel.attachPresentation(PresentationDriverChain(bindings: [
  PresentationDriverBinding(
    modes: {PresentationMode.fullscreen, PresentationMode.windowFullscreen},
    driver: fullscreen,
  ),
]));

await kernel.enterFullscreen(playerId);   // 平台全屏
await kernel.exitFullscreen(playerId);    // 回到 normal，桌面会还原窗口边界

// 宿主自己管 ESC / 返回手势时，直接问驱动，不必合成 request + playerId。
await fullscreen.toggleFullscreen();
if (fullscreen.isAnyFullscreen) { /* 读 fullscreen.strategy 决定铺法 */ }

// 隐藏标题栏的 Windows 窗口：注入原生实现替代 window_manager 桥。
FullscreenDriver(desktopWindow: Win32FullscreenWindow());
```

喂最新视频尺寸用 `onVideoSize(width, height)`，朝向与 `strategy` 随之更新；`onFullscreenChanged` 是稳定后的状态流（一次过渡只发一次，避免交接瞬间闪出非全屏 chrome）。

## 平台支持

| 模式 | Windows | macOS | Linux | Android | iOS | Web |
| --- | --- | --- | --- | --- | --- | --- |
| 平台全屏 `fullscreen` | ✅ 窗口态 | ✅ 窗口态 | ✅ 窗口态 | ✅ 沉浸式系统 UI | ✅ 沉浸式系统 UI | ❌ |
| 窗口全屏 `windowFullscreen` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 直接 user32（`Win32FullscreenWindow`） | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

`windowFullscreen` 只在 `platform == unsupported` 时抛错；`FullscreenConfig.restorePreviousBounds` 仅对桌面有意义（平台不会自己还原边界）。

## 相关文档

- 画中画：[../media_core_pip](../media_core_pip)
- 演示能力与图层：[../media_core_presentation](../media_core_presentation)
- Windows FFI：[../media_core_win32](../media_core_win32)
- 主包与 `PresentationDriverChain`：[../media_core](../media_core)
- 仓库总览：[../../README.md](../../README.md)
