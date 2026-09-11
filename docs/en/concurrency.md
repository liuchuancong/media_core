# concurrency Module

> Reusable async concurrency primitives: locks, mutexes, semaphores, concurrency limits, and serial executors, plus a central manager that shares them by key.

## Module Responsibilities

- Provide pure infrastructure-level concurrency control primitives with no business logic.
- Share the same lock/semaphore/serializer across modules by `ConcurrencyKey` through `ConcurrencyManager`.

## Core API

| API | Description |
| --- | --- |
| `ConcurrencyManager` | Central registry: obtains `withLock`, mutex, limit, and serial executor by key |
| `AsyncLock` | Single-holder async lock, with a `synchronized()` helper |
| `Mutex` | Traditional acquire/release mutex, with `protect()` |
| `AsyncSemaphore` | Permit-counted concurrency limiter, with `withPermit()` |
| `ConcurrencyLimit` | Concurrency bucket based on `package:pool`: maxConcurrent, permit acquisition, guarded actions |
| `SerialExecutor` | FIFO async task queue that runs one task at a time |
| `ExclusiveTask` | Exclusive task: chained to run after the previous task completes (suitable for init, source switching) |
| `ConcurrencyKey` | Domain-agnostic resource identifier (`scope:name`), owned by the caller |

## Design Notes

- Doc comments clearly distinguish the applicable scenarios for lock / mutex / limit / serial executor.
- Resource keys are defined by the caller; this module is unaware of semantics.

## Dependencies

- External: `package:pool`
