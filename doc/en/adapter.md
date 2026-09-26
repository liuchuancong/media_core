# adapter Module

> Backend-agnostic player adapter abstraction: defines a unified playback engine contract (`PlayerAdapter`), factories, registry, and capability selection.

## Module Responsibilities

- Define the unified `PlayerAdapter` contract so concrete playback engines such as media_kit, native, and video_player integrate in the same way.
- Provide adapter creation (Factory), registration and lookup (Registry), and capability-based candidate selection (Selector).
- Define adapter-layer value objects for events, state, metrics, and capability descriptions.

## Core API

| API | Description |
| --- | --- |
| `PlayerAdapter` | Abstract contract for a playback backend: `open/play/pause/stop/seek/setVolume/setRate/close/dispose`, exposing `state`, `events`, `metrics`, `capabilities` |
| `PlayerAdapterFactory` / `DefaultPlayerAdapterFactory` | Creates adapter instances by identifier; registers anonymous creation functions, hiding concrete implementations |
| `PlayerAdapterRegistry` / `PlayerAdapterRegistration` | Stores adapter metadata (id, factory, capabilities, priority, enabled state); only responsible for lookup |
| `PlayerAdapterSelector` | Selects the best adapter for a `SourceDescriptor` based on capabilities (live/seek/protocol/format) and priority, and provides a candidate list |
| `PlayerAdapterCapabilities` | Static capability description: live, seek, PiP, hardware decoding, supported protocols and formats |
| `PlayerAdapterEvent` | Closed set of backend events (freezed): opened/playing/paused/buffering/completed/position/duration/videoSize/volume/rate/error |
| `PlayerAdapterState` / `PlayerAdapterConfig` / `PlayerAdapterContext` / `PlayerAdapterError` / `PlayerAdapterMetrics` | Surrounding immutable value objects |

## Design Notes

- Strict single responsibility: Adapter executes, Factory creates, Registry stores, Selector decides.
- Fallback handling is delegated to the `FallbackManager` in the `fallback` module; this module only produces the candidate ordering.
- Events provide predicate extensions such as `isError` / `affectsPlayback` / `affectsGeometry`.

## Dependencies

- Internal: `core` (PlayerState), `source` (PlayerSource / SourceDescriptor)
- External: `freezed`, `equatable`
