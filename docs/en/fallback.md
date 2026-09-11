# fallback Module

> Fallback mechanism: coordinates degradation/retry lifecycles across three dimensions (backend implementation, playback line URL, quality tier).

## Module Responsibilities

- Manage candidate traversal for backends, lines, and qualities with three identical state-machine patterns.
- `FallbackManager` holds the active context and delegates concrete selection to three coordinators.
- Provide semantic fallback reasons and associated ids.

## Core API

| API | Description |
| --- | --- |
| `BackendFallback` / `BackendFallbackState` | Backend-id candidate traversal: `start/next/markFailed/complete/exhaust/reset` |
| `LineFallback` / `LineFallbackState` | Playback-line-id traversal with the same pattern |
| `QualityFallback` / `QualityFallbackState` | Quality-id traversal with the same pattern |
| `FallbackManager` | Holds the active `FallbackContext`, provides `success` / `failure` result factories; delegates to three coordinators |
| `FallbackContext` | Reason for the fallback request + associated ids (operationId/requestId/sourceId/generationId) + message/metadata |
| `FallbackReason` | Sealed reasons: unknown/backend/line/quality/network/decoder/renderer/timeout; descriptive only, does not decide policy |
| `FallbackResult` | Success carries a target; failure carries diagnostic information |

## Design Notes

- States are immutable Equatable and support `toMap`/`fromMap`; a selected candidate is removed from the candidate set.
- `exhausted` means "no candidates remain after a failure" — merely selecting the last candidate does not count as exhausted.
- Coordinators do not create backends, open media, or control playback.

## Dependencies

- Internal: `identity`
