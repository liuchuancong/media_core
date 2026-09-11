# visibility Module

> Player visibility observation and management: tracks whether the player is visible and emits visibility events.

## Module Responsibilities

- `VisibilityController` maintains the player's visibility state.
- Publishes changes externally through `VisibilityObserver` callbacks and immutable events.

## Core API

| API | Description |
| --- | --- |
| `VisibilityController` | Visibility state controller |
| `VisibilityObserver` | Abstract interface: single `onVisibilityEvent(VisibilityEvent)` callback |
| `VisibilityEvent` / `VisibilityEventType` | Events and type enums (appeared, disappeared, visible, hidden, changed) |
| `VisibilityState` / `VisibilitySnapshot` / `VisibilityMetrics` | Runtime state / immutable snapshot / statistics |

## Design Notes

- Minimal and self-contained; no cross-module imports (`testing/fake_visibility` is planned to fake this module).
