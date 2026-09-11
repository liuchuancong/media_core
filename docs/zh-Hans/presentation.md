# presentation 模块

> 呈现模式：全屏、画中画与悬浮窗的 Redux 风格状态机，与播放状态及平台 API 解耦。

## 模块职责

- 管理 normal / fullscreen / pip / floating 四种呈现模式（模式切换永不影响播放本身）。
- 控制器/reducer 为纯函数；所有原生操作经 `PresentationAdapter` 进行。
- 以 generation 同步机制丢弃过期的异步回调。

## 核心 API

| API | 说明 |
| --- | --- |
| `PresentationMode` | 枚举：normal、fullscreen、pip |
| `PresentationController` | 核心状态机：BehaviorSubject 持有状态，接收请求、reduce 事件 |
| `PresentationReducer` | 纯 `(state, event) -> state`，忽略 generation 低于当前的事件 |
| `PresentationEvent` / `PresentationState` / `PresentationRequest` / `PresentationSnapshot` / `PresentationCapabilities` | 事件/状态/请求/快照/能力值对象（freezed） |
| `PresentationService` | 应用层 API：配对 Controller 与 `PresentationAdapter`，把适配器事件桥接进控制器 |
| `PresentationAdapter` / `PresentationAdapterBase` | 平台实现的适配器接口 + 基类（事件流、能力变化、生命周期） |
| `PresentationManager` / `PresentationDispatcher` | 高层门面 / 请求路由到各模式控制器 |
| `FullscreenController`、`PipController`、`FloatingController` | 各模式子控制器及 freezed 状态 |

## 设计说明

- 严格分层：controller/reducer 纯；原生操作全部走 adapter。
- 被 `policy` 模块的 `PresentationPolicy` 引用。

## 依赖

- 外部：`rxdart`、`freezed`
