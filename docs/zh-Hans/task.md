# task 模块

> 可调度任务执行：任务值对象、优先级队列、调度器与拥有生命周期的管理器。

## 模块职责

- 以 `PlayerTask`（freezed）描述可调度的工作。
- `TaskScheduler` 做中立的生命周期推进（仅 queued → running）；`TaskManager` 拥有任务生命周期与执行槽位。
- 提供协作式取消令牌。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerTask` | 可调度工作的描述（freezed） |
| `TaskManager` | 拥有生命周期与执行槽位；抛 `TaskExecutionFailure`（保留失败任务 + 错误 + 栈）与释放错误 |
| `TaskScheduler` | 除 `queued → running` 外保持中立；不拥有注册表/取消 |
| `TaskQueue` | 不可变队列（所有变更返回新队列）；确定性排序：优先级 → 创建时间 → `TaskId`；`TaskQueueResult` 用于移除操作 |
| `TaskCancelToken` / `TaskCancelledException` | 协作式取消（active → cancelled/disposed）与异常 |
| `TaskId` / `TaskType` / `TaskPriority` / `TaskState` | 小型 Comparable id（防 id 类型混用）/ 值对象类型（非 enum，便于适配器扩展）/ 优先级 / 终态封闭的状态 |
| `TaskContext` | freezed 执行上下文：重试信息 + JSON 兼容 metadata；`task_json_converters.dart` 提供 json_serializable 转换器 |

## 依赖

- 内部：`operation`（operation_context.dart）、`identity`（各类 id 与转换器）
