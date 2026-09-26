## 0.1.0

Initial release.

- List playback: `PlaybackListController` owns the ordered list and the current item, while `PlaybackListPlayer` plays the whole list in one window.
- Switching: swipe up and down to move between items, each keeping its own playback position.
- Resume: `PlaybackProgressStore` records progress per item, so returning to an item continues where it stopped.
- Configuration and items: `PlaybackListConfig` declares swipe and preload behaviour, `PlaybackListItem` describes an entry.
