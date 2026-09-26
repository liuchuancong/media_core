## 0.1.0

Initial release.

- FFmpeg recording backend: captures network streams through `ffmpeg_kit_extended_flutter` and writes them out as segmented MPEG-TS.
- Wired to the kernel's recording contract: `FfmpegRecordingBackend` handles start / stop / segment rotation and failure reporting.
- Background execution: recording goes through `BackgroundExecutionStarter` to `media_core_native`'s foreground service, so it keeps going with the screen off; the session has to be taken before the process starts.
