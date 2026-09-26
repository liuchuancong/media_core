# media_core example

A runnable tour of the framework: pages a developer interacts with (most of them
playing real media, two running offline over fake players), plus a module tour
that prints what the pure-logic modules actually did.

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
| **内存监控仪表盘** (memory) | The `media_core_memory` surface, live: per-module accounts, a budget slider that moves the pressure level, peaks, and a device-provider switch. **Runs offline.** |
| **多画面视频墙** (multiview) | A monitoring wall: 2×2 / 3×3 layouts, focus and one audible cell, the decode budget degrading the wall, a frozen cell triggering the watchdog, patrol, per-cell danmaku. **Runs offline over fake players** — the wall logic is the real one. |

Each page has an event log at the bottom: it is where the framework's own
decisions (backend chosen, recovery rung, download progress) become visible,
which is the point of running an example rather than reading docs.

## 模块速览 / Module tour

Kept for what a device cannot show better: the pure-logic modules run and print
their result.

| Demo | What it prints |
| --- | --- |
| `memory` | Two instances adding up on one account, the total crossing `warning`/`critical`/`emergency`, the peak after a release, and a full report with declared **and** measured numbers side by side. |
| `logging` | The actual records: which lines survived a level, what a category override changed, scope fields appearing inside `LogScope.run`, a filter narrowing output, and a throttle's `suppressed` count on the next line that got through. |
| `cache` | LRU eviction (with the touched entry surviving), expiry dropped at read time, and the measured byte count the memory module reads from the cache. |
| `task` | Priority ordering under a concurrency cap, three serialized operations, a mutex turning a racing read-modify-write into a predictable one, and a retry budget with its backoff sequence. |
| `pool` | Every reconciliation of the playback pool: which item became active, which stayed warm, when an idle player was re-pointed instead of created, and what pressure shrank. |
| `list` | The resume rule: a position restored on the way back, an item abandoned inside the completion threshold restarting, and a live stream never counting as finished. |
| `fault` | The fault vocabulary, injection gated by `BugModeConfig`, and `ErrorPolicy` deciding retryability per code *and* per attempt count. |
| `download` | Two transfers at a time with a third queued, a paused transfer resumed after verifying its tail, a poisoned partial file restarting from zero, and an attempt budget ending a task visibly. |
| `recording` | The exact FFmpeg argument list for FLV/HLS/RTMP sources, then the recording state machine driven by a fake process — including why exit code 255 needs a stop intent. |
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
