# Permissions and platform setup

What the music module needs from the host, per platform, and why. The Dart
side asks through `AudioPermissionService`; everything else is a manifest
entry only the app can make.

## Runtime permissions (`AudioPermissionService`)

```dart
final permissions = AudioPermissionService();

// Media notification. Without it the notification silently never appears on
// Android 13+; playback itself is unaffected.
await permissions.request(AudioPermission.notifications);

// Local music. Only needed when the app scans the device (LocalMusicSource,
// a library screen); streamed playback does not need it.
await permissions.request(AudioPermission.mediaLibrary);

// Desktop lyrics. show() already does this, but an app that wants to ask
// before the user taps "desktop lyrics" can do it up front.
await permissions.request(AudioPermission.desktopLyricOverlay);
```

| permission | Android | elsewhere |
| --- | --- | --- |
| `notifications` | `POST_NOTIFICATIONS` (API 33+); a no-op below that | granted (`true`) |
| `mediaLibrary` | `READ_MEDIA_AUDIO` (33+) / `READ_EXTERNAL_STORAGE` (≤32, runtime) | granted |
| `desktopLyricOverlay` | `SYSTEM_ALERT_WINDOW` — **no dialog exists**: the request opens the system settings screen and answers once the switch is on (or after a 60s wait) | granted |

A permission a platform does not have answers `true`: the caller asked "may
I?", and on a platform that never asks, the answer is yes.

## What the app must declare itself

### Android

The plugin's own manifest already declares, and merges into the app:

- `SYSTEM_ALERT_WINDOW` (overlay), `POST_NOTIFICATIONS` (notification),
  `READ_MEDIA_AUDIO` + `READ_EXTERNAL_STORAGE` (local music),
- `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
  (background playback).

`audio_service` requires three more entries that a library cannot add for the
app, because the app's own activity is replaced:

```xml
<application ...>
  <activity android:name="com.ryanheise.audioservice.AudioServiceActivity" ... />

  <service android:name="com.ryanheise.audioservice.AudioService"
      android:foregroundServiceType="mediaPlayback"
      android:exported="true" tools:ignore="Instantiatable">
    <intent-filter>
      <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
  </service>

  <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
      android:exported="true" tools:ignore="Instantiatable">
    <intent-filter>
      <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
  </receiver>
</application>
```

Without the service/receiver the media notification, the lock-screen controls
and headset buttons stay dead even though playback works.

### iOS

Not supported by this module's overlay (no cross-application window exists).
Background **audio** does work, and needs an app-side key:

```xml
<key>UIBackgroundModes</key>
<array><string>audio</string></array>
```

### Windows / macOS / Linux

No runtime permissions. macOS needs nothing for a floating window; Linux needs
nothing for the overlay (see the note about Wayland and click-through in
`DesktopLyricTransport`'s documentation).
