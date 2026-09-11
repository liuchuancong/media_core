# Media Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-compatible-02569B.svg)](https://flutter.dev)

> 一套面向 Flutter/Dart 的模块化媒体播放核心：以后端无关的方式抽象播放器、音视频会话、资源、缓存、并发、降级、恢复、呈现与可观测性。
>
> A modular media playback core for Flutter/Dart: backend-agnostic abstractions for players, audio/video sessions, resources, caching, concurrency, fallback, recovery, presentation, and observability.
>
> 一套面向 Flutter/Dart 的模組化媒體播放核心：以後端無關的方式抽象播放器、音視訊會話、資源、快取、併發、降級、恢復、呈現與可觀測性。

- 仓库 / Repository: https://github.com/liuchuancong/media_core
- 许可证 / License: MIT

> 其他语言版本 · Other languages: [English](README.en.md) · [繁體中文](README.zh-Hant.md)

---

## 简体中文

### 简介

Media Core 不是一个单一的播放器插件，而是一组**职责清晰、边界严格、可组合**的模块。它把播放器能力拆分为核心领域模型、适配器、工厂、会话、播放控制、音频、缓存、并发、网络、资源、策略、降级、恢复、呈现、渲染、事件、操作、任务、状态机等子系统，并通过协调层把它们组合起来。

**设计目标：**

- **后端无关**：media_kit、native、video_player、ExoPlayer、VLC 等都可以通过适配器接入。
- **单一职责**：Adapter 执行、Factory 创建、Registry 存储、Selector 决策、Coordinator 只转发。
- **可测试**：大量使用 `clock`、不可变值对象、注入式接口与故障注入。
- **可扩展**：错误码、故障类型、任务类型、操作类型等刻意使用值对象而非封闭 enum。
- **可观测**：状态、指标、事件、快照贯穿各模块。

### 模块文档

| 模块 | 说明 |
| --- | --- |
| [`adapter`](./adapter.md) | 后端无关的播放器适配器抽象：统一播放引擎合约、工厂、注册表与能力选择 |
| [`audio`](./audio.md) | 平台无关音频子系统：音频焦点、会话、输出路由、音量与静音 |
| [`bug`](./bug.md) | 调试与故障注入：Bug 模式、故障配置、Hook、注入器、调度器与场景 |
| [`cache`](./cache.md) | 通用二级缓存：内存 + 可插拔存储、驱逐策略、过期、指标与状态 |
| [`concurrency`](./concurrency.md) | 异步并发原语：锁、互斥量、信号量、并发上限与串行执行器 |
| [`coordinator`](./coordinator.md) | 跨模块协调层：按 PlayerId 绑定并转发请求，自身不执行操作 |
| [`core`](./core.md) | 播放器领域模型公共核心：身份、状态、配置、选项、能力、信息、指标、错误与快照 |
| [`error`](./error.md) | 错误体系：错误码/分类、分类器、格式化器、重试/降级策略决策与失败对象 |
| [`event`](./event.md) | 播放器事件定义、总线与分发：只负责事件传输 |
| [`factory`](./factory.md) | 播放器/后端工厂：后端注册表、基于能力的后端选择、播放器创建入口 |
| [`fallback`](./fallback.md) | 降级机制：后端实现、播放线路 URL、清晰度档位三个维度的退化/重试生命周期 |
| [`geometry`](./geometry.md) | 视频几何：视频/显示尺寸、宽高比、旋转、方向、像素密度与几何状态控制器 |
| [`identity`](./identity.md) | 跨模块共享的强类型不可变标识值对象 |
| [`lifecycle`](./lifecycle.md) | 播放器、页面与应用生命周期：小型状态机、事件、快照与观察者 |
| [`network`](./network.md) | 网络抽象：连通性状态/条件/类型/质量、性能指标与请求/响应执行 |
| [`operation`](./operation.md) | 高层异步/业务操作：不可变生命周期记录、注册表、追踪器、取消令牌与超时策略 |
| [`platform`](./platform.md) | 平台能力与平台特定抽象：纯描述性值类型 |
| [`playback`](./playback.md) | 播放控制：播放命令、状态、进度、时长与选项 |
| [`policy`](./policy.md) | 集中式跨模块播放器策略：跨模块行为规则的唯一事实来源 |
| [`pool`](./pool.md) | 播放器实例池：实例分配、闲置回收、指标与状态流 |
| [`preload`](./preload.md) | 媒体预载：基于优先级的预载任务调度、预热与生命周期管理 |
| [`presentation`](./presentation.md) | 呈现模式：全屏、画中画与悬浮窗的 Redux 风格状态机 |
| [`reactive`](./reactive.md) | 响应式抽象与流工具：基于 rxdart 的共享工具箱 |
| [`reconciler`](./reconciler.md) | 期望状态与实际状态调和：产生宣告式收敛动作计划 |
| [`recording`](./recording.md) | 录制抽象：录制会话、格式与后端 |
| [`recovery`](./recovery.md) | 播放恢复：失败后决定并调度恢复动作 |
| [`renderer`](./renderer.md) | Flutter widget 层渲染抽象：surface、视图、覆盖层与渲染器状态 |
| [`resource`](./resource.md) | 资源管理：解码器、内存、带宽与温度资源的预算、分域管理器与压力计算 |
| [`result`](./result.md) | 统一、不可变、基于值的结果类型：同步 Result、异步 AsyncResult 与操作级 OperationResult |
| [`session`](./session.md) | 播放会话：生命周期、上下文、状态、事件与操作 |
| [`slot`](./slot.md) | 逻辑播放器槽位：槽位所有权、分配与状态 |
| [`source`](./source.md) | 媒体源抽象：描述、解析、探测、校验与已解析元数据 |
| [`state_machine`](./state_machine.md) | 通用领域无关状态机基础设施：状态、事件、转换与编排 |
| [`task`](./task.md) | 可调度任务执行：任务值对象、优先级队列、调度器与生命周期管理器 |
| [`util`](./util.md) | 通用可复用静态工具集：无领域逻辑、无跨模块依赖 |
| [`visibility`](./visibility.md) | 播放器可见性观察与管理：跟踪可见性并发出事件 |

### 快速开始

在 `pubspec.yaml` 中添加以下依赖，然后运行 `flutter pub get`：

```yaml
dependencies:
  media_core:
    git:
      url: https://github.com/liuchuancong/media_core.git
```


