# pool 模塊

> 播放器實例池:按 id 跟蹤的實例分配、閒置回收、指標與狀態流。

## 模塊職責

- 管理池內播放器實例到會話的分配與閒置回收。
- 發布池狀態流並跟蹤池指標。
- 不自行創建或銷毀播放器——那屬於 PlayerFactory / PlayerSession。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerPool` | 公開門面:`states` 流、`state`、`snapshot`、`count`、`add` 及獲取/釋放式操作;隱藏內部協調 |
| `PlayerPoolManager` | 協調 allocator + recycler;維護 `_players/_active/_sessions`;BehaviorSubject 發布 `PlayerPoolState`;跟蹤 `PlayerPoolMetrics` |
| `PlayerPoolAllocator` | 為會話挑選可用播放器(默認先到先得);`selectCandidate` 是自定義策略的覆寫點 |
| `PlayerPoolRecycler` | 決定哪些閒置播放器可安全回到 idle(默認最多回收 maxCount 個) |
| `PlayerPoolConfig` | freezed 配置:maxPlayers、initialSize、lazyCreate、enableRecycle、idleTimeout、keepWarm、warmSize、maxActivePlayers |
| `PlayerPoolState` / `PlayerPoolSnapshot` / `PlayerPoolMetrics` | 狀態 / 只讀快照 / 指標值對象(freezed) |

## 設計說明

- 與 `slot` 模塊(邏輯槽位)和 `factory` 模塊(物理創建)互相分離;池只做複用調度。

## 依賴

- 內部:`identity`(PlayerId、SessionId)
- 外部:`rxdart`、`freezed`、`clock`
