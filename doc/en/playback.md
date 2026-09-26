# playback Module

> Playback control: playback commands, state, position, duration, and options; owns a backend-agnostic playback state machine.

## Module Responsibilities

- Express playback state changes as a sealed command set (`PlaybackCommand`).
- `PlaybackController` holds and exposes playback state via BehaviorSubject; operations are serialized through an internal future queue.
- Does not decode media, control backends, or call platform APIs.

## Core API

| API | Description |
| --- | --- |
| `PlaybackCommand` | Sealed commands: `.idle()/.play()/.pause()/.stop()/.buffering()/.position()/.duration()/.seek()/.volume()/.rate()`, with state predicates |
| `PlaybackController` | State holder: `state` (ValueStream), `current`, `snapshot`, `request(PlaybackRequest)` |
| `PlaybackState` | Runtime state: command, position, duration, volume, rate, initialized, updatedAt (via `clock`) |
| `PlaybackSnapshot` | Immutable read-only view for the Player API / UI / diagnostics |
| `PlaybackRequest` / `PlaybackOptions` | External operation wrapper / pre-start configuration |
| `PlaybackPosition` / `PlaybackDuration` / `PlaybackRate` / `PlaybackVolume` / `PlaybackCommandType` | Value objects and command enum |

## Design Notes

- Command pattern + sealed union types; self-contained module with no internal cross-module dependencies.

## Dependencies

- External: `rxdart`, `equatable`, `clock`
