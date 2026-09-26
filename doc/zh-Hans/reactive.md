# reactive 模块

> 响应式抽象与流工具：基于 rxdart 的共享工具箱，供控制器、仓库、服务与播放器管理器使用；不依赖 Flutter。

## 模块职责

- 统一的主体（subject）抽象与静态工厂。
- 提供并发/时序控制（互斥、闸门、队列、调度器）。
- 提供状态/结果包装、流操作符与生命周期辅助。

## 核心 API（节选）

| API | 说明 |
| --- | --- |
| `Reactive` | 静态工厂门面（广播/单订阅控制器）；底层仍是 rxdart |
| `ReactiveSubject<T>` / `ReactiveBehavior<T>` | 同为 Stream+Sink 的主体接口 / BehaviorSubject 背书、总能给出最新值 |
| `StreamMutex` / `StreamGate` / `StreamQueue` | 异步互斥（串行 `run()`）/ 忽略过期异步操作的闸门 / 串行任务队列 |
| `StreamScheduler` | 可 dispose 安全的延迟/周期调度器 |
| `StreamState` / `StreamResult` / `StreamSafe` / `StreamSafeResult` | 状态持有 / 异步操作状态与结果 / 错误转结果的包装辅助 |
| `debounce` / `throttle` / `combine` / `distinct` / `stream_transform` / `stream_extensions` | 流操作符与扩展 |
| `stream_disposable` / `stream_cancellation` / `stream_lifecycle` / `stream_cache` / `stream_retry` / `stream_debouncer` 等 | 可释放资源管理、取消、生命周期、带 TTL 内存缓存、重试配置等辅助 |

## 设计说明

- 定位是包装 rxdart 而非取代它；所有工具都是 dispose 感知的。
- 叶子模块，无内部跨模块依赖。

## 依赖

- 外部：`rxdart`、`dart:async`
