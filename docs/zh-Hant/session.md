# session 模塊

> 播放會話:生命週期、上下文、狀態、事件與操作——把播放器實例與媒體源綁定起來的編排單元。

## 模塊職責

- 定義 `PlayerSession`(一次播放會話)及其運行控制與管理。
- 提供 `SessionGeneration` 單調代際防護:換源/重建/重試/降級後的過期會話不得影響新會話。
- 記錄會話狀態、生命週期、事件與操作。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerSession` | 一次播放會話;不創建播放器(屬 PlayerFactory/PlayerAdapter/PlaybackController) |
| `SessionController` | 會話狀態的運行控制 |
| `SessionManager` | 管理多個會話;不直接控制 adapter |
| `SessionContext` / `SessionState` / `SessionStatus` | 上下文 / 不可變狀態與狀態枚舉 |
| `SessionLifecycle` / `SessionLifecyclePhase` | 會話生命週期與階段枚舉 |
| `SessionGeneration` | Comparable 單調代際守衛,攔截過期會話的影響 |
| `SessionOperation` / `SessionOperationType` / `SessionOperationState` | 被跟蹤的會話操作;無重試策略 |
| `SessionEvent` / `SessionEventType` | 不可變事件記錄 |
| `SessionSnapshot` | freezed 只讀狀態視圖 |

## 依賴

- 內部:`identity`(各類 id)、`source`(player_source.dart)、`policy`(player_policy.dart)、`platform`(platform_capabilities.dart)
