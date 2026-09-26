# preload Module

> Media preload: priority-based preload task scheduling, warmup, and lifecycle management (keyed by source).

## Module Responsibilities

- Maintain a preload task table and dequeue tasks by priority for execution.
- Expose a metrics stream and task lifecycle operations.

## Core API

| API | Description |
| --- | --- |
| `PreloadManager` | Task-table manager: `metrics` stream (BehaviorSubject), `add(PreloadRequest)`, `next()`, `complete(task)`, `fail(task)` |
| `PreloadScheduler` | Maintains a priority-sorted task list; `add` marks a task queued and re-sorts by descending priority, `next()` pops the head |
| `PreloadPriority` | Enum: low / normal / high / critical |
| `PreloadRequest` / `PreloadTask` | Request of sourceId + priority / runnable task with lifecycle transitions |
| `PreloadState` | pending/loading/completed/failed/cancelled flags, `queued()/start()` transition helpers |
| `PreloadMetrics` / `PreloadContext` | Counters / context object |

## Design Notes

- Behavior caps (max preloaded count, warmup, background preload) are provided by `PreloadPolicy` in the `policy` module.

## Dependencies

- Internal: `identity` (SourceId)
- External: `rxdart`, `equatable`
