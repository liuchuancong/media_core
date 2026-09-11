# visibility 模塊

> 播放器可見性觀察與管理:跟蹤播放器是否可見並發出可見性事件。

## 模塊職責

- `VisibilityController` 維護播放器可見性狀態。
- 通過 `VisibilityObserver` 回調與不可變事件對外發布變化。

## 核心 API

| API | 說明 |
| --- | --- |
| `VisibilityController` | 可見性狀態控制器 |
| `VisibilityObserver` | 抽象接口:單一 `onVisibilityEvent(VisibilityEvent)` 回調 |
| `VisibilityEvent` / `VisibilityEventType` | 事件與類型枚舉(appeared、disappeared、visible、hidden、changed) |
| `VisibilityState` / `VisibilitySnapshot` / `VisibilityMetrics` | 運行狀態 / 不可變快照 / 統計 |

## 設計說明

- 極小、自包含;無跨模塊導入(`testing/fake_visibility` 規劃中將偽造本模塊)。
