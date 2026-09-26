# presentation 模塊

> 呈現模式:全屏、畫中畫與懸浮窗的 Redux 風格狀態機,與播放狀態及平台 API 解耦。

## 模塊職責

- 管理 normal / fullscreen / pip / floating 四種呈現模式(模式切換永不影響播放本身)。
- 控制器/reducer 為純函數;所有原生操作經 `PresentationAdapter` 進行。
- 以 generation 同步機制丟棄過期異步回調。

## 核心 API

| API | 說明 |
| --- | --- |
| `PresentationMode` | 枚舉:normal、fullscreen、pip |
| `PresentationController` | 核心狀態機:BehaviorSubject 持有狀態,接收請求、reduce 事件 |
| `PresentationReducer` | 純 `(state, event) -> state`,忽略 generation 低於當前的事件 |
| `PresentationEvent` / `PresentationState` / `PresentationRequest` / `PresentationSnapshot` / `PresentationCapabilities` | 事件/狀態/請求/快照/能力值對象(freezed) |
| `PresentationService` | 應用層 API:配對 Controller 與 `PresentationAdapter`,把適配器事件橋接進控制器 |
| `PresentationAdapter` / `PresentationAdapterBase` | 平台實現的適配器接口 + 基類(事件流、能力變化、生命週期) |
| `PresentationManager` / `PresentationDispatcher` | 高層門面 / 請求路由到各模式控制器 |
| `FullscreenController`、`PipController`、`FloatingController` | 各模式子控制器及 freezed 狀態 |

## 設計說明

- 嚴格分層:controller/reducer 純;原生操作全部走 adapter。
- 被 `policy` 模塊的 `PresentationPolicy` 引用。

## 依賴

- 外部:`rxdart`、`freezed`
