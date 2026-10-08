# media_core_pip

`media_core` 的画中画能力包：一个特性、一份契约、背后三个平台家族——桌面是常驻小窗，Android 是系统 PiP 窗口，iOS 如实回答"不支持"而不是假装。

## 定位

```text
desktop → 常驻顶部、按视频比例成形的小窗
  Windows    → Win32PipWindow（直接 user32 调用，无插件）
  macOS/Linux→ WindowManagerPipWindow（window_manager 插件）
  选择        → defaultDesktopPipWindow()，宿主可按平台注入
android → 平台自己的 PiP 窗口（FloatingSystemPip）
iOS     → 没有可被 Flutter 任意内容使用的系统 PiP API，
          因此 availability 报 false，而不是假装能进
```

`PipDriver` 实现 `KernelPresentationDriver`，只服务 `PresentationMode.pip`；被 `PresentationDriverChain` 路由，其余模式（全屏、应用内小窗）交给别的驱动。桌面是应用完全掌控的窗口：抓快照、缩进角落、退出时还原。移动是平台自己的 PiP，三条平台事实被如实尊重：

- PiP **可请求但无法从 Dart 退出**——`normal` 撤销不了它，状态跟随系统自己的 `statusStream`；
- Android 只接受 1/2.39..2.39 的比例，极端比例退回插件默认形状而非让整个请求失败；
- 该插件仅 Android，iOS 报 unavailable。

`DisplayAwarePipWindow` 把桌面摆放策略（多显示器感知、记住边界、最小尺寸释放、回滚）叠在宿主选定的 `PipWindow` 后端之上。无法服务的请求抛 `UnsupportedError`，而非静默不动——演示状态机会记下一次失败过渡，宿主能告诉用户为什么什么都没发生。

## 依赖：请注意这两处

- **Android 的 PiP 后端来自 git 依赖，不是 pub.dev。** `floating` 是 pub.dev 同名包的**已打补丁分叉**（AGP 9 内建 Kotlin 构建 + `FloatingSystemPip` 轮询修复；改动清单见 [../floating/PATCHES.md](../floating/PATCHES.md)）。一个依赖只能有一个来源，而 `floating` 这个名字在 pub.dev 已被占用，所以这里只能走 git：
  ```yaml
  floating:
    git:
      url: https://github.com/liuchuancong/floating.git
      ref: main
  ```
  **pub.dev 上的消费者会直接拉到这个 git 依赖**——需要能访问该仓库；离线或镜像受限的环境要自备 `dependency_overrides` 或 `pub cache`。本仓库工作区里 `packages/floating` 的副本仅在本地解析时遮蔽它，对外发布不改变这一点。
- **`media_core_win32`** 提供 `Win32PipWindow` 的直接 user32 FFI 通路（`window_manager` 的无边框快路径会跳过样式更新、其 `setSkipTaskbar` 有过崩溃报告，原生路径两者都没有）。

## 用法

```dart
// 装成演示链里负责 PiP 的一环。
final pip = PipDriver();
await pip.initialize();            // 移动端会订阅系统 PiP 状态流
kernel.attachPresentation(PresentationDriverChain(bindings: [
  PresentationDriverBinding(modes: {PresentationMode.pip}, driver: pip),
]));

await kernel.enterPip(playerId);
if (await pip.isAvailable) { /* 桌面恒 true；移动端问平台 */ }

// 移动路径需要先喂尺寸，否则 enable 抛 StateError。
pip.onVideoSize(1920, 1080);
pip.onVideoRect(videoRectOnScreen);   // 仅作进入动画的来源提示

// 宿主自己管关闭 / 双击 PiP 表面时，直接问驱动。
await pip.togglePip();

// 桌面小窗的默认后端可替换：
PipDriver(desktopWindow: const WindowManagerPipWindow());   // 或 Win32PipWindow()
```

`PipConfig` 是调参入口：`width`/`height`（桌面小窗长短边，横屏流得 320x180、竖屏流得 180x320）、`minWidth`/`minHeight`、`cornerSpacing`、`skipTaskbar`、`title`、`restoreWindowOnExit`、`lockAspectRatio`、`requestSourceRectHint`（仅移动端、纯观感）。

## 平台支持

| 路径 | Windows | macOS | Linux | Android | iOS | Web |
| --- | --- | --- | --- | --- | --- | --- |
| 桌面小窗 | ✅ `Win32PipWindow` | ✅ `WindowManagerPipWindow` | ✅ `WindowManagerPipWindow` | — | — | — |
| 系统 PiP | — | — | — | ✅ `FloatingSystemPip`（见上） | ❌ 报 unavailable 并抛 `UnsupportedError` | ❌ |

## 相关文档

- 全屏：[../media_core_fullscreen](../media_core_fullscreen)
- 应用内悬浮窗（widget 而非窗口）：[../media_core_floating](../media_core_floating)
- Windows FFI：[../media_core_win32](../media_core_win32)
- `floating` 补丁说明：[../floating/PATCHES.md](../floating/PATCHES.md)
- 主包与 `PresentationDriverChain`：[../media_core](../media_core)
- 仓库总览：[../../README.md](../../README.md)
