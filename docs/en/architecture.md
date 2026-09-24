# Media Core Architecture

> The complete layered architecture of media_core: module responsibilities, mounting points, the full data flow of one playback, the recovery decision flow, and how to plug in a new backend.

## 1. Layer diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│ Application layer (entry points the host app consumes)          │
│                                                                 │
│  PlayerHandle (single player)  LivePlaybackController (live)    │
│  FeedPlayerController (vertical feed)  MediaPlayerView (widget) │
│  PlayerVisibilityBinding (auto pause/resume)                    │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ Kernel orchestration  PlayerKernel                              │
│  · create/release: select engine → build handle → register      │
│  · preload / pool / coordinator / eventBus hub                  │
│  · attachAudio / attachPresentation capability drivers          │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ Handle runtime  PlayerHandle (one per logical player)           │
│                                                                 │
│  PlayerRuntime (composition root)                               │
│   ├ PlayerAdapter (engine instance, swappable by recovery)      │
│   ├ PlayerSession + SessionController                           │
│   ├ PlaybackController (command/position/volume/rate mirror)    │
│   ├ GeometryController (video size / aspect ratio)              │
│   └ PlayerPlaybackBinding / PlayerGeometryBinding               │
│                                                                 │
│  Handle-owned modules                                           │
│   ├ LifecycleController (state machine)                         │
│   ├ RecoveryLadder (single decision point) + RecoveryTarget     │
│   ├ OperationRegistry/Tracker (operation records)               │
│   └ Serial operation queue + lifecycle generations              │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ Adapter backend layer                                           │
│  PlayerAdapter (engine contract)   PlayerAdapterBase (template) │
│  PlayerAdapterRegistry (register)  PlayerAdapterSelector (score)│
│  PlayerAdapterCapabilities   PlayerAdapterEvent (unified)       │
│  PlayerVideo (video widget output interface)                    │
└─────────────────────────────────────────────────────────────────┘

Infrastructure (consumed by the layers above): identity / core /
source / error / event / policy / platform / operation / task /
diagnostics …
Standalone building blocks (import on demand): cache / network /
recording / slot / state_machine / reconciler / bug / factory /
concurrency / reactive / result / util / fallback
```

## 2. Module responsibilities and mounting points

### Main chain (fully wired)

| Module | Responsibility | Mounted on | Integration point |
| --- | --- | --- | --- |
| `identity` | Strongly-typed IDs | everywhere | `PlayerId/SessionId/SourceId/GenerationId` in every event |
| `core` | Player domain, PlayerConfig, PlayerState | kernel | `Player.create()` → handle.id |
| `source` | **PlayerSource**: uri/protocol/format/headers | input of adapter.open | selection scoring, SessionContext, line fallback all key on it |
| `adapter` | Engine contract + registry + selector + capabilities | PlayerRuntime | `open(source)`/`play()`/unified events/`PlayerVideo.build()` |
| `runtime` | Composition root | inside PlayerHandle | `replaceAdapter()` swaps engines mid-life |
| `session` | Session context/state/snapshot | PlayerRuntime | `open(source)` rebuilds SessionContext (sourceId + generation) |
| `playback` | Command/state mirror | PlayerRuntime | bindings turn events into PlaybackState |
| `geometry` | Video size / aspect ratio | PlayerRuntime | VideoSize → MediaPlayerView AspectRatio |
| `lifecycle` | Player lifecycle state machine | PlayerHandle | play/pause/activate/deactivate transitions |
| `recovery` | Recovery ladder (decide + execute) | PlayerHandle (only) | adapter error → reportFailure → ladder → reopen/swap |
| `operation` | Operation records | PlayerHandle | `handle.onOperation`: one record per lifecycle call |
| `event` | Global event bus | PlayerKernel | normalized events via `_publish` |
| `coordinator` | Cross-player coordination | PlayerKernel | `_registerEverywhere` |
| `pool` | Instance pool | PlayerKernel | `acquire/recycle` soft reuse |
| `preload` | Preload bookkeeping | PlayerKernel | feed preloads the next item |
| `presentation` | Fullscreen/PiP/floating state machine | kernel + coordinator | `attachPresentation(driver)` |
| `policy` / `platform` | Cross-module policy / platform facts | SessionContext | carried with the source |
| `task` | Task queue primitives | LivePlaybackController | every live action is a queued task |
| `diagnostics` | MediaCoreLog hub | all layers | structured logs on every critical path |

### Application entry points

| Entry | Purpose | Built on |
| --- | --- | --- |
| `PlayerKernel.create()` → `PlayerHandle` | VOD / general playback | full main chain |
| `LivePlaybackController` | Live: line/engine sweep + watchdogs | main chain + task queue; handle's own ladder disabled |
| `FeedPlayerController` | TikTok-style vertical feed | one shared handle, next item preloaded |
| `MediaPlayerView` | Rendering | `adapter as PlayerVideo`, rebuilds on backendChanges |
| `PlayerVisibilityBinding` | Auto pause/resume on visibility | VisibilityController → handle.pause/play |

### Standalone building blocks

`cache`, `network`, `recording`, `slot`, `state_machine`, `reconciler`, `bug` (fault injection), `concurrency`, `reactive`, `result`, `util`. `factory` now only creates logical player identities (`PlayerFactory`/`DefaultPlayerFactory`); backend registration and selection belong exclusively to the `adapter` module.

## 3. Data flow of one playback

```text
App: kernel.create(config, source, preferredBackend)
 1. SourceService.resolve (optional real-URL resolution)
 2. selector.scoreTable(source) → best engine (protocol/format/live)
 3. Player.create() + factory.create() + PlayerRuntime assembly
 4. handle.initialize() → adapter.initialize() → lifecycle init
 5. _registerEverywhere: coordinators + pool

