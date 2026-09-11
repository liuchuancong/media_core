# reconciler 模块

> 期望状态与实际状态的调和（Kubernetes 风格）：比较两者并产生声明式的收敛动作计划，自身不执行任何动作。

## 模块职责

- `reconcile(current, desired)` → `ReconcilePlan`（如派生的 `PlayerStatus` 不一致时给出 `changeState`）。
- 排队与调度计划，发布调和状态；动作的实际执行属于 Coordinator / Controller / SessionManager。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerReconciler` | `reconcile(current, desired)`、`needsReconcile()`、`evaluate(plan)` → `ReconcileResult`（noop/pending） |
| `ReconcileAction` / `ReconcileActionType` | 纯描述性动作（目前仅 `changeState`，含 from/to 状态） |
| `ReconcilePlan` | 有序动作列表；`empty()` 工厂 |
| `ReconcileScheduler` | 计划排队、排序执行顺序；BehaviorSubject 发布 `ReconcileState` 与 pending 计数；不执行动作 |
| `ReconcileQueue` / `ReconcileState` / `ReconcileResult` / `ReconcileContext` | FIFO 队列（跳过空计划）/ running/completed/failed/pendingActions 状态 / 结果 / 上下文 |

## 设计说明

- 从 `PlayerState` 旗标解析 `PlayerStatus` 的优先级：disposed > disposing > opening > …。

## 依赖

- 内部：`core`（PlayerState / PlayerStatus）、`identity`
- 外部：`rxdart`、`equatable`
