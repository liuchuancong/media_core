# concurrency 模块

> 可复用的异步并发原语：锁、互斥量、信号量、并发上限与串行执行器，以及按 key 共享它们的中心管理器。

## 模块职责

- 提供纯基础设施级的并发控制原语，不含任何业务逻辑。
- 通过 `ConcurrencyManager` 按 `ConcurrencyKey` 跨模块共享同一把锁/信号量/串行器。

## 核心 API

| API | 说明 |
| --- | --- |
| `ConcurrencyManager` | 中心注册表：按 key 取得 `withLock`、mutex、limit 与串行执行器 |
| `AsyncLock` | 单持有者异步锁，附 `synchronized()` 辅助 |
| `Mutex` | 传统 acquire/release 互斥，附 `protect()` |
| `AsyncSemaphore` | 许可计数的并发限制器，附 `withPermit()` |
| `ConcurrencyLimit` | 基于 `package:pool` 的并发桶：maxConcurrent、许可获取、受守护动作 |
| `SerialExecutor` | FIFO 异步任务队列，一次执行一个 |
| `ExclusiveTask` | 独占式任务：链接在上个任务完成之后执行（适合 init、换源） |
| `ConcurrencyKey` | 领域无关的资源标识（`scope:name`），由调用方拥有 |

## 设计说明

- 文档注释明确区分 lock / mutex / limit / serial executor 的适用场景。
- 资源 key 由调用方定义，本模块不感知语义。

## 依赖

- 外部：`package:pool`
