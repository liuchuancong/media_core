## 0.1.0

Initial release.

- Platform fullscreen state: `FullscreenPlatform` abstracts where desktop fullscreen really comes from (true fullscreen is not the same as a maximized window).
- Window-level fullscreen: the `FullscreenWindow` contract and the `window_manager` backed implementation (`WindowManagerFullscreenWindow`).
- Per-orientation fit strategies: `FullscreenFitStrategy` decides how a landscape video fills a portrait device (letterbox / crop / rotate).
- Configuration and driver: `FullscreenConfig` and `FullscreenDriver`.
