# pool 模块

> 播放器实例池：按 id 跟踪的实例分配、闲置回收、指标与状态流。

## 模块职责

- 管理池内播放器实例到会话的分配与闲置回收。
- 发布池状态流并跟踪池指标。
- 不自行创建或销毁播放器——那属于 PlayerFactory / PlayerSession。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerPool` | 公开门面：`states` 流、`state`、`snapshot`、`count`、`add` 及获取/释放式操作；隐藏内部协调 |
| `PlayerPoolManager` | 协调 allocator + recycler；维护 `_players/_active/_sessions`；BehaviorSubject 发布 `PlayerPoolState`；跟踪 `PlayerPoolMetrics` |
| `PlayerPoolAllocator` | 为会话挑选可用播放器（默认先到先得）；`selectCandidate` 是自定义策略的覆写点 |
| `PlayerPoolRecycler` | 决定哪些闲置播放器可安全回到 idle（默认最多回收 maxCount 个） |
| `PlayerPoolConfig` | freezed 配置：maxPlayers、initialSize、lazyCreate、enableRecycle、idleTimeout、keepWarm、warmSize、maxActivePlayers |
| `PlayerPoolState` / `PlayerPoolSnapshot` / `PlayerPoolMetrics` | 状态 / 只读快照 / 指标值对象（freezed） |

## 设计说明

- 与 `slot` 模块（逻辑槽位）和 `factory` 模块（物理创建）互相分离；池只做复用调度。

## 依赖

- 内部：`identity`（PlayerId、SessionId）
- 外部：`rxdart`、`freezed`、`clock`
