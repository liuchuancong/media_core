# renderer Module

> Rendering abstraction at the Flutter widget layer: the player's surface, views, and overlays, plus renderer state.

## Module Responsibilities

- Provide composite widgets for player display (view, surface, renderer, overlay).
- `RendererController` orchestrates renderer state transitions; does not create platform surfaces or control playback.

## Core API

| API | Description |
| --- | --- |
| `PlayerView` | Top-level composite widget; delegates the actual surface to `PlayerSurface` |
| `PlayerSurface` | Platform rendering surface slot (texture/platform view creation happens elsewhere) |
| `PlayerRenderer` | Assembles the view parts; does no playback control or geometry computation |
| `PlayerOverlay` | Caller-provided UI overlay (control bar, loading, gestures, danmaku, debug info) |
| `RendererController` | Orchestrates renderer state transitions |
| `RendererState` / `RendererConfig` / `RendererCapabilities` | Immutable renderer state / config and capability description (informational only) |

## Design Notes

- Pure presentation layer; every widget explicitly declares that it does no playback control, platform resource creation, or geometry computation. No cross-module imports.

## Dependencies

- External: Flutter widget framework
