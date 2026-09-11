# lifecycle 模块

> 播放器、页面与应用生命周期管理：小型状态机，跟踪生命周期转换并以事件/快照/观察者回调广播。

## 模块职责

- 以布尔旗标的 `LifecycleState` 建模生命周期，并以略细粒度的事件类型广播转换。
- 通知已注册的 `LifecycleObserver`。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerLifecycle` | 接口：`snapshot`、`events` 流、转换方法 `create/initialize/activate/pause/resume/deactivate/detach/dispose` |
| `LifecycleController` | 实现：BehaviorSubject 快照流 + PublishSubject 事件流；每次转换通知观察者；`dispose()` 依序发出 disposing→disposed 后关闭 |
| `LifecycleState` | 不可变布尔旗标状态（created/initialized/active/paused/inactive/detached/disposing/disposed），`markX()` 转换方法与派生判定（`isAlive`、`isReady`、`isTerminal`） |
| `LifecycleEvent` / `LifecycleEventType` | 事件与 9 种事件类型（比状态略细：如 `activated` 与 `resumed` 都映射到 active） |
| `LifecycleObserver` | 单一回调 `onLifecycleEvent` |
| `LifecycleSnapshot` | 状态 + `updatedAt` 时间戳 |

## 设计说明

- 极小模块（约 300 行），自包含，无内部跨模块依赖。

## 依赖

- 外部：`rxdart`、`clock`、`equatable`
