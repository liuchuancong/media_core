## Unreleased

- Re-exports the engine: `package:flv_lzc/fijkplayer.dart` (`FijkPlayer`, `FijkView`, `FijkValue`, `FijkOption`, …), so a host reaches it from its single dependency on this adapter. No name clashes with `media_core`.

## 0.1.0

Initial release.

- Backend adapter: `FlvLzcPlayerAdapter` + `FlvLzcPlayerAdapterFactory` connect ijkplayer (`flv_lzc`) to the media_core adapter contract (`PlayerAdapter` + `PlayerVideo`).
- Engine options: raw `(domain, key, value)` triples in ijkplayer's own vocabulary (`EngineOption`, with `domain` mapped onto the `FijkOption` categories `host` / `format` / `codec` / `sws` / `swr` / `player`), written before every open and merged last-value-wins with options applied at runtime; reconnect, timeouts and proxy settings belong to the caller, not to a built-in preset. The adapter only writes two things itself: the source's request headers as the `headers` / `user_agent` format options, and the `enable-snapshot` host option its screenshot capability depends on.
- Helpers: `FijkHelper` translates source headers (`sourceHeaderOptions`), maps the logging hub's level onto the engine's own (`syncLogLevel`), and converts `BoxFit` to `FijkFit` (`getIjkBoxFit`) plus `formatDuration`.
- Capability declaration: the adapter reports the protocols, containers and codecs it supports, which is what lets the kernel pick an engine for a given source.
