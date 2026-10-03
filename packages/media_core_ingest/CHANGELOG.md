# 0.1.0

- `IngestNeed` / `IngestStrategy` / `resolveIngestPlan`: one place that decides
  whether a source is handed to the player directly or through a relay, instead
  of a per-host branch in every playback transport.
- `LoopbackIngestRelay`: rewrites an HLS manifest tree (children, keys, maps,
  nested playlists) to absolute loopback URLs and proxies the children upstream
  with the caller's headers. Fixes sources whose bare or absolute-path children
  a native resolver turns into local paths.
- `FfmpegIngestRelay`: remuxes an upstream into a rolling loopback HLS tree for
  containers the player cannot parse and for URLs that expire mid-stream.
