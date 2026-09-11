# operation 模块

> 高层异步/业务操作：把 open/play/seek/recover 等操作建模为带严格状态转换校验的不可变生命周期记录，附注册表、响应式追踪器、取消令牌与超时策略。

## 模块职责

- 以值对象方式描述操作（不做执行）：`Operation` 记录 id、类型、状态、上下文与时间戳。
- 提供执行侧控制（取消令牌）、策略（超时）与观察（Registry / Tracker）。

## 核心 API

| API | 说明 |
| --- | --- |
| `Operation` | 不可变生命周期记录；`start()/complete()/fail()/cancel()` 返回新实例，非法转换抛 `StateError`；不含执行逻辑 |
| `OperationState` | 值对象（非 enum）：created/running/completed/failed/cancelled + `custom()`；显式转换图，终态封闭 |
| `OperationType` | 值对象，23 种内置类型（open、play、pause、stop、seek、close、initialize、dispose、prepare、load、reload、速率/音量/静音设置、全屏/画中画进出、录制开始/停止、recover、fallback、retry）+ 分类 getter（isPlaybackOperation 等） |
| `OperationContext` | 丰富关联上下文（全部 7 种 id、lineId、quality、uri、platform、backend、adapter、参数/metadata）；流式 `withX()/withoutX()`；完整 JSON 往返 |
| `OperationCancelToken` | 执行侧取消控制：`cancel([reason])`、`cancelledFuture`、`onCancel` 流、`throwIfCancelled()`、`run/runChecked`、层级 `child()/fork()`（仅父→子传播）；抛 `OperationCancelledException`；不直接修改 OperationState |
| `OperationTimeout` | 时长+启用开关的策略：`deadlineFor`、`remainingFor`、`isExpired`（终态操作永不超时） |
| `OperationRegistry` | 注册操作的权威集合：register/update/remove、按状态查询；不执行、不取消 |
| `OperationTracker` | 响应式观察：每 id 最新快照 + 有界历史（默认 1000），BehaviorSubject 当前流 + PublishSubject 操作流，`markStarted/Completed/Failed/Cancelled` 辅助与历史查询 |

## 设计说明

- 最大的模块（约 3400 行），职责切分在文档中反复强调：Operation（模型）/ CancelToken（执行）/ Timeout（策略）/ Registry（所有权）/ Tracker（观察）；执行、调度、重试、恢复属于更高层。
- 全程使用 `clock`，保证可测试。

## 依赖

- 内部：`identity`
- 外部：`rxdart`、`clock`、`equatable`
