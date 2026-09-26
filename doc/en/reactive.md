# reactive Module

> Reactive abstractions and stream utilities: a shared rxdart-based toolbox for controllers, repositories, services, and player managers; does not depend on Flutter.

## Module Responsibilities

- Unified subject abstraction and static factories.
- Provide concurrency/timing control (mutex, gate, queue, scheduler).
- Provide state/result wrappers, stream operators, and lifecycle helpers.

## Core API (selected)

| API | Description |
| --- | --- |
| `Reactive` | Static factory facade (broadcast/single-subscription controllers); still rxdart underneath |
| `ReactiveSubject<T>` / `ReactiveBehavior<T>` | Subject interfaces that are both Stream+Sink / BehaviorSubject-backed, always able to emit the latest value |
| `StreamMutex` / `StreamGate` / `StreamQueue` | Async mutex (serial `run()`) / gate that ignores stale async operations / serial task queue |
| `StreamScheduler` | Dispose-safe delayed/periodic scheduler |
| `StreamState` / `StreamResult` / `StreamSafe` / `StreamSafeResult` | State holding / async operation state and result / error-to-result wrapper helpers |
| `debounce` / `throttle` / `combine` / `distinct` / `stream_transform` / `stream_extensions` | Stream operators and extensions |
| `stream_disposable` / `stream_cancellation` / `stream_lifecycle` / `stream_cache` / `stream_retry` / `stream_debouncer`, etc. | Helpers for disposable resource management, cancellation, lifecycle, in-memory cache with TTL, retry configuration, etc. |

## Design Notes

- Positioned to wrap rxdart rather than replace it; all tools are dispose-aware.
- Leaf module with no internal cross-module dependencies.

## Dependencies

- External: `rxdart`, `dart:async`
