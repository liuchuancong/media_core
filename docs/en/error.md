# error Module

> The error system: stable error codes/categories, a classifier, formatters, retry/fallback policy decisions, and failure object representations.

## Module Responsibilities

- Define machine-readable `PlayerErrorCode` and broad failure domains `PlayerErrorCategory`.
- Answer three separated questions: classifier "what kind of error?", policy "what to do?", formatter "how to present?".
- Provide immutable failure objects, exception types, and structured diagnostic context.

## Core API

| API | Description |
| --- | --- |
| `PlayerErrorCode` | Stable error-code value object (`PLAYER_UNKNOWN`, network/source/backend, etc.); supports custom codes |
| `PlayerErrorCategory` | Failure-domain value object (unknown/invalidArgument/state/network/…); supports customization |
| `ErrorClassifier` | Static code → category mapping |
| `ErrorPolicy` | Decision: retryable/non-retryable code sets, maxRetries, retryDelay, whether retry/fallback/recovery are enabled; `defaults()` treats network/timeout/source/backend codes as retryable |
| `PlayerFailure` | Immutable failure object (code, message, cause, stackTrace, context, category); named constructors and `fromError` |
| `PlayerException` | Base exception carrying code/message/cause/context; `PlayerException.from` |
| `ErrorContext` | Structured diagnostic context (player/session/source/request/operation id, uri, backend, adapter, state, metadata) |
| `ErrorFormatter` | User-facing and diagnostics-facing string formatting |
| `ErrorUtils` | Stateless helpers: `toFailure`, `tryToFailure` |

## Design Notes

- Error codes/categories deliberately use value objects rather than enums so applications and adapters can extend them.
- This module does not perform retry/recovery; it only produces decision data.

## Dependencies

- Internal: `identity` (context id)
- External: `equatable`
