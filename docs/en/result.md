# result Module

> Unified, immutable, value-based result types: synchronous `Result`, in-flight `AsyncResult`, and operation-level `OperationResult`.

## Module Responsibilities

- Provide classic success/failure value results.
- Deliberately model "async in-progress" state separately from the "final result".

## Core API

| API | Description |
| --- | --- |
| `Result<T>` | Sealed: `ResultSuccess<T>` / `ResultFailure<T>` |
| `AsyncResult<T>` / `AsyncResultStatus` | Async lifecycle (loading/running); separation from the terminal result is a deliberate design |
| `OperationResult<T>` | Operation-level result; contains no retry/fallback policy (which belongs to other layers) |
| `ResultError` | Error-only payload; classification/recovery policy stays in the error layer |
| `ResultStatus` | Terminal status value; deliberately excludes async intermediate states |

## Design Notes

- Everything is immutable and Equatable; the separation between async intermediate states and terminal states is the module's core design point.

## Dependencies

- Internal: `identity` (RequestId, GenerationId), `error` (PlayerFailure, etc.)
