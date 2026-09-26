## 0.1.0

Initial release.

- In-app small window: `FloatingWindowController` handles show / hide / drag / snap, and `FloatingWindowOverlay` is an overlay you can drop straight into an `Overlay`.
- Pure geometry: `FloatingWindowPlacement` and `FloatingAnchor` only compute coordinates and snapping, so they can be tested without rendering anything.
- Configuration split from presentation: `FloatingConfig` declares size, margins and snapping behaviour, `FloatingWindowPresenter` drives it.
