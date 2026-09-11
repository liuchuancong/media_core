# Media Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-compatible-02569B.svg)](https://flutter.dev)

> 一套面向 Flutter/Dart 的模块化媒体播放核心：以后端无关的方式抽象播放器、音视频会话、资源、缓存、并发、降级、恢复、呈现与可观测性。
>
> A modular media playback core for Flutter/Dart: backend-agnostic abstractions for players, audio/video sessions, resources, caching, concurrency, fallback, recovery, presentation, and observability.
>
> 一套面向 Flutter/Dart 的模組化媒體播放核心：以後端無關的方式抽象播放器、音視訊會話、資源、快取、併發、降級、恢復、呈現與可觀測性。

- Repository: https://github.com/liuchuancong/media_core
- License: MIT

> Other languages · 其他语言版本: [简体中文](../zh-Hans/README.md) · [繁體中文](../zh-Hant/README.md)

---

## English

### Introduction

Media Core is not a single player plugin, but a set of **clearly-scoped, strictly-bounded, composable** modules. It decomposes player capabilities into subsystems — the core domain model, adapters, factory, sessions, playback control, audio, caching, concurrency, network, resources, policies, fallback, recovery, presentation, rendering, events, operations, tasks, state machines, and more — and composes them through a coordination layer.

**Design goals:**

- **Backend-agnostic**: media_kit, native, video_player, ExoPlayer, VLC, etc. can all be integrated through adapters.
- **Single responsibility**: Adapter executes, Factory creates, Registry stores, Selector decides, Coordinator only forwards.
- **Testable**: heavy use of `clock`, immutable value objects, injectable interfaces, and fault injection.
- **Extensible**: error codes, fault types, task types, operation types, etc. deliberately use value objects instead of closed enums.
- **Observable**: state, metrics, events, and snapshots run through every module.

### Module Documentation

| Module | Description |
| --- | --- |
| [`adapter`](adapter.md) | Backend-agnostic player adapter abstraction: unified playback engine contract, factory, registry, and capability selection |
| [`audio`](audio.md) | Platform-agnostic audio subsystem: audio focus, session, output routing, volume, and mute |
| [`bug`](bug.md) | Debugging & fault injection: bug modes, fault configs, hooks, injectors, schedulers, and scenarios |
| [`cache`](cache.md) | Generic two-level cache: memory + pluggable storage, eviction policies, expiration, metrics, and state |
| [`concurrency`](concurrency.md) | Async concurrency primitives: locks, mutexes, semaphores, concurrency limits, and serial executors |
| [`coordinator`](coordinator.md) | Cross-module coordination layer: binds by PlayerId and forwards requests; executes nothing itself |
| [`core`](core.md) | Public core of the player domain model: identity, state, config, options, capabilities, info, metrics, errors, and snapshots |
| [`error`](error.md) | Error system: codes/categories, classifier, formatter, retry/fallback policy decisions, and failure objects |
| [`event`](event.md) | Player event definition, bus, and dispatch: transport only |
| [`factory`](factory.md) | Player/backend factories: backend registry, capability-based backend selection, player creation entry point |
| [`fallback`](fallback.md) | Fallback mechanism: degradation/retry lifecycle across backend, playback line URL, and quality tier |
| [`geometry`](geometry.md) | Video geometry: video/display size, aspect ratio, rotation, orientation, pixel density, and geometry state controller |
| [`identity`](identity.md) | Strongly-typed immutable identifier value objects shared across modules |
| [`lifecycle`](lifecycle.md) | Player, page, and app lifecycle: small state machine, events, snapshots, and observers |
| [`network`](network.md) | Network abstraction: connectivity state/condition/type/quality, performance metrics, and request/response execution |
| [`operation`](operation.md) | High-level async/business operations: immutable lifecycle records, registry, tracker, cancellation tokens, and timeout policy |
| [`platform`](platform.md) | Platform capabilities and platform-specific abstractions: purely descriptive value types |
| [`playback`](playback.md) | Playback control: commands, state, position, duration, and options |
| [`policy`](policy.md) | Centralized cross-module player policy: single source of truth for cross-module behavior rules |
| [`pool`](pool.md) | Player instance pool: instance allocation, idle recycling, metrics, and state streams |
| [`preload`](preload.md) | Media preload: priority-based preload task scheduling, warmup, and lifecycle management |
| [`presentation`](presentation.md) | Presentation modes: Redux-style state machine for fullscreen, picture-in-picture, and floating window |
| [`reactive`](reactive.md) | Reactive abstractions and stream utilities: shared rxdart-based toolbox |
| [`reconciler`](reconciler.md) | Reconciliation of desired vs. actual state: produces declarative convergence action plans |
| [`recording`](recording.md) | Recording abstraction: recording sessions, formats, and backends |
| [`recovery`](recovery.md) | Playback recovery: decides and schedules recovery actions after failure |
| [`renderer`](renderer.md) | Rendering abstraction at the Flutter widget layer: surfaces, views, overlays, and renderer state |
| [`resource`](resource.md) | Resource management: budgets, per-domain managers, and pressure computation for decoder, memory, bandwidth, and thermal |
| [`result`](result.md) | Unified, immutable, value-based result types: synchronous Result, async AsyncResult, and operation-level OperationResult |
| [`session`](session.md) | Playback session: lifecycle, context, state, events, and operations |
| [`slot`](slot.md) | Logical player slots: slot ownership, assignment, and state |
| [`source`](source.md) | Media source abstraction: declaration, resolution, inspection, validation, and resolved metadata |
| [`state_machine`](state_machine.md) | Generic domain-agnostic state machine infrastructure: states, events, transitions, and orchestration |
| [`task`](task.md) | Schedulable task execution: task value objects, priority queue, scheduler, and lifecycle manager |
| [`util`](util.md) | General-purpose reusable static utilities: no domain logic, no cross-module dependencies |
| [`visibility`](visibility.md) | Player visibility observation and management: tracks visibility and emits events |

### Getting Started

Add the following dependency to your `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  media_core:
    git:
      url: https://github.com/liuchuancong/media_core.git
```

For the responsibility boundaries, core APIs, and dependencies of each module, see the "Module Documentation" table above.

### Directory Layout

```
media_core/
└── docs/
    ├── zh-Hans/         # README.md + 36 module docs (Simplified Chinese)
    ├── en/              # README.md + 36 module docs (English)
    └── zh-Hant/         # README.md + 36 module docs (Traditional Chinese)
```
