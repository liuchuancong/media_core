# visibility 模块

> 播放器可见性观察与管理：跟踪播放器是否可见并发出可见性事件。

## 模块职责

- `VisibilityController` 维护播放器可见性状态。
- 通过 `VisibilityObserver` 回调与不可变事件对外发布变化。

## 核心 API

| API | 说明 |
| --- | --- |
| `VisibilityController` | 可见性状态控制器 |
| `VisibilityObserver` | 抽象接口：单一 `onVisibilityEvent(VisibilityEvent)` 回调 |
| `VisibilityEvent` / `VisibilityEventType` | 事件与类型枚举（appeared、disappeared、visible、hidden、changed） |
| `VisibilityState` / `VisibilitySnapshot` / `VisibilityMetrics` | 运行状态 / 不可变快照 / 统计 |

## 设计说明

- 极小、自包含；无跨模块导入（`testing/fake_visibility` 规划中将伪造本模块）。
