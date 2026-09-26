# coordinator Module

> Cross-module coordination layer: binds a player to each subsystem controller/manager by `PlayerId` and forwards requests between them; it performs no operations itself.

## Module Responsibilities

- Act as a composition root (`GlobalPlayerCoordinator`) aggregating playback, page, audio, resource, preload, lifecycle, and presentation coordinators.
- Uniformly use a "register/unregister/lookup + `request(...)` forwarding" pattern to route requests to the corresponding subsystem.
- Does not create players, call platform APIs, or store playback state.

## Core API

| API | Description |
| --- | --- |
| `GlobalPlayerCoordinator` | Root composition: aggregates the coordinators below (all lazily defaultable) |
| `PlaybackCoordinator` | Binds a `PlaybackController` per player, forwards `PlaybackRequest` |
| `PlayerCoordinator` | Binds `Player`/`PlayerSession` pairs, owns the high-level player workflow |
| `PlayerAudioCoordinator` | Registers each player's `AudioManager`; per-player volume/mute with reactive streams; serialized operations, idempotent disposal |
| `LifecycleCoordinator` | Binds a `PlayerLifecycle` handler per player, dispatches lifecycle events |
| `PageCoordinator` | Page↔player binding (`attachPlayer/detachPlayer`, active page) |
| `PreloadCoordinator` | Binds a `PreloadManager` per player, forwards preload requests |
| `ResourceCoordinator` | Binds a `ResourceManager` per player, applies resource-pressure decisions |
| `PresentationCoordinator` | Binds a `PresentationController` per player, routes presentation requests |

## Design Notes

- Coordinators are always just "bind + forward"; actual responsibilities belong to PlayerFactory / PlayerAdapter / PlaybackController, etc.
- Suitable for uniformly obtaining subsystem entry points at the application layer via `GlobalPlayerCoordinator`.

## Dependencies

- Internal: `identity`, `core`, `session`, `playback`, `audio`, `lifecycle`, `preload`, `presentation`, `resource`
- External: `rxdart`
