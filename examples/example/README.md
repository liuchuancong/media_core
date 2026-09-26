# media_core example

A runnable tour of the framework: five pages that actually play media, plus a
module tour that prints what the pure-logic modules did.

```bash
flutter run -d windows      # or: -d macos / -d linux / -d <android-device>
```

The example depends on the packages in this repository by path, including the
vendored `media_kit`, so it always exercises the working tree — no published
version, no external fork.

## 可运行示例 / Runnable demos

| Page | What it demonstrates |
| --- | --- |
| **播放器与生命周期** (player) | `PlayerKernel → registerBackend → create → open → play`; seek/volume/rate/mute/loop; the event log shows engine events, **operation records** (`handle.onOperation`) and recovery decisions. |
| **直播多线路与引擎回退** (live) | A multi-line `LiveSourceRequest`: lines are swept on the current engine, then the next engine gets its turn, and the caller receives **exactly one** failure when everything is spent. |
| **短视频上下滑** (feed) | One shared player re-opened per item (no engine startup between swipes); only the visible page mounts a video widget; the next item is preloaded. |
| **音乐** (music) | The whole `media_core_audio` surface: a `MusicSource` implementation, queue + four play modes, lyric timeline, desktop-lyric window (with lock/style), background binding, and an ffmpeg download with live progress. |
| **展示与弹幕** (presentation) | `kernel.attachPresentation(driver)` forwarding fullscreen/PiP/floating, and the danmaku session fed by a synthetic transport. |

Each page has an event log at the bottom: it is where the framework's own
decisions (backend chosen, recovery rung, download progress) become visible,
which is the point of running an example rather than reading docs.

## 模块速览 / Module tour

Kept for what a device cannot show better: the pure-logic modules run and print
their result.

| Demo | What it prints |
| --- | --- |
| `lrc` | A parsed lyric table (repeated timestamps, offset, merged translation, `<mm:ss.xx>` word timing) and a timeline walk showing that only line changes emit events. |
| `queue` | A queue walk per play mode — including that a user "next" on the last track does **not** silently wrap in `list` mode — plus the shuffled permutation and `insertNext`. |
| `source` | `search → resolveTrackSource → TrackSource → PlayerSource`, with headers/`expiresAt`, and an expired resolution that would be re-resolved instead of replayed. |
| `platform` | Permission states (read-only, no dialog), and the exact ffmpeg argument list for a streaming URL versus a copyable container. |

## Adding a demo

1. Add a page under `lib/pages/` (or a console demo under `lib/demos/console/`).
2. Register it in `lib/demos/registry.dart` — one entry for a runnable page,
   one `ModuleDemo` subclass for a printed tour.
3. `flutter test` covers the catalog wiring; `dart analyze examples/example`
   covers the rest.

## Platform notes

- **Windows / macOS / Linux**: nothing to set up. Desktop lyrics open a native
  overlay window (`media_core_audio`); the music page's "桌面歌词" button is the
  one to press.
- **Android**: the music page requests `POST_NOTIFICATIONS` /
  `READ_MEDIA_AUDIO` and, for desktop lyrics, `SYSTEM_ALERT_WINDOW` (which has
  no dialog — the request opens the system settings screen and answers once the
  switch is on). See `packages/media_core_audio/doc/permissions.md` for what an
  app must still declare itself (audio_service's activity/service/receiver).
- The first build downloads the native bundles for `media_kit` and (if the
  music page is used) `ffmpeg_kit_extended_flutter` from their release pages.
  Without network access those two hooks fail and the build stops there — not a
  problem with the example.
- Sample URLs are public test streams; replace them with your own in the text
  fields. Nothing in the example hardcodes a private endpoint.
