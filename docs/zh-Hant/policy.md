# policy 模塊

> 集中式跨模塊播放器策略:一組普通、不可變的配置/策略對象,是跨模塊播放器行為規則的唯一事實來源。

## 模塊職責

- 聚合 14 個領域策略到 `PolicyContext`,提供 `PolicyContext.defaults()`。
- 策略只描述規則並提供查詢輔助(如 `PreloadPolicy.canPreload(count)`);執行分屬 PreloadManager、Player、Session、Factory 等。

## 核心 API

| API | 說明 |
| --- | --- |
| `PolicyContext` | 聚合全部 14 個策略;`defaults()` 工廠 |
| `PlayerPolicy` | 根策略:組合 `PlaybackPolicy`、`ResourcePolicy`、`RecoveryPolicy`、`ConcurrencyPolicy` + 全局 `enabled` 開關 |
| `PlaybackPolicy` / `PreloadPolicy` | 播放策略 / 預載策略(maxPreloadedPlayers、preloadDuration、warmup、後台預載) |
| `AudioPolicy` / `CachePolicy` / `MemoryPolicy` / `ThermalPolicy` | 音頻 / 緩存 / 內存 / 溫度策略 |
| `LifecyclePolicy` / `VisibilityPolicy` / `FallbackPolicy` / `PresentationPolicy` | 生命週期 / 可見性 / 降級 / 呈現策略 |
| `ConcurrencyPolicy` / `ResourcePolicy` / `RecoveryPolicy` | 並發 / 資源 / 恢復策略 |

## 設計說明

- 全部為小配置類,不可變、無副作用;唯一對外引用是 `presentation` 的模式類型(PresentationPolicy 使用)。

## 依賴

- 內部:`presentation`(僅類型)
