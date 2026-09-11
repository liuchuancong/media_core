# recovery Module

> Playback recovery: decides and schedules recovery actions after a failure (retry/restart/reinitialize/stop).

## Module Responsibilities

- Represent decision values (not execution requests) with sealed `RecoveryAction`.
- `RecoveryManager` starts recovery, tracks context and attempt counts, schedules retries, and completes or exhausts.
- `RetryScheduler` only computes and executes retry timing.

## Core API

| API | Description |
| --- | --- |
| `RecoveryAction` | Sealed decisions: `None/Retry/Restart/Reinitialize/Stop` (values only, not execution requests) |
| `RecoveryReason` | Sealed reasons: Unknown/Network/Timeout/Decoder/Renderer/Source/Initialization/Interrupted/Resource |
| `RecoveryManager` | Starts recovery, tracks context/attempts, schedules retries, complete/exhaust; exposes `RecoverySnapshot` |
| `RetryScheduler` / `RetryState` | Retry timing only / retry ordinal and attempt count |
| `RecoveryState` | Lifecycle: idle → … → complete/exhaust (see the flow in the class docs) |
| `RecoveryContext` / `RecoverySnapshot` | Immutable identity/diagnostic data and read-only state view |

## Design Notes

- Policy (action), execution (manager), and diagnostics (reason/snapshot) are strictly separated.

## Dependencies

- Internal: `identity` (SourceId, RequestId, OperationId, GenerationId)
