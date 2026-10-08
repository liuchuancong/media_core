## Unreleased

- Re-exports the engine: `package:better_player_plus/better_player_plus.dart` (`BetterPlayerController`, `BetterPlayerConfiguration`, `BetterPlayerDataSource`, …), so a host reaches it from its single dependency on this adapter. No name clashes with `media_core`.

## 0.1.0

Initial release.

- Backend adapter: `BetterPlayerAdapter` connects better_player / video_player to the media_core adapter contract (`PlayerAdapter` + `PlayerVideo`), registered by `BetterPlayerAdapterFactory`.
- Data source building: the adapter maps a `PlayerSource` (network / file, plus its `headers` and `isLive`) onto a `BetterPlayerDataSource`; `BetterPlayerDataSourceBuilder` is the last-chance rewrite hook applied to that data source before every setup. Asset sources are not supported — the installed better_player_plus exposes no asset data-source type.
- Video surface: the adapter implements `PlayerVideo` itself, so `BetterPlayerAdapter.build()` returns the `BetterPlayer` widget and the viewport fit is applied through `setOverriddenFit` rather than a wrapper widget.
- Shares the kernel with the other backends: sessions, recovery and event normalization all come from `media_core`; this package only owns engine details.
