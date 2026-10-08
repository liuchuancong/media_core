## Unreleased

- Re-exports the engine: `package:fvp/mdk.dart` (the mdk player API — `MediaInfo`, stream and codec info, …) and `package:fvp/fvp.dart` (`registerWith`, `VideoPlayerRegistrant`), so a host reaches them from its single dependency on this adapter. Nothing is hidden: `media_core`'s own public types use composed names (`PlayerIdentity`, `PlayerCoreState`, `PlayerTransportState`, `PlayerMediaType`), so importing both barrels stays unambiguous even against mdk's `Player`, `PlaybackState` and `MediaType`.

## 0.1.0

Initial release.

- fvp (libmdk) playback backend adapter: `FvpPlayerAdapter`, `FvpAdapterFactory`, `FvpVideoView`.
