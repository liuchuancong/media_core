# renderer 模块

> Flutter widget 层渲染抽象：播放器的 surface、视图与覆盖层，以及渲染器状态。

## 模块职责

- 提供播放器显示的组合 widget（view、surface、renderer、overlay）。
- `RendererController` 编排渲染状态转换；不创建平台 surface、不控制播放。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerView` | 顶层组合 widget；把实际 surface 委托给 `PlayerSurface` |
| `PlayerSurface` | 平台渲染 surface 槽位（texture/platform view 的创建在别处） |
| `PlayerRenderer` | 组装各视图部件；不做播放控制、不做几何计算 |
| `PlayerOverlay` | 调用方提供的 UI 覆盖层（控制条、加载、手势、弹幕、调试信息） |
| `RendererController` | 编排渲染状态转换 |
| `RendererState` / `RendererConfig` / `RendererCapabilities` | 不可变渲染状态 / 配置与能力描述（仅信息性） |

## 设计说明

- 纯呈现层；每个 widget 都明确声明不做播放控制、平台资源创建与几何计算。无跨模块导入。

## 依赖

- 外部：Flutter widget 框架
