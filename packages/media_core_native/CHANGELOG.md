## Unreleased

- `NativeBackgroundBackend` implements the core's `BackgroundExecutionBackend` over the existing channel: it turns a `BackgroundRequest` into the words and glyph the plugin already reads, and its refusal into a reason, so recording — and next the download — go through one runtime instead of each starting what they like. `BackgroundExecution.acquireDetailed` is `acquire` with the reason kept (`unsupportedPlatform`, `serviceRefused`, `pluginMissing`, `noPlatformBinding`), because `acquire`'s null answered four different questions with one word and a runtime that has to tell the user what to do about it needs to know which one it was; `acquire` itself is unchanged. `NativeBackgroundRuntime.shared` is the one registry every job in the process shares, created on first use and replaced by whatever a host installed first.

## 0.2.0

- New background execution capability (`BackgroundJobKind`, `BackgroundExecutionStarter`): one entry point for foreground service, notification, wake lock and keep-awake, shared by audio and recording.
- Permissions are requested by the plugin itself; if the host declines, everything still runs — the notification just is not visible.
- One service carries several sessions, and releasing one only gives up its own slot.
- A recording session must be taken before the process starts, otherwise the foreground service budget is not available to it.

## 0.1.0

- Platform capability probe: codec support, device facts and system features are asked once and carried into every session, instead of re-probing on each playback.
- `canDecodeInHardware` is three-valued: `null` means "not asked yet" and it never returns a false `false`.
- `NativePlatformProvider` / `PlatformProbeReport` carry the probe results; `MethodChannelMediaCoreNative` is the channel implementation.
