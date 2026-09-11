# task Module

> Schedulable task execution: task value objects, a priority queue, a scheduler, and a manager that owns lifecycles.

## Module Responsibilities

- Describe schedulable work with `PlayerTask` (freezed).
- `TaskScheduler` does neutral lifecycle advancement (queued → running only); `TaskManager` owns task lifecycles and execution slots.
- Provide a cooperative cancellation token.

## Core API

| API | Description |
| --- | --- |
| `PlayerTask` | Description of schedulable work (freezed) |
| `TaskManager` | Owns lifecycles and execution slots; throws `TaskExecutionFailure` (retains the failed task + error + stack trace) and disposal errors |
| `TaskScheduler` | Neutral except for `queued → running`; does not own a registry/cancellation |
| `TaskQueue` | Immutable queue (every mutation returns a new queue); deterministic ordering: priority → creation time → `TaskId`; `TaskQueueResult` for removal operations |
| `TaskCancelToken` / `TaskCancelledException` | Cooperative cancellation (active → cancelled/disposed) and its exception |
| `TaskId` / `TaskType` / `TaskPriority` / `TaskState` | Small Comparable id (prevents mixing id types) / value-object type (not an enum, making adapter extension easy) / priority / terminal-closed state |
| `TaskContext` | freezed execution context: retry info + JSON-compatible metadata; `task_json_converters.dart` provides json_serializable converters |

## Dependencies

- Internal: `operation` (operation_context.dart), `identity` (all kinds of ids and converters)
