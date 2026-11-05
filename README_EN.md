# media_core

A reusable cross-platform Flutter player core: **a platform-agnostic orchestration layer** +
**packages split by capability**.

The core package (`packages/media_core`) carries 46 modules covering the hard part of playback —
sessions and generations, command serialization, recovery decisions, pooling, event normalization —
without any platform code, UI or theming. The workspace holds 26 packages: 1 kernel + 4 video
backends + 1 audio-only backend + 15 capability packages (UI, system media surfaces, live
orchestration, danmaku, …) + 5 infrastructure packages (logging, memory, platform probes, win32
utilities, loopback ingest).

> 📐 Full layered architecture (module responsibilities, mount points, data flow, recovery
> ladder): [English](doc/en/architecture.md) · [中文](doc/zh-Hans/architecture.md)
>
> 📚 Per-module docs: `doc/en/`（also [中文](doc/zh-Hans/README.md) and
> [繁體中文](doc/zh-Hant/README.md)）

> 🌏 本页有中文版：[README.md](README.md)

## 30-second setup

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:media_core_ui/media_core_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKitPlayerAdapter.ensureInitialized();

  // System media surfaces (notifications / lock screen / SMTC): one line,
  // and every player created afterwards mounts its notification automatically.
  await MediaSessionBootstrap.enable();

  final kernel = PlayerKernel()..registerBackend(const MediaKitAdapterFactory().registration());

  final handle = await kernel.create(
    source: PlayerSource(id: SourceId('demo'), uri: Uri.parse('https://example.com/video.mp4')),
    config: const PlayerConfig(autoPlay: true),
  );

  runApp(MaterialApp(
    home: Scaffold(
      // Video + controls in six design languages + pinch-zoom + screenshots,
      // all inside this one widget.
      body: AspectRatio(aspectRatio: 16 / 9, child: MediaCorePlayerView(handle: handle)),
    ),
  ));
}
```

`MediaCorePlayerView` resolves its style per platform (Android→material, iOS→cupertino,
macOS→macos, Windows→fluent, Linux→yaru); you can also force any of them:

```dart
MediaCorePlayerView(handle: handle, style: PlayerControlsStyle.neumorphic)  // or fluent / cupertino / …
```

To build your own UI, the lower-level pieces are just as usable: `MediaPlayerView` (video only) +
`PlayerControlsController` (state and actions) + `PlayerControlsTheme` (tokens) — together they
are one custom control bar.

## Architecture overview

```text
PlayerSource ─┐
              │   SourceService (resolve / validate / probe)
              ▼
PlayerKernel ──▶ PlayerAdapterSelector ──▶ PlayerAdapterRegistry (media_kit / ijk / better_player / fvp)
    │                scores backends by protocol, format, live capability and priority
    │
    └── PlayerHandle (the facade for one player; the only entry point for actions)
            │
            ├── PlayerRuntime          composition root: adapter + session + playback + geometry + bindings
            │      ├── PlayerSession        session + Generation (stale async results are dropped by it)
            │      ├── PlaybackController   playback state machine (serialized commands)
            │      └── GeometryController   size / rotation / fit
            ├── SessionController      session lifecycle state
            ├── LifecycleController    background / active / detached (fed by AppLifecycleDriver)
            ├── RecoveryLadder         **the single recovery decision point**:
            │                          reopen on this backend → next line → next backend → give up
            ├── OperationTracker       operation log (observable via `onOperation`)
            └── ScreenshotManager      frame grabs (engine grab / surface grab dual channel)

PlayerKernel also owns the cross-player collaborators:
    PlayerPool · PreloadManager · PlayerEventBus · GlobalPlayerCoordinator · capability drivers (audio / presentation / platform)

