## 0.1.0

Initial release.

- Backend adapter: `BetterPlayerAdapter` connects better_player / video_player to the media_core adapter contract (`PlayerAdapter` + `PlayerVideo`), registered by `BetterPlayerAdapterFactory`.
- Data source building: `BetterPlayerDataSourceBuilder` turns a media_core source and its headers into a better_player data source.
- View: `MediaCoreVideoPlayer` exposes the video_player compatible render entry point for hosts that cannot use textures.
- Shares the kernel with the other backends: sessions, recovery and event normalization all come from `media_core`; this package only owns engine details.
