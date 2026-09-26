# event 模块

> 播放器事件的定义、总线与分发：只负责事件传输，不含任何业务逻辑。

## 模块职责

- 定义 media core 对外发出的不可变事件值。
- 提供中心事件总线与分发器，支持过滤订阅与一次性直达投递。
- 携带关联元数据（`EventContext`），便于跨模块追踪。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerEvent` | sealed 事件基类：携带 `type`、可选 `EventContext`、`priority`；子类含 `GenericPlayerEvent`、`PlayerErrorEvent`、`PlayerLifecycleEvent` |
| `PlayerEventBus` | 广播总线：`publish/publishAll`、`subscribe/subscribeOnce`、`next(filter)`、`dispose`；内部委托 `EventDispatcher` |
| `EventDispatcher` | 注册过滤订阅；`dispatchTo` 一次性直达投递；`cancelAll`、`dispose` |
| `EventContext` | 关联元数据（playerId/sessionId/slotId/sourceId/operationId/requestId/generationId + metadata + 时间戳） |
| `EventFilter` | 过滤器接口；实现：`AllowAllEventFilter`、`EventTypeFilter`、`EventPriorityFilter`、`EventContextFilter`、`CompositeEventFilter`（可组合） |
| `EventPriority` / `EventPriorityValue` | 优先级枚举（low/normal/high/critical）与排序包装 |
| `PlayerEventType` | 17 个事件类别枚举（player、session、source、playback、buffering、renderer、audio、presentation、recovery、fallback、cache、recording、visibility、lifecycle、error、diagnostics、unknown） |

## 设计说明

- 事件是不可变值；总线/分发器只管传输；订阅（`EventSubscription`）只管投递配置（暂停/恢复/取消）。

## 依赖

- 内部：`identity`（全部七种 id）
- 外部：`clock`、`equatable`
