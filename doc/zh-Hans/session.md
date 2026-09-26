# session 模块

> 播放会话：生命周期、上下文、状态、事件与操作——把播放器实例与媒体源绑定起来的编排单元。

## 模块职责

- 定义 `PlayerSession`（一次播放会话）及其运行控制与管理。
- 提供 `SessionGeneration` 单调代际防护：换源/重建/重试/降级后的过期会话不得影响新会话。
- 记录会话状态、生命周期、事件与操作。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerSession` | 一次播放会话；不创建播放器（属 PlayerFactory/PlayerAdapter/PlaybackController） |
| `SessionController` | 会话状态的运行控制 |
| `SessionManager` | 管理多个会话；不直接控制 adapter |
| `SessionContext` / `SessionState` / `SessionStatus` | 上下文 / 不可变状态与状态枚举 |
| `SessionLifecycle` / `SessionLifecyclePhase` | 会话生命周期与阶段枚举 |
| `SessionGeneration` | Comparable 单调代际守卫，拦截过期会话的影响 |
| `SessionOperation` / `SessionOperationType` / `SessionOperationState` | 被跟踪的会话操作；无重试策略 |
| `SessionEvent` / `SessionEventType` | 不可变事件记录 |
| `SessionSnapshot` | freezed 只读状态视图 |

## 依赖

- 内部：`identity`（各类 id）、`source`（player_source.dart）、`policy`（player_policy.dart）、`platform`（platform_capabilities.dart）
