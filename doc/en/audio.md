# audio Module

> Platform-agnostic audio subsystem management: audio focus, audio session, output routing, volume, and mute.

## Module Responsibilities

- Manage the high-level lifecycle of the audio subsystem: activate/deactivate (session first, then focus; automatic rollback on failure).
- Expose `enabled` / `active` / `focused` state via reactive streams.
- Hide platform details such as Android focus and iOS AVAudioSession interruptions behind interfaces.

## Core API

| API | Description |
| --- | --- |
| `AudioManager` | High-level facade: `activate/deactivate`, `abandonFocus/requestFocus`, `setEnabled`, idempotent `dispose` |
| `AudioCoordinator` | Coordination layer: combines focus + session into `AudioFocusState` / `AudioSessionState` streams; rejects stale async platform callbacks via a monotonic `generation` counter |
| `AudioFocus` / `AudioSession` | Platform abstraction interfaces (implementations provided by the platform adapter layer) |
| `AudioRoute` / `AudioRouteKind` | Coarse-grained description of the output route (speaker, etc.) |
| `AudioVolume` / `AudioMute` | Normalized volume (0.0–1.0) and mute value objects |
| `AudioFocusState` / `AudioSessionState` | Immutable state snapshots |

## Design Notes

- All lifecycle operations are serialized through a chained future queue to prevent race conditions.
- Clear layering of responsibilities: Focus/Session are the platform seams, Coordinator consolidates state, Manager faces outward.

## Dependencies

- External: `rxdart` (BehaviorSubject / ValueStream), `equatable`
