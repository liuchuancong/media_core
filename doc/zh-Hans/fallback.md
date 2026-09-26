# fallback 模块

> 降级机制：在三个维度（后端实现、播放线路 URL、清晰度档位）上协调退化/重试生命周期。

## 模块职责

- 以三套相同的状态机模式分别管理后端、线路、清晰度的候选遍历。
- 由 `FallbackManager` 持有活动上下文，把具体选择委托给三个协调器。
- 提供语义化的降级原因与关联 id。

## 核心 API

| API | 说明 |
| --- | --- |
| `BackendFallback` / `BackendFallbackState` | 后端 id 候选遍历：`start/next/markFailed/complete/exhaust/reset` |
| `LineFallback` / `LineFallbackState` | 播放线路 id 的同模式遍历 |
| `QualityFallback` / `QualityFallbackState` | 清晰度 id 的同模式遍历 |
| `FallbackManager` | 持有活动 `FallbackContext`，提供 `success` / `failure` 结果工厂；委托三个协调器 |
| `FallbackContext` | 降级请求的原因 + 关联 id（operationId/requestId/sourceId/generationId）+ message/metadata |
| `FallbackReason` | sealed 原因：unknown/backend/line/quality/network/decoder/renderer/timeout；仅描述，不决定策略 |
| `FallbackResult` | 成功携带 target；失败携带诊断信息 |

## 设计说明

- 状态为不可变 Equatable，支持 `toMap`/`fromMap`；被选中的候选会从候选集中移除。
- `exhausted` 意为「一次失败后再无候选」——仅选中最后一个候选并不算耗尽。
- 协调器不创建后端、不打开媒体、不控制播放。

## 依赖

- 内部：`identity`
