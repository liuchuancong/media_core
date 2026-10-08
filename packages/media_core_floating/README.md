# media_core_floating

`media_core` 的应用内小窗。视频浮在页面之上、可拖拽、贴边、关闭或展开回页面，一套代码覆盖所有平台。

## 定位

[media_core](../media_core) 的 `presentation` 模块定义了逻辑模式 `PresentationMode.floating`；本包负责**把那个模式变成可交互的小窗**：

- `FloatingDriver` —— 实现 `KernelPresentationDriver`，响应 floating / normal 切换，发布 `onFloatingChanged` 流。
- `FloatingSessionController` —— 拥有页面与小窗之间的交接：携带哪个 player、何时自动弹出、如何渲染。
- `FloatingWindowOverlay` —— 一个 Widget，在 `Stack` 顶层显示可拖拽的视频 surface。
- `FloatingWindowPlacement` —— 纯几何：anchor、clamp、snap、resize，不渲染任何东西。
- `FloatingConfig` + `FloatingPlacementConfig` —— 行为与几何参数分离声明。

与 `media_core_pip` 的区别：本包是**应用内** overlay widget，任何 Flutter 渲染平台都能用；`media_core_pip` 管理操作系统窗口，需要平台 API。

## 用法

```dart
// 1. 把 FloatingDriver 挂进内核。
final driver = FloatingDriver(config: FloatingConfig.defaults);
kernel.attachPresentation(driver);

// 2. 创建会话控制器。
final controller = FloatingSessionController.forKernel(
  driver: driver,
  kernel: kernel,
  autoEnter: FloatingAutoEnterPolicy(onPageExit: true, onAppBackground: false),
);

// 3. 页面 Stack 里挂小窗 overlay。
Stack(
  children: [
    currentPage,
    controller.buildOverlay(
      context,
      playerId,
      onExpand: () => kernel.exitFloating(playerId),
    ),
  ],
)

// 4. 页面即将被 pop。
await controller.onPageExit(playerId: playerId, playing: isPlaying);

// 5. 手动 toggle。
await controller.toggle(playerId);
```

## 几何与配置要点

- **anchor**（`FloatingAnchor`）：四角 + centerLeft / centerRight，窗口在未被拖拽时停靠的位置。
- **snap**：拖拽结束后距边缘 `< dragSnapThreshold` 则贴边，否则留在原地。
- **resize**：`resizableByDrag` 开启后由 `resizeHandles`（edge / corner set）决定哪几条边可拖。默认只有 bottomRight。
- **aspect ratio**：`aspectRatioFromVideo` 让窗口形状跟随视频，避免 letterbox 浪费。
- **keepPlayingWhenHidden**：关闭小窗后视频是否继续播——默认 true（用户收起的是窗口不是视频）。

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android / iOS | ✅ overlay widget，无需任何平台 API |
| macOS / Windows / Linux | ✅ 同上 |
| Web | ✅ 同上 |

本包**不含任何平台分支**——一个在页面之上的 Widget 在所有平台上都是同一件事。

## 相关文档

- [media_core](../media_core) —— 主包内核与 presentation 模块
- [media_core_pip](../media_core_pip) —— 操作系统窗口级画中画
- [media_core_fullscreen](../media_core_fullscreen) —— 全屏与 window fullscreen
- [项目总览](../../README.md)
