# core Module

> The public core of the player domain model: foundational immutable value objects for identity, state, configuration, options, capabilities, info, metrics, errors, and snapshots.

## Module Responsibilities

- Define `Player` identity, semantic `PlayerState`, and the fully observable `PlayerSnapshot`.
- Distinguish creation-time configuration (`PlayerConfig`) from runtime options (`PlayerOptions`).
- Describe implementation capabilities (`PlayerCapabilities`) and current media capabilities (`MediaCapabilities`).

## Core API

| API | Description |
| --- | --- |
| `Player` | Stable player identity (equality by `PlayerId` only); `Player.create()` generates the id |
| `PlayerState` | Semantic runtime state (freezed): `PlayerLifecycleState` (idle/initializing/ready/disposing/disposed) + `PlayerPlaybackState` (playing/paused/buffering/seeking/…) + hasSource/audio/video/muted flags |
| `PlayerSnapshot` | Complete immutable observable state: all ids, media type/capabilities, state, options, capabilities, metrics, timestamp |
| `PlayerConfig` / `PlayerOptions` | Immutable creation config vs runtime options (autoPlay, loop, volume, decoding preference, recovery/fallback switches and max counts) |
| `PlayerCapabilities` | Implementation capabilities: play/seek/PiP/fullscreen/frameStep… |
| `MediaCapabilities` / `MediaType` | Capabilities of the current media (audio/video/subtitle tracks, seekable, live) and its type |
| `PlayerInfo` | Stable descriptive metadata (title, author, bitrate, size…, freezed) |
| `PlayerMetrics` | Backend-agnostic playback/buffering/rendering/network measurements for diagnostics |
| `PlayerError` | Immutable error snapshot: code, category resolved by the classifier, cause, context id |
| `PlayerStatus` + `PlayerStatusX` | High-level status enums derived from state, with convenience predicates |
| `PlayerConstants` | Shared defaults/caps (volume/rate bounds, timeouts, seek tolerance) |

## Design Notes

- Strictly separates five layers — config / state / options / capabilities / media capabilities — and every class documents its clear boundary.
- `PlayerState` and `PlayerInfo` use freezed and support JSON serialization.

## Dependencies

- Internal: `identity` (all kinds of ids), `error` (ErrorClassifier, code, category)
- External: `freezed`, `equatable`, `clock`
