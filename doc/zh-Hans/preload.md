# preload 模块

> 媒体预载：基于优先级的预载任务调度、预热与生命周期管理（以源为 key）。

## 模块职责

- 维护预载任务表，按优先级排序出队执行。
- 对外暴露指标流与任务生命周期操作。

## 核心 API

| API | 说明 |
| --- | --- |
| `PreloadManager` | 任务表管理者：`metrics` 流（BehaviorSubject）、`add(PreloadRequest)`、`next()`、`complete(task)`、`fail(task)` |
| `PreloadScheduler` | 维护按优先级排序的任务列表；`add` 置为 queued 并按优先级降序重排，`next()` 弹出队首 |
| `PreloadPriority` | 枚举：low / normal / high / critical |
| `PreloadRequest` / `PreloadTask` | sourceId + 优先级的请求 / 带生命周期转换的可运行任务 |
| `PreloadState` | pending/loading/completed/failed/cancelled 旗标，`queued()/start()` 转换辅助 |
| `PreloadMetrics` / `PreloadContext` | 计数器 / 上下文对象 |

## 设计说明

- 行为上限（最大预载数、warmup、后台预载）由 `policy` 模块的 `PreloadPolicy` 提供。

## 依赖

- 内部：`identity`（SourceId）
- 外部：`rxdart`、`equatable`
