# Changelog

The example application. It is not released and not versioned; this file records
what the demos demonstrate, so someone reading a demo can tell what changed
underneath it.

## Unreleased

### Changed

- The pool demo now **runs** the feature presets instead of only describing the pool:
  one settle of item 3 is replayed under `FeedConfig.recommendedPoolConfig`,
  `PlaybackListConfig.recommendedPoolConfig` and `LivePoolPolicy.defaults.toPoolConfig()`,
  and each row prints the config it used and the items the pool actually kept on the
  books. The walk's own header line is read from the same config too, so the narration
  cannot drift from what the pool was told. Running them is what surfaced the thing the
  section now prints as a warning: `LivePoolPolicy` promises one spare line and the pool
  keeps two, because `PlayerPoolConfig.warmSize` is read as "warm players" by one bound
  and as "players held in total" by another.

### Added

- `test/demo_log_test.dart`: the in-page event log collapses a repeating line
  into `×N`, so a ticker cannot push the operation and recovery records out of
  the window it exists to show.

### Changed

- Demo pages no longer rebuild the whole page on every transport report. The
  player, music, UI-style and media-session readouts are scoped to the widgets
  that show them, and the controls that used to repaint "because a tick happened"
  now repaint because they call `setState` themselves.
- The music page's background button is labelled for what it actually does:
  attach or detach the system media surface. Whether playback continues
  off-screen is `PlayerConfig` / `KernelOptions`, not this button.
- The player demo releases the previous handle before opening a new one. Each
  press used to leave an engine and its texture alive.
