# session Module

> Playback session: lifecycle, context, state, events, and operations — the orchestration unit that binds a player instance to a media source.

## Module Responsibilities

- Define `PlayerSession` (one playback session) and its runtime control and management.
- Provide `SessionGeneration` monotonic generation protection: stale sessions after source switching/rebuild/retry/fallback must not affect new sessions.
- Record session state, lifecycle, events, and operations.

## Core API

| API | Description |
| --- | --- |
| `PlayerSession` | One playback session; does not create players (that belongs to PlayerFactory/PlayerAdapter/PlaybackController) |
| `SessionController` | Runtime control of session state |
| `SessionManager` | Manages multiple sessions; does not directly control the adapter |
| `SessionContext` / `SessionState` / `SessionStatus` | Context / immutable state and state enums |
| `SessionLifecycle` / `SessionLifecyclePhase` | Session lifecycle and phase enums |
| `SessionGeneration` | Comparable monotonic generation guard that intercepts the influence of stale sessions |
| `SessionOperation` / `SessionOperationType` / `SessionOperationState` | Tracked session operations; no retry policy |
| `SessionEvent` / `SessionEventType` | Immutable event records |
| `SessionSnapshot` | freezed read-only state view |

## Dependencies

- Internal: `identity` (all kinds of ids), `source` (player_source.dart), `policy` (player_policy.dart), `platform` (platform_capabilities.dart)
