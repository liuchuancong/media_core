# Changelog

Changes to this project (the `media_core` workspace), newest first. Every package keeps its own `CHANGELOG.md`.

## 1.0.0

Initial release.

- **Core** (`media_core`): a platform-agnostic orchestration layer of 40 modules — identity and generations, sessions and handles, command serialization (task queue / state machine / reconciler), the recovery ladder with failure classification, player pool and preload, normalized events, operation tracking, memory and resource accounting, screenshots, diagnostics. It contains no platform code, UI or theming.
- **Four playback backends**: `media_kit`, `better_player` (video_player), `fvp` (libmdk) and `ijkplayer` (flv_lzc), all behind the adapter contract (`PlayerAdapter` + `PlayerVideo`), selected by capability and priority, and swappable at runtime.
- **Live** (`media_core_live`): line and engine sweep, stall watchdogs and backoff retry for non-seekable streams; single-use signed URLs are refreshed before an engine switch.
- **Presentation**: fullscreen (`media_core_fullscreen`), picture-in-picture (`media_core_pip`) and the in-app floating window (`media_core_floating`), coordinated as one state by `media_core_presentation` with video-orientation awareness.
- **Player UI** (`media_core_ui`): one control layer (state / actions / theme tokens) plus six design languages (material, cupertino, fluent, macos, yaru, neumorphic), including pinch zoom and screenshot entry points.
- **System media surfaces** (`media_core_mediasession`): Android notification, iOS lock screen and control center, Windows SMTC and Linux MPRIS, plus audio focus, interruption handling and pause-on-unplug.
- **Content shapes**: vertical feed (`media_core_feed`), list playback with resume (`media_core_list_playback`), multiview live wall (`media_core_multiview`), danmaku (`media_core_danmaku`) and music playback (`media_core_audio` — sources, queue, play modes, lyrics and the desktop lyric windows, downloads).
- **Platform and infrastructure**: native capability probe and background execution (`media_core_native`), levelled logging (`media_core_logging`), memory accounting (`media_core_memory`), offline downloads (`media_core_download`) and FFmpeg recording (`media_core_recording_ffmpeg`).
- The vendored `media_kit` and `media_kit_video` follow their upstream versions with fork patches (Native Assets build, native event loop, renderer binding); the differences are listed in their own `CHANGELOG.md` files.
