## 0.1.0

Initial release.

- Backend adapter: `FlvLzcPlayerAdapter` + `FlvLzcPlayerAdapterFactory` connect ijkplayer (`flv_lzc`) to the media_core adapter contract (`PlayerAdapter` + `PlayerVideo`).
- Live-oriented options: reconnect, timeouts, proxy, headers and snapshots are all set on the adapter side, so hosts never touch the engine directly.
- Helpers: `FijkHelper` covers engine initialization and platform differences, `FijkProxyUrlResolver` resolves proxy addresses.
- Capability declaration: the adapter reports the protocols, containers and codecs it supports, which is what lets the kernel pick an engine for a given source.
