# policy 模块

> 集中式跨模块播放器策略：一组普通、不可变的配置/策略对象，是跨模块播放器行为规则的唯一事实来源。

## 模块职责

- 聚合 14 个领域策略到 `PolicyContext`，提供 `PolicyContext.defaults()`。
- 策略只描述规则并提供查询辅助（如 `PreloadPolicy.canPreload(count)`）；执行分属 PreloadManager、Player、Session、Factory 等。

## 核心 API

| API | 说明 |
| --- | --- |
| `PolicyContext` | 聚合全部 14 个策略；`defaults()` 工厂 |
| `PlayerPolicy` | 根策略：组合 `PlaybackPolicy`、`ResourcePolicy`、`RecoveryPolicy`、`ConcurrencyPolicy` + 全局 `enabled` 开关 |
| `PlaybackPolicy` / `PreloadPolicy` | 播放策略 / 预载策略（maxPreloadedPlayers、preloadDuration、warmup、后台预载） |
| `AudioPolicy` / `CachePolicy` / `MemoryPolicy` / `ThermalPolicy` | 音频 / 缓存 / 内存 / 温度策略 |
| `LifecyclePolicy` / `VisibilityPolicy` / `FallbackPolicy` / `PresentationPolicy` | 生命周期 / 可见性 / 降级 / 呈现策略 |
| `ConcurrencyPolicy` / `ResourcePolicy` / `RecoveryPolicy` | 并发 / 资源 / 恢复策略 |

## 设计说明

- 全部为小配置类，不可变、无副作用；唯一对外引用是 `presentation` 的模式类型（PresentationPolicy 使用）。

## 依赖

- 内部：`presentation`（仅类型）
