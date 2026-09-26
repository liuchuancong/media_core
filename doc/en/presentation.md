# presentation Module

> Presentation modes: a Redux-style state machine for fullscreen, picture-in-picture, and floating window, decoupled from playback state and platform APIs.

## Module Responsibilities

- Manage the four presentation modes normal / fullscreen / pip / floating (mode switching never affects playback itself).
- Controller/reducer are pure functions; all native operations go through `PresentationAdapter`.
- Discard stale async callbacks with a generation synchronization mechanism.

## Core API

| API | Description |
| --- | --- |
| `PresentationMode` | Enum: normal, fullscreen, pip |
| `PresentationController` | Core state machine: holds state via BehaviorSubject, receives requests, reduces events |
| `PresentationReducer` | Pure `(state, event) -> state`, ignores events with a generation lower than the current one |
| `PresentationEvent` / `PresentationState` / `PresentationRequest` / `PresentationSnapshot` / `PresentationCapabilities` | Event/state/request/snapshot/capability value objects (freezed) |
| `PresentationService` | Application-layer API: pairs a Controller with a `PresentationAdapter`, bridging adapter events into the controller |
| `PresentationAdapter` / `PresentationAdapterBase` | Platform-implemented adapter interface + base class (event streams, capability changes, lifecycle) |
| `PresentationManager` / `PresentationDispatcher` | High-level facade / routes requests to per-mode controllers |
| `FullscreenController`, `PipController`, `FloatingController` | Per-mode sub-controllers with freezed states |

## Design Notes

- Strict layering: controller/reducer are pure; all native operations go through the adapter.
- Referenced by `PresentationPolicy` in the `policy` module.

## Dependencies

- External: `rxdart`, `freezed`
