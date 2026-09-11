# platform Module

> Platform capabilities and platform-specific abstractions: purely descriptive value types describing what the current runtime environment supports; no native API access.

## Module Responsibilities

- Describe the runtime platform type and environment information.
- Describe capability flags for codecs, rendering, audio, subtitles, PiP, fullscreen, background, network, etc.
- Define the `PlatformProvider` interface as the abstraction layer between media core and the host platform.

## Core API

| API | Description |
| --- | --- |
| `PlatformType` | Platform type value object: android/ios/windows/macos/linux/web/tv, with parsing |
| `PlatformProvider` | Abstract interface: `type`, `info`, `capabilities`, `isReady`; detection and native queries are the responsibility of its implementations |
| `PlatformInfo` | Immutable runtime environment information |
| `PlatformCapabilities` | Capability flags for codecs/rendering/audio/subtitles/PiP/fullscreen/background/network |
| `PlatformLifecycle` | Flags for background playback, pause when inactive, resume on foreground, suspension, etc. |
| `PlatformPip` | System PiP vs custom floating window, automatic entry, resizable |
| `PlatformSurface` | Video output surface description (type, scaling/rotation support, texture id) |
| `PlatformAudio` / `PlatformNetwork` / `PlatformRenderer` | Audio/network/rendering capability descriptors |

## Design Notes

- A complete leaf module with zero internal cross-module dependencies; native detection is delegated to `PlatformProvider` implementations and the `BackendFactory` in the `factory` module.

## Dependencies

- External: `equatable`
