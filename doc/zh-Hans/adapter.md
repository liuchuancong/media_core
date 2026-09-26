# adapter 模块

> 后端无关的播放器适配器抽象：定义统一的播放引擎合约（PlayerAdapter）、工厂、注册表与能力选择。

## 模块职责

- 定义 `PlayerAdapter` 统一合约，让 media_kit、native、video_player 等具体播放引擎以相同方式接入。
- 提供适配器的创建（Factory）、注册与查找（Registry）、以及基于能力的候选选择（Selector）。
- 定义适配器层的事件、状态、指标与能力描述等值对象。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerAdapter` | 播放后端的抽象合约：`open/play/pause/stop/seek/setVolume/setRate/close/dispose`，暴露 `state`、`events`、`metrics`、`capabilities` |
| `PlayerAdapterFactory` / `DefaultPlayerAdapterFactory` | 按标识创建适配器实例；注册匿名创建函数，隐藏具体实现 |
| `PlayerAdapterRegistry` / `PlayerAdapterRegistration` | 存储适配器元数据（id、工厂、能力、优先级、启用状态），只负责查找 |
| `PlayerAdapterSelector` | 依据能力（live/seek/协议/格式）与优先级为 `SourceDescriptor` 选出最佳适配器，并提供候补列表 |
| `PlayerAdapterCapabilities` | 静态能力描述：直播、seek、PiP、硬解、支持的协议与格式 |
| `PlayerAdapterEvent` | 后端事件闭集（freezed）：opened/playing/paused/buffering/completed/position/duration/videoSize/volume/rate/error |
| `PlayerAdapterState` / `PlayerAdapterConfig` / `PlayerAdapterContext` / `PlayerAdapterError` / `PlayerAdapterMetrics` | 周边不可变值对象 |

## 设计说明

- 严格单一职责：Adapter 执行、Factory 创建、Registry 存储、Selector 决策。
- 降级（fallback）处理委托给 `fallback` 模块的 `FallbackManager`，本模块只产生候选顺序。
- 事件提供 `isError` / `affectsPlayback` / `affectsGeometry` 等判定扩展。

## 依赖

- 内部：`core`（PlayerState）、`source`（PlayerSource / SourceDescriptor）
- 外部：`freezed`、`equatable`