App: handle.open(source)
 6. _invalidateOperations(): generation++, stale ops die
 7. ladder.reset() → sessionController.recreateGeneration()
 8. session.updateContext(SessionContext(sourceId, generationId, source))
 9. adapter.open(source)   ← the PlayerSource enters the engine here
10. apply config.volume/rate + queued pending values + mute/audioOnly
11. autoPlay → _playInternal: adapter.play → playback.play
    → sessionController.play → lifecycle.activate → bus 'play'

App: MediaPlayerView(handle)
12. adapter as PlayerVideo → build() widget into the tree
13. VideoSize event → geometry → AspectRatio

Engine events (while playing)
14. adapter.events → three parallel consumers:
    PlayerPlaybackBinding → playback mirror
    PlayerGeometryBinding → geometry mirror
    handle._onAdapterEvent → session transitions + bus + loop restart
```

## 4. Recovery decision flow (single decision point)

```text
Any failure source (adapter error / watchdog stall / open throw / no progress)
        │  reportFailure(RecoveryFailure)   ← the only entry
        ▼
RecoveryLadder owned by PlayerHandle (decides)
        ▼
[same-engine reopen] → [next line (source candidates)] → [next engine] → exhausted
        │ executes via RecoveryTarget (the handle)
        ▼
_reopenOnCurrentBackend / _swapTo (stage the new engine, verify, then swap)
        │ each step _verifyPlayback: position must advance within 8s
        ▼
exhausted → recoveryEvents 'exhausted' + bus fatal → the caller decides
```

Live mode exception: LivePlaybackController disables the handle's ladder and runs the equivalent sweep in its own single-slot task queue, reporting failure once on `onError`.

## 5. Extending: plugging in a new engine

```dart
class MyEngineAdapter extends PlayerAdapterBase implements PlayerVideo {
  // 1. implement onOpen/onPlay/onSeek/… translate engine events into
  //    emitPlaying/emitPositionChanged/… unified events
  // 2. implements PlayerVideo: available + build()
  // 3. declare capabilities; the selector scores from them
}

final kernel = PlayerKernel()..registerBackend(registration);
// the selector scores it automatically; recovery can use it as a candidate
```

## 6. Design invariants (read before changing code)

1. **Recovery has exactly one decision point**: RecoveryLadder is constructed only inside PlayerHandle; everyone else reports.
2. **PlayerSource is the only selection input**: do not hand raw URLs to the framework to re-parse.
3. **playIntent wins over the mirror**: engines that autoplay must `declarePlayIntent(true)`.
4. **Engine swaps must verify**: open returning ≠ playing; position advancing is success (`_verifyPlayback`).
5. **Serialized operations + generation invalidation**: stale operations cannot commit state.
6. **Facade streams stay stable**: `adapterEvents/backendChanges/sourceChanges` survive engine swaps; never hold the old adapter.
