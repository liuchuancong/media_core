## 0.1.0

Initial release.

- Vertical feed: `FeedPlayerController` keeps one shared player for the whole feed and hands playback to the item that is on screen.
- Configuration: `FeedConfig` controls preload and reclaim ranges.
- Lifecycle: `FeedItemState` exposes each item as mounted / active / released; off-screen items release their resources according to policy.
- Optional next-item preload: start the next item early when the network allows it, so a swipe lands on already-playing video.