The single-slot task queue (`TaskManager`) does not live on the handle: capability packages that
need "one thing at a time" (live line/engine sweeps, download queues) each hold their own, and it
is the serialization authority for that orchestration.
```

Three rules hold across the repository:

- **Capabilities are declared, not guessed**: `PlayerAdapterCapabilities` is the single source of
  backend capability, `PlatformCapabilities` / `PlatformCodecCapabilities` the single source of
  device facts (filled in by probes); both keep a way to say "unknown".
- **One decision point**: recovery is decided only in `RecoveryLadder` (consumers report via
  `reportFailure`, observe via `recoveryEvents`); an engine switch must verify playback position
  is actually advancing.
- **Serialization is correctness**: public actions run through queues in order, and the queue's own
  state is the only gate (task queues, operation registries, generation guards) — no scattered
  boolean flags.

## The self-healing chain

When an adapter reports an error, the single decision point `RecoveryLadder` walks the ladder, and
every step needs **evidence that playback is really moving** (position advancing; live sources
re-baseline after a switch) to count as success:

1. **Reopen on the same backend** (`sameBackendReopen`): re-open the current source in place;
2. **Next line** (`nextLine`): the next candidate source (live multi-line streams);
3. **Next backend** (`nextBackend`): the next engine in the registry, refreshing signed
   single-use URLs before switching;
4. **Give up**: candidates exhausted, a terminal event with the reason is published.

The whole chain is observable through `PlayerEventBus` and `recoveryEvents`; retry budgets,
backoff and candidate strategy come from `PlayerConfig` / `KernelOptions` / `RecoveryPolicy`.

## Capability packages

| Package                        | Capability          | One-liner                                                                                                                      |
| ------------------------------ | ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `media_core_ui`               | Player UI           | **Six design languages** (material / cupertino / fluent / macos / yaru / neumorphic) over one controls layer; pinch/double-tap zoom and screenshots |
| `media_core_mediasession`     | System media surface | Notifications / lock screen / SMTC + audio focus; **one `enable()` per process, every player mounts automatically** (Linux pending `flutter_media_session` MPRIS) |
| `media_core_native`           | Platform probes     | Codec hardware-decode and resolution caps, memory/cores, system features, and **background keep-alive** (foreground services / wake locks / keep-alive); five platform implementations, answers delivered per session and adapter |
| `media_core_live`             | Live streaming      | Line/engine sweeps, stall watchdogs, host-paced instant retry (on a single-slot task queue)                                     |
| `media_core_feed`             | Vertical video feed | One shared player re-sourced per swipe, snap scrolling, next-item preload                                                       |
| `media_core_list_playback`    | List playback       | Single-window up/down switching, per-item position memory and resume                                                            |
| `media_core_multiview`        | Multi-view wall     | Monitoring-style video wall: per-cell health, single audio owner, decode budget, per-cell danmaku, patrol rounds, per-cell lists |
| `media_core_danmaku`          | Danmaku (bullet chat) | Transport contract + message normalization + dedupe/backlog gates + content filters + session fencing                          |
| `media_core_audio`            | Music               | Source registry and resolution (signed URLs with expiry), queue with four play modes, lyrics (LRC/translation/per-word), desktop lyric window, downloads (ffmpeg) |
| `media_core_cast_dlna`        | Casting             | DLNA/UPnP backend: SSDP discovery, GENA eventing (falls back to polling when lost), SOAP commands, local media server (Range + token-gated) |
| `media_core_ingest`           | Ingest proxy        | Local loopback HTTP proxy: HLS rewriting, cookie jar, child-segment transforms (for scrambled live segments), so players consume without cross-origin issues |
| `media_core_recording_ffmpeg` | Recording           | FFmpegKit segmented MPEG-TS recording + CSV journal; a failure loses seconds, not the show; processes take background keep-alive sessions by default (keeps recording with the screen off) |
| `media_core_download`         | Downloads           | Bounded concurrent queue, resumable transfers (verify first, then resume), retry budgets and progress                            |
| `media_core_presentation`     | Presentation seam   | Window-level driver contracts + a shared overlay stage (slots / hover show-hide), reused by the window packages                 |
| `media_core_fullscreen`       | Fullscreen          | System fullscreen and window-level fullscreen variants, with orientation strategy                                               |
| `media_core_pip`              | Picture-in-picture  | Desktop always-on-top mini window (aspect-locked) + Android overlay handoff + iOS system PiP (pip_kit); mobile "can enter, cannot exit" is a platform fact reported honestly |
| `media_core_notify`           | Job notifications   | Foreground running lines + task progress/result notifications (one line each for downloads and recordings); owned by foreground services on Android |
| `media_core_logging`          | Leveled logging     | Global hub: level/category switches, multiple sinks (console / memory ring / rotating file), scoped fields                       |
| `media_core_memory`           | Memory accounting   | Per-contributor declared totals + measured device snapshots; budget thresholds drive four pressure levels                        |

### Pooled playback orchestration

`PlaybackPoolOrchestrator` drives list / feed / live playback from a **bounded player pool**:
swap sources instead of rebuilding (the decoder is created once), visibility-driven with hysteresis
(half-visible items do not start/stop repeatedly), neighbour prewarm, and under rising
`ResourcePressure` it first drops prewarms, then releases idle players. Players come from two host
seams, `PoolPlayerHost` / `PoolPlayerHandle`; `KernelPoolPlayerHost` already wires the kernel
instance pool, and the capability packages ship recommended presets
(`FeedConfig.recommendedPoolConfig`, `LivePoolPolicy.toPoolConfig()`, …).

### Leveled logging and memory

Logging is **fully silent by default** (`LogLevel.nothing`) and the host turns it on. Info level
already carries the full key-milestone trail (player created / source opened, engine and line
switches, recovery decisions, task start/end); when investigating one problem, raise only that
category:

```dart
MediaCoreLog.level = LogLevel.info;                            // key milestones
MediaCoreLog.level = LogLevel.debug;                           // plus best-effort cleanups and details
MediaCoreLog.setCategoryLevel(LogCategory.live, LogLevel.trace);
final ring = MediaCoreLog.attachMemorySink(capacity: 500);
LogScope.run({'roomId': room.id}, () => player.open(source));   // every log in this scope carries the room id
```

Memory has two views — "who is using it" (modules `report`/`withdraw` per contributor, summable)
and "how much in total" (device truth installed by the host as a provider). No Dart API can report
decoder/texture bytes, so modules report conservative **declared** values (used for ordering and
budgets) while disk caches/downloads/recordings report **measured** ones; pressure maps to four
levels at 512 MiB / 70% / 85% and is bridged into the resource layer's `ResourcePressure`.

## Backend adapters

| Package                    | Backend                            | Factory                      | Notes                                                                     |
| -------------------------- | ---------------------------------- | ---------------------------- | ------------------------------------------------------------------------- |
| `media_core_media_kit`   | media_kit (vendored in this repo)  | `MediaKitAdapterFactory`   | Widest protocol/format coverage, the default first choice; ships a decode strategy (hardware or explicit software per device capability) |
| `media_core_ijk_player`  | ijk (`flv_lzc`)                  | `IjkPlayerAdapterFactory`  | FLV / H.265, mobile                                                        |
| `media_core_better_player` | better_player 1.33 (federated: Media3 / AVPlayer / libmpv / Shaka) | `BetterPlayerAdapterFactory` | One API across all platforms; Android runs Media3, desktop and web coverage included |
| `media_core_fvp`         | fvp (libmdk)                       | `FvpAdapterFactory`        | Another desktop/mobile decode path                                         |
| `media_core_mpv_audio`   | mpv (audio-only)                   | `MpvAudioAdapterFactory`   | Audio backend: no video surface, for background music/podcasts             |

Registration is uniform: `kernel.registerBackend(const XxxAdapterFactory().registration())`.

## Platform support

|                                          | Android | iOS   | macOS | Windows         | Linux                      |
| ---------------------------------------- | ------- | ----- | ----- | --------------- | -------------------------- |
| Playback (any of the five backends)      | ✅      | ✅    | ✅    | ✅              | ✅                         |
| System media surface (notifications / lock screen / SMTC) | ✅ | ✅ | ✅ | ✅ | ⏳ pending MPRIS |
| Capability probes (hardware decode / device / system features) | ✅ | ✅ | ✅ | ✅ | ✅ (per-codec pending libva) |
| System PiP / picture-in-picture          | ✅ overlay handoff | ✅ pip_kit | in-app mini window ✅ · system PiP ⏳ | — in-app mini window | — in-app mini window |
| Desktop lyrics window                    | ✅      | —    | ✅    | ✅              | ✅                         |

## Documentation

- English: [doc/en/README.md](doc/en/README.md) · Architecture: [architecture.md](doc/en/architecture.md)
- 中文：[doc/zh-Hans/README.md](doc/zh-Hans/README.md) · 架构：[architecture.md](doc/zh-Hans/architecture.md)
- 繁體中文：[doc/zh-Hant/README.md](doc/zh-Hant/README.md)
- Background runtime (foreground services / keep-alive / device checklist):
  [doc/media_core_background_runtime_architecture.md](doc/media_core_background_runtime_architecture.md)

Package-level detail: media surfaces in `packages/media_core_mediasession/README.md`, the probe
contract in `packages/media_core_native/README.md`, permissions and platform manifests in
`packages/media_core_audio/doc/permissions.md`.

## Repository conventions

- **The core depends on no platform**: `media_core` depends only on Flutter, the two infrastructure
  packages (`media_core_logging` / `media_core_memory`) and a few pure-Dart libraries; platform code
  lives in capability packages or `media_core_native`.
- **Capability packages implement core contracts**: they mount into the kernel through
  `KernelAudioDriver` / `KernelPresentationDriver` / `PlatformProvider` and the like; the core never
  depends back on them — so they can be included per-need or removed wholesale.
- **Unknown ≠ unsupported**: every layer of capability and device fact keeps an "unprobed /
  unreported" expression (`bool?`, `reported` flags); the caller decides "should we try", instead of
  treating silence as no.
- **A module's `library.dart` is generated** (`// GENERATED MODULE LIBRARY` header); when adding a
  module, add one export by hand.

