# media_core_notify

User-facing notifications for `media_core`: what a download or a recording ended
with, and one line that says what is running right now.

## Responsibility

**Owns**

- `MediaCoreNotify` — the on/off switch, the permission question, and posting an
  event. Every call is incapable of failing the job it reports for.
- `NotifyTone` — what an event is allowed to do to the user (sound, banner,
  importance, whether it can be swiped away), decided in one table instead of at
  each call site.
- `ForegroundJobs` — the running-jobs **line**: it reads the sessions the
  background runtime holds and composes one notification from them (loudest
  first, the rest counted), reposted at most once per second. It owns no list of
  jobs and starts no service.
- `LocalNotificationClient` — the seam. `FlutterLocalNotificationsClient` is the
  default implementation; nothing above that file touches the plugin.

**Does not own**

- The **media** notification (playback controls, artwork, lock screen, SMTC,
  MPRIS). That is [`media_core_mediasession`](../media_core_mediasession), which
  publishes it through `audio_service`. Two packages drawing one media
  notification is a doubled tray, so the boundary is by surface, not by
  convenience.
- **Process protection.** Keeping a recording or download alive with the screen
  off needs an Android wake lock, an iOS background assertion, macOS
  idle-sleep prevention and `SetThreadExecutionState` on Windows. None of that is
  a notification, and `flutter_local_notifications` offers none of it: it is
  [`media_core_native`](../media_core_native).
- On Android, the **job notification** is `media_core_native`'s foreground
  service's own, and `ForegroundJobs` deliberately draws nothing there: one
  notification must be owned by one backend, and a foreground service may only be
  started by the process that holds it. Where no such service exists — iOS,
  macOS, Windows, Linux — the line this package posts is the only thing that says
  a job is running, so it is posted as an ordinary notification. It never was the
  thing keeping the work alive, and the plugin's `startForegroundService` path
  (a second service, a second notification, a manifest entry every host had to
  write) is gone.

## Who may depend on it

Leaf capability package, like `media_core_mediasession` and
`media_core_presentation`: business modules may reference it through a policy
value (`NotifyOn`) and a callback, and only an app or a module that actually
posts events should take the dependency. Nothing in `media_core` depends on it.

## Dependencies and platform requirements

- [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) `^22.3.2` —
  which requires Dart `^3.10.0` and Flutter `>=3.38.1`. This package's SDK floor
  is that constraint, not a choice.
- [`media_core_native`](../media_core_native) `^0.2.0` — for the job vocabulary
  (`BackgroundNotification`, `BackgroundJobKind`, `BackgroundProgress`) and for
  the Android small-icon drawables this package references by name
  (`ic_stat_media_core_record`, `_download`, `_task`).

| platform | a posted event | the running line |
| --- | --- | --- |
| Android | notification on a named channel | native's foreground-service notification |
| iOS / macOS | notification centre entry | a non-dismissible notification, no banner per update |
| Windows | toast | a normal notification (no service exists here) |
| Linux | desktop notification where a server exists | dropped silently where none does |
| web | no-op reporting `false` | no-op |

### Setup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaCoreNotify.enable();          // register channels, install the tap handler
  await MediaCoreNotify.requestPermission(); // Android 13+: POST_NOTIFICATIONS
  runApp(const MyApp());
}
```

To let a tap open something, pass `NotifySetup(onTap: ...)` to `enable`. On
Android, `POST_NOTIFICATIONS` is already declared by `media_core_native`; if you
also want the plugin's own foreground service (you probably do not — see
*Does not own* above), that is the `AndroidManifest.xml` step in the
`flutter_local_notifications` README.

## Public entry point

`package:media_core_notify/media_core_notify.dart` — `MediaCoreNotify`,
`NotifyEvent`, `NotifyTone`, `NotifyChannel`, `NotifyOn`, `NotifySetup`,
`ForegroundJobs`, `LocalNotificationClient`, `FlutterLocalNotificationsClient`.

## Usage

```dart
// A module that reports outcomes, filtered by what the host asked for:
await MediaCoreNotify.postOutcome(
  NotifyEvent(
    title: '下载完成',
    body: '${task.fileName} · ${task.sizeInBytes} B',
    tone: NotifyTone.success,
    kind: BackgroundJobKind.download,
    id: task.notificationId, // the progress line becomes the result in place
  ),
  policy: notifyOn,
);

// A running job is not announced here at all. It takes a lease from the runtime,
// and the line is a view over the leases:
final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
BackgroundRuntimes.current = registry;
await MediaCoreNotify.enable(); // turns on the line too — watch() is called for you

final result = await registry.acquire(
  const BackgroundRequest(
    id: 'recording/room-42',
    kind: BackgroundExecutionKind.recording,
    title: '正在录制',
    description: 'room-42 · 00:12',
  ),
);

if (result case BackgroundAcquireSuccess(:final lease)) {
  // …the job updates its own lease, and the line follows it.
  await lease.release(); // the line falls with the last lease, not the first
}

await ForegroundJobs.hide(); // silence the line without touching the jobs
```

`enable()` may run before the registry exists — a host wires notifications in `main()`
and the background backend appears at the first job — so the line waits for
`BackgroundRuntimes.changes` rather than asking once. `MediaCoreNotify.disable()` hides
the line along with turning the rest of the package off.

## Testing

```powershell
flutter test          # 21 cases, no platform required
flutter analyze
dart ..\tool\validate_packages.dart
```

`LocalNotificationClient` is why the suite needs no device: it records the
events that *would* have been shown, so the line's rules are tested as behaviour —
one notification for many sessions, the loudest text plus a count, a repost at
most once per second while the line is up, opening and closing unprompted, a
platform whose service already shows the jobs drawing nothing here, and a released
session unable to resurrect the line. The tests drive a real
`BackgroundLeaseRegistry` rather than a hand-written session list, because a
projection that reads its own copy would only prove it agrees with itself.

## Known limitations

- **Not verified on a device.** No case here proves how a real notification
  head, sounds or groups on a given Android version; the tone mapping is asserted
  as far as the client sees it.
- `ForegroundJobs` shows itself only where the platform has no job service of its
  own. A host that wants a line on Android for work that holds no lease has to take
  the lease; that is the intended direction, not a workaround.
- The timer churn saved by `ForegroundJobs` (one repost per window instead of
  one per report) is observable in tests; the equivalent saving inside
  `FlutterLocalNotificationsClient` is not, because that file is the boundary.
- No notification actions (buttons). A stop button needs a callback path into a
  running isolate, which is a feature of its own.
- Channel *names* are English-with-Chinese strings chosen here; a host that ships
  localized settings text should pass its own `NotifySetup(channels: ...)`.
