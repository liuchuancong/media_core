# factory Module

> Player/backend factories: a backend registry, capability-based backend selection, and the public player creation entry point of media core.

## Module Responsibilities

- Register and look up playback backends (media_kit, vlc, exoplayer, etc.) and their descriptors and factories.
- Score backends by capability and preference to select the most suitable one.
- Provide the public `PlayerFactory` as the player creation entry point.

## Core API

| API | Description |
| --- | --- |
| `BackendCapabilities` | Backend capability set (live, vod, seek, pause, speed, audioOnly, network/local, hardware/software decoding, subtitles, audio tracks, rotation, screenshots, platform); with derived predicate getters |
| `BackendDescriptor` | Backend metadata: id, name, version, `factory`, capabilities, selection priority, enabled state |
| `BackendFactory` / `BackendInstance` | Creates backend instances (`create/warmUp/dispose`) and single-backend runtime (`initialize/dispose`) interfaces |
| `BackendRegistry` | Register/unregister/lookup/enabled check/`findByPlatform`; storage and lookup only |
| `BackendSelector` | `select(BackendSelectionRequest)`: directly eliminates (−1) disabled/platform-unsupported/missing-required-capability backends, then scores by preference (preferred backend +1000, hardware decode +100, low latency +50, network/local match +30, decodable +10) and descriptor priority |
| `BackendSelectionRequest` / `BackendSelectionResult` / `BackendSelectionReject` | Selection input/output (including score and rejection reason) |
| `PlayerFactory` | `create({PlayerFactoryConfig?})` → `Player`; the public creation entry point of media core |
| `PlayerFactoryConfig` | Creation-time options: preferredBackend, platform, autoInitialize, enableDiagnostics, enableHardwareDecode, enableFallback, optional `PlayerPolicy` |

## Design Notes

- Selector / Registry / Factory / Instance responsibilities are strictly separated in the docs; Selector does not register, Registry does not select.

## Dependencies

- Internal: `source` (SourceDescriptor / SourceLocation), `policy` (PlayerPolicy), `core` (Player)
