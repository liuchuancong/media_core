## Unreleased

- **Breaking**: one foreground service per feature. `BackgroundExecutionService` (one service, one notification id, one channel, one wake lock shared by every job) is now `JobForegroundService` plus `RecordingForegroundService` / `DownloadForegroundService` / `GenericForegroundService`, each with its own channel (`media_core.recording` / `.download` / `.background`), its own notification id (`0x4D52` / `0x4D44` / `0x4D43` — generic keeps the old value so a user's existing mute choice survives the upgrade) and its own wake-lock tag. A session handle is `(featureCode << 16) | localId`, so `update` and `release` find their way back to the service that issued them without a second registry that could disagree with the first. The point is the timeout: `onTimeout` stops only its own service, where before a recording that ran out of Android's `dataSync` allowance silently dropped the protection of the download sharing that instance. Recording declares `specialUse` (a live capture has no useful bound, unlike a transfer that ends when the bytes do), with the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` justification in the manifest.
- The channel's `acquire` gained an `owner` argument — the wire spelling of `BackgroundServiceOwner`, and what decides which service holds the session. `BackgroundExecution.acquire`/`acquireDetailed` take it as `target:`; a call that names none falls back to the notification's `kind` for compatibility with an older Dart side, which is a fallback rather than a policy. `NativeBackgroundBackend.targetFor` is the one place the two vocabularies meet and it refuses `mediaSession`: playback is not a job, and parking it on a download's line would be worse than an error.
- `flutter_foreground_task` is gone from the dependencies: it was adopted for a rewrite that never happened, and its one-service-one-notification model is the opposite of this split. The hand-written Java services are the implementation, as they always were.
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
