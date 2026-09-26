## 0.1.0

Initial release.

- Multi-cell live wall: `MultiviewController` runs N players side by side, laid out by `MultiviewLayout`.
- One audio owner: only one cell is audible at a time; `MultiviewAudioMode` decides whether that is a pinned cell, the focused one, or everything muted.
- Decode budget: `MultiviewBudgetPolicy` caps how many cells decode at once, with the rest downgraded or stepped aside according to policy.
- Quality policy: `MultiviewQualityPolicy` / `MultiviewQualityPreference` / `MultiviewQualityResolver` pick a resolution per cell from its size and the remaining budget.
- Per-cell health: `MultiviewCellStatus` and `MultiviewCellFailureKind` are tracked per cell, so one failing cell does not take the wall down.
- Per-cell danmaku: wired to `media_core_danmaku`, each cell filtering independently.
