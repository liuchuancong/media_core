# lifecycle 模塊

> 播放器、頁面與應用生命週期管理:小型狀態機,跟蹤生命週期轉換並以事件/快照/觀察者回調廣播。

## 模塊職責

- 以布爾旗標的 `LifecycleState` 建模生命週期,並以略細粒度的事件類型廣播轉換。
- 通知已註冊的 `LifecycleObserver`。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerLifecycle` | 接口:`snapshot`、`events` 流、轉換方法 `create/initialize/activate/pause/resume/deactivate/detach/dispose` |
| `LifecycleController` | 實現:BehaviorSubject 快照流 + PublishSubject 事件流;每次轉換通知觀察者;`dispose()` 依序發出 disposing→disposed 後關閉 |
| `LifecycleState` | 不可變布爾旗標狀態(created/initialized/active/paused/inactive/detached/disposing/disposed),`markX()` 轉換方法與派生判定(`isAlive`、`isReady`、`isTerminal`) |
| `LifecycleEvent` / `LifecycleEventType` | 事件與 9 種事件類型(比狀態略細:如 `activated` 與 `resumed` 都映射到 active) |
| `LifecycleObserver` | 單一回調 `onLifecycleEvent` |
| `LifecycleSnapshot` | 狀態 + `updatedAt` 時間戳 |

## 設計說明

- 極小模塊(約 300 行),自包含,無內部跨模塊依賴。

## 依賴

- 外部:`rxdart`、`clock`、`equatable`
