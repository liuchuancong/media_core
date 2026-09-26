## 0.1.0

Initial release.

- Task queue: `DownloadManager` runs a set of `DownloadTask`s with a concurrency limit and queue state.
- Resumable transfers: `DownloadResumeDecision` decides between resuming and restarting, while `DownloadResume` records the breakpoint (ETag / range / bytes already on disk).
- Retry policy: failure classification (`DownloadFailureKind`) and backoff retry.
- Transport abstraction: the `DownloadTransport` interface with a default implementation, writing through `DownloadFileSink`.
- Progress and status: `DownloadProgress` and `DownloadStatus` are ready to feed straight into host UI.