## Workspace layout

```text
packages/
  media_core/                       kernel: 46 modules + orchestration (kernel / handle / runtime)
  media_core_media_kit/             media_kit adapter (default backend)
  media_core_ijk_player/            ijk (flv_lzc) adapter
  media_core_better_player/         better_player 1.33 adapter (all-platform federated)
  media_core_fvp/                   fvp (libmdk) adapter
  media_core_mpv_audio/             mpv audio-only adapter
  media_core_native/                platform probes (android / ios / macos / linux / windows)
  media_core_win32/                 Win32 FFI utilities (window enumeration / geometry / fullscreen)
  media_core_ui/                    the six design-language control sets
  media_core_mediasession/          notifications / lock screen / SMTC + audio focus
  media_core_notify/                job running lines and progress/result notifications
  media_core_audio/                 music: sources / queue / lyrics / desktop lyrics / downloads
  media_core_cast_dlna/             DLNA/UPnP casting
  media_core_ingest/                local loopback ingest proxy (HLS rewrite / cookie jar / segment transforms)
  media_core_presentation/          presentation seam (window driver contracts + overlay stage)
  media_core_fullscreen/            fullscreen (two variants + orientation strategy)
  media_core_pip/                   picture-in-picture (desktop mini window + Android overlay + iOS system PiP)
  media_core_danmaku/               danmaku
  media_core_live/                  live orchestration
  media_core_feed/                  vertical video feed
  media_core_list_playback/         list playback (position resume)
  media_core_multiview/             multi-view wall (monitoring-style)
  media_core_recording_ffmpeg/      recording (FFmpegKit segmented recording)
  media_core_download/              downloads (queue + resume + retry)
  media_core_logging/               leveled logging
  media_core_memory/                memory accounting
example/                            sample app: 10 runnable pages + module quick-look
```

`media_kit` and `media_kit_video` are not distributed with this repo: they are fetched from
`Predidit/media-kit` at the ref pinned in `packages/media_core_media_kit`. The PureLive-branch
patches (`setVideoOutputEnabled`, Windows `frameRevision`, …) are therefore **not** available here,
and adapters must not rely on them.

The sample app makes each of the above clickable and visible: `player` (lifecycle and operation
log), `live` (multi-line and engine fallback), `feed` (vertical swipe), `media-session` (the
auto-mounted system media surface), `ui-styles` (six styles switched live + zoom + screenshot),
`music` (source → queue → lyrics → desktop lyrics → download), `multiview` (video wall),
`presentation` (fullscreen / PiP / overlay / danmaku), `memory` (memory dashboard) and
`audio-tap` (audio analysis), plus the module quick-look printing platform probe reports and
pure-logic demos.
