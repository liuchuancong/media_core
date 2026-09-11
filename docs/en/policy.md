# policy Module

> Centralized cross-module player policy: a set of plain, immutable config/policy objects that are the single source of truth for cross-module player behavior rules.

## Module Responsibilities

- Aggregate 14 domain policies into `PolicyContext`, providing `PolicyContext.defaults()`.
- Policies only describe rules and provide query helpers (e.g. `PreloadPolicy.canPreload(count)`); execution belongs to PreloadManager, Player, Session, Factory, etc.

## Core API

| API | Description |
| --- | --- |
| `PolicyContext` | Aggregates all 14 policies; `defaults()` factory |
| `PlayerPolicy` | Root policy: composes `PlaybackPolicy`, `ResourcePolicy`, `RecoveryPolicy`, `ConcurrencyPolicy` + a global `enabled` switch |
| `PlaybackPolicy` / `PreloadPolicy` | Playback policy / preload policy (maxPreloadedPlayers, preloadDuration, warmup, background preload) |
| `AudioPolicy` / `CachePolicy` / `MemoryPolicy` / `ThermalPolicy` | Audio / cache / memory / thermal policies |
| `LifecyclePolicy` / `VisibilityPolicy` / `FallbackPolicy` / `PresentationPolicy` | Lifecycle / visibility / fallback / presentation policies |
| `ConcurrencyPolicy` / `ResourcePolicy` / `RecoveryPolicy` | Concurrency / resource / recovery policies |

## Design Notes

- All are small config classes, immutable and side-effect free; the only outward reference is the mode types of `presentation` (used by PresentationPolicy).

## Dependencies

- Internal: `presentation` (types only)
