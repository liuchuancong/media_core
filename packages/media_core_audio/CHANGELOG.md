## 0.1.0

Initial release.

- Sources: the `MusicSource` contract and registry, with a local source built in.
- Queue and play modes: `PlayQueue`, `PlayMode` (sequential / single / shuffle and friends) and the `PlayModeX` extension.
- Lyrics: LRC parsing, `LyricDocument` and the timeline (`LyricTimeline`), with a pluggable `LyricProvider`.
- Desktop lyric window: native windows for Windows and Android, including alignment, actions and the transport layer (`DesktopLyricController`).
- Background playback: `MusicBackgroundBinding` ties the app lifecycle and the audio session together.
- System media surfaces: notification / lock screen / SMTC / MPRIS through `media_core_mediasession` (`MediaCoreAudioHandler`).
- Downloads: an FFmpeg-backed source download queue (`MusicDownloadFormat` / `MusicDownloadStatus`).
- Permissions: `AudioPermissionService` and `AudioCapabilityConfig` declare what the module needs.
