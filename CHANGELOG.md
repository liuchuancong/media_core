# Changelog

Changes to this project (the `media_core` workspace), newest first. Every package keeps its own `CHANGELOG.md`.

## Unreleased

- **Dependencies**: `media_kit` and `media_kit_video` now resolve from `Predidit/media-kit` pinned at `803c4a27`, and `fvp` from pub.dev as `^0.38.1`. The copies that used to live in `packages/` are gone. The pinned revision does **not** contain the PureLive fork patches (`VideoController.setVideoOutputEnabled`, the Android Surface/`vid` ownership, the Windows `frameRevision` signal), so no package may call them.
- **Consequence for Android natives**: with the upstream bundles the bundled libmpv is back on FFmpeg 7.1, and the self-built FFmpeg 9 bundles are no longer shipped here; a stream that only a newer FFmpeg can read is the caller's problem now (see the next bullet).
- **Adapter re-exports**: every backend adapter re-exports the engine it is built on, so a host gets that engine's API from its single adapter dependency — `media_core_media_kit` (media_kit + media_kit_video; `Player` and `PlayerState` hidden), `media_core_fvp` (`fvp/mdk.dart` + `fvp/fvp.dart`; `Player`, `PlaybackState` and `MediaType` hidden), `media_core_better_player` (better_player_plus) and `media_core_ijk_player` (flv_lzc). Names are hidden only where `media_core` exports its own type of the same name.
- **No business logic in the packages**: the Douyu FLV continuation relay (URL leases and renewal) was removed from `media_core`'s source layer and from all four adapters, and now the legacy-HEVC FLV layer follows it out: `source/flv` (rewrite relay, tag rewriter, framer) is gone, `MediaKitPlayerConfig.legacyHevcFlvHosts` with it, and the media_kit adapter no longer reroutes any source — which sources a bundled FFmpeg cannot read is application knowledge, so a host that needs the rewrite runs its own relay. To make that work, a source URI on loopback is now exempt from the native proxy automatically (`media_kit` adapter), since a caller-owned relay must never be proxied. The fvp adapter keeps its decoder rule (legacy-HEVC hosts decode in software) — it does not reroute anything and its list stays caller configuration.

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
