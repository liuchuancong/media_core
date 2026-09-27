## Unreleased

- Re-exports the engine: `package:fvp/mdk.dart` (the mdk player API — `MediaInfo`, stream and codec info, …) and `package:fvp/fvp.dart` (`registerWith`, `VideoPlayerRegistrant`), so a host reaches them from its single dependency on this adapter. fvp's `Player`, `PlaybackState` and `MediaType` stay hidden: `media_core` exports its own types under those names and importing both barrels would be ambiguous.

## 0.1.0

Initial release.

- fvp (libmdk) playback backend adapter: `FvpPlayerAdapter`, `FvpAdapterFactory`, `FvpVideoView`.
