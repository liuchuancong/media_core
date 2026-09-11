# pool Module

> Player instance pool: instance allocation tracked by id, idle recycling, metrics, and state streams.

## Module Responsibilities

- Manage allocation of pooled player instances to sessions and idle recycling.
- Publish a pool state stream and track pool metrics.
- Does not create or destroy players itself — that belongs to PlayerFactory / PlayerSession.

## Core API

| API | Description |
| --- | --- |
| `PlayerPool` | Public facade: `states` stream, `state`, `snapshot`, `count`, `add`, and acquire/release-style operations; hides internal coordination |
| `PlayerPoolManager` | Coordinates allocator + recycler; maintains `_players/_active/_sessions`; publishes `PlayerPoolState` via BehaviorSubject; tracks `PlayerPoolMetrics` |
| `PlayerPoolAllocator` | Picks an available player for a session (first-come-first-served by default); `selectCandidate` is the override point for custom policies |
| `PlayerPoolRecycler` | Decides which idle players can safely return to idle (recycles up to maxCount by default) |
| `PlayerPoolConfig` | freezed config: maxPlayers, initialSize, lazyCreate, enableRecycle, idleTimeout, keepWarm, warmSize, maxActivePlayers |
| `PlayerPoolState` / `PlayerPoolSnapshot` / `PlayerPoolMetrics` | State / read-only snapshot / metrics value objects (freezed) |

## Design Notes

- Separated from the `slot` module (logical slots) and the `factory` module (physical creation); the pool only does reuse scheduling.

## Dependencies

- Internal: `identity` (PlayerId, SessionId)
- External: `rxdart`, `freezed`, `clock`
