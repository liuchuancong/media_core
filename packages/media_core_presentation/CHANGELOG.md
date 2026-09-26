## 0.1.0

Initial release.

- Presentation state coordination: fullscreen, picture-in-picture and the in-app floating window are mutually exclusive, and `PresentationStage` is the single value that says which one is active.
- Video-orientation awareness: `PortraitFullscreenStrategy` and `LandscapeOnPortraitStrategy` decide how a landscape video fills a portrait device and how a portrait video fills a landscape fullscreen.
- Overlays: `MediaPlayerOverlay` / `PlayerOverlaySlot` / `PlayerOverlayVisibility` show and hide controls, danmaku and other overlays with the presentation state, so no host has to work that out itself.
- Wired to the kernel's presentation module: the driver chain (`PresentationDriverChain`) keeps switches ordered and never lets two states be active at once.
