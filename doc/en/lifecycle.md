# lifecycle Module

> Player, page, and application lifecycle management: a small state machine that tracks lifecycle transitions and broadcasts them via events/snapshots/observer callbacks.

## Module Responsibilities

- Model lifecycle with boolean-flag `LifecycleState` and broadcast transitions with slightly finer-grained event types.
- Notify registered `LifecycleObserver`s.

## Core API

| API | Description |
| --- | --- |
| `PlayerLifecycle` | Interface: `snapshot`, `events` stream, transition methods `create/initialize/activate/pause/resume/deactivate/detach/dispose` |
| `LifecycleController` | Implementation: BehaviorSubject snapshot stream + PublishSubject event stream; notifies observers on every transition; `dispose()` emits disposing→disposed in order before closing |
| `LifecycleState` | Immutable boolean-flag state (created/initialized/active/paused/inactive/detached/disposing/disposed), `markX()` transition methods and derived predicates (`isAlive`, `isReady`, `isTerminal`) |
| `LifecycleEvent` / `LifecycleEventType` | Events and 9 event types (slightly finer than state: e.g. both `activated` and `resumed` map to active) |
| `LifecycleObserver` | Single callback `onLifecycleEvent` |
| `LifecycleSnapshot` | State + `updatedAt` timestamp |

## Design Notes

- Minimal module (~300 lines), self-contained, with no internal cross-module dependencies.

## Dependencies

- External: `rxdart`, `clock`, `equatable`
