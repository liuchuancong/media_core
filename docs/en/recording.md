# recording Module

> Recording abstraction: recording sessions, formats, and backends for capturing media (from players, device input, etc.).

## Module Responsibilities

- Manage multiple recording sessions and their lifecycle orchestration.
- Delegate platform-specific writing/encoding to `RecordingBackend` implementations.
- Describe recording sources, configuration, container/codec preferences, and results.

## Core API

| API | Description |
| --- | --- |
| `RecordingManager` | Manages multiple recording sessions and orchestrates lifecycles |
| `RecordingSession` | Lifecycle of one recording; does not write media data itself or select platform APIs |
| `RecordingBackend` | Platform contract: `start(source, config)`, `stop()`, `cancel()`, `dispose()`; implementations write/encode files |
| `RecordingSource` / `RecordingSourceType` | Semantic source of the recorded media (decoupled from the player/network layers) |
| `RecordingConfig` | User configuration; does not select a backend or start/stop |
| `RecordingFormat` / `RecordingContainer` / `RecordingVideoCodec` / `RecordingAudioCodec` | Backend-agnostic container and codec preferences |
| `RecordingState` / `RecordingStatus` / `RecordingResult` | Session lifecycle state / completion result |

## Design Notes

- Strong layering discipline: every class's docs list "what it does NOT do"; no cross-module imports, fully decoupled.

## Dependencies

- No internal dependencies
