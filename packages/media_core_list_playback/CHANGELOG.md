## Unreleased

- Same clarification as the feed's preset: `warmSize: 3` counts warm players, so it is the headroom a host rises into when it widens `preloadCount`; the "three players cover an endless list" sentence describes the window (one item each side, plus the one playing).
- Switch coalescing: a jump requested while an item is still opening **retargets** the running open instead of queueing behind it, and the index is re-checked both before touching the engine and before reporting the item settled. Rapid `next()` taps or a dragged list no longer pay one full open per row crossed, and a superseded open can no longer mark a newer row as finished loading.
- `dispose()` releases callers still awaiting an in-flight open instead of leaving them hanging.

## 0.1.0

Initial release.

- List playback: `PlaybackListController` owns the ordered list and the current item, while `PlaybackListPlayer` plays the whole list in one window.
- Switching: swipe up and down to move between items, each keeping its own playback position.
- Resume: `PlaybackProgressStore` records progress per item, so returning to an item continues where it stopped.
- Configuration and items: `PlaybackListConfig` declares swipe and preload behaviour, `PlaybackListItem` describes an entry.
