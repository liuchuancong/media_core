# operation Module

> High-level async/business operations: models operations such as open/play/seek/recover as immutable lifecycle records with strict state-transition validation, plus a registry, reactive tracker, cancellation tokens, and timeout policy.

## Module Responsibilities

- Describe operations as value objects (no execution): `Operation` records id, type, state, context, and timestamps.
- Provide execution-side control (cancellation token), policy (timeout), and observation (Registry / Tracker).

## Core API

| API | Description |
| --- | --- |
| `Operation` | Immutable lifecycle record; `start()/complete()/fail()/cancel()` return new instances, illegal transitions throw `StateError`; contains no execution logic |
| `OperationState` | Value object (not an enum): created/running/completed/failed/cancelled + `custom()`; explicit transition graph, terminal-closed |
| `OperationType` | Value object with 23 built-in types (open, play, pause, stop, seek, close, initialize, dispose, prepare, load, reload, rate/volume/mute settings, fullscreen/PiP enter/exit, recording start/stop, recover, fallback, retry) + classification getters (isPlaybackOperation, etc.) |
| `OperationContext` | Rich associated context (all 7 ids, lineId, quality, uri, platform, backend, adapter, params/metadata); fluent `withX()/withoutX()`; full JSON round-trip |
| `OperationCancelToken` | Execution-side cancellation control: `cancel([reason])`, `cancelledFuture`, `onCancel` stream, `throwIfCancelled()`, `run/runChecked`, hierarchical `child()/fork()` (parent→child propagation only); throws `OperationCancelledException`; does not directly mutate OperationState |
| `OperationTimeout` | Duration + enabled-switch policy: `deadlineFor`, `remainingFor`, `isExpired` (terminal operations never time out) |
| `OperationRegistry` | Authoritative set of registered operations: register/update/remove, query by state; does not execute or cancel |
| `OperationTracker` | Reactive observation: latest snapshot per id + bounded history (default 1000), BehaviorSubject current stream + PublishSubject operation stream, `markStarted/Completed/Failed/Cancelled` helpers and history queries |

## Design Notes

- The largest module (~3400 lines); responsibility separation is emphasized throughout the docs: Operation (model) / CancelToken (execution) / Timeout (policy) / Registry (ownership) / Tracker (observation); execution, scheduling, retry, and recovery belong to higher layers.
- Uses `clock` throughout for testability.

## Dependencies

- Internal: `identity`
- External: `rxdart`, `clock`, `equatable`
