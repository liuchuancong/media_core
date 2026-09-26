## 0.1.0

Initial release.

- Backend adapter: `MediaKitPlayerAdapter` + `MediaKitAdapterFactory` connect media_kit to the media_core adapter contract (`PlayerAdapter` + `PlayerVideo`).
- View: `MediaKitVideoView` carries media_kit's rendering output.
- Proxy: `MediaKitProxyUrlResolver` resolves stream addresses that must go through a proxy.
- Configuration: `MediaKitPlayerConfig` declares engine-side options, including the CDN allowlist for legacy-HEVC FLV — streams on that list go through core's FLV rewriter and loopback relay before reaching the engine.
- Shares the kernel with the other backends: sessions, the recovery ladder and event normalization come from `media_core`.
