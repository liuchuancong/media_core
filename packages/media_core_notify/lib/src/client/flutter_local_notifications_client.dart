/// The `flutter_local_notifications` implementation of [LocalNotificationClient].
///
/// All of the plugin's surface that this package needs lives here, so the tone
/// mapping (what an event is allowed to do to the user) is one table rather than
/// scattered decisions, and so a host can replace the whole mechanism by passing
/// a different client.
library;

import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_core/media_core.dart' show LogCategory, LogModule, MediaCoreLog;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;

import 'package:media_core_notify/src/client/notification_client.dart';
import 'package:media_core_notify/src/client/notify_event.dart';
import 'package:media_core_notify/src/jobs/foreground_jobs.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.general);

/// Arms a COM apartment on the calling thread before the plugin's Windows
/// FFI surface is touched.
///
/// The plugin's Windows implementation is plain FFI, so every call — the DLL
/// load, `CoRegisterClassObject` of the toast activation callback and the
/// `ToastNotificationManager` activation — runs on whatever thread the caller
/// used. From a Flutter root isolate that is the isolate thread, and the
/// engine only ever gives *its* platform thread an apartment. Combase on
/// current Windows fail-fasts outright on the apartment-less registration
/// (the process dies with abort() during boot), and older hosts die through
/// `winrt::check_hresult` throwing a C++ exception across the FFI boundary.
/// `COINIT_MULTITHREADED` needs no message pump, S_FALSE and
/// RPC_E_CHANGED_MODE both mean an apartment already exists, and the init is
/// deliberately never balanced by `CoUninitialize`: the apartment lives for
/// the process, like the engine's own.
void _ensureWindowsComApartment() {
  try {
    final ole32 = ffi.DynamicLibrary.open('ole32.dll');
    final coInitializeEx = ole32.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Uint32),
      int Function(ffi.Pointer<ffi.Void>, int)
    >('CoInitializeEx');
    coInitializeEx(ffi.Pointer.fromAddress(0), 0x0);
  } on Object catch (error) {
    // Only reachable off-Windows or in a sandbox without ole32; configure()
    // reports the platform's refusal downstream either way.
    _log.warning('windows COM apartment pre-init failed', error: error);
  }
}

/// The data-binding name a Windows running line carries its title in.
///
/// The line's text is written as `{name}` in the toast XML and supplied as data,
/// rather than baked into the markup, because that is the only way a toast can be
/// told again with new words: see [FlutterLocalNotificationsClient.showRunningLine].
@visibleForTesting
const String kWindowsLineTitleBinding = 'mc_line_title';

/// The data-binding name a Windows running line carries its body in.
@visibleForTesting
const String kWindowsLineBodyBinding = 'mc_line_body';

/// The two things a Windows running line needs from the toast mechanism.
///
/// Split out because the plugin's Windows half cannot be constructed off a
/// Windows build — its field initialiser opens the native library — and "raise
/// once, then re-word" is exactly the rule that must not regress back into a
/// banner per second without anyone noticing. The default implementation is
/// [_PluginWindowsLineOps]; a test passes its own.
@visibleForTesting
abstract interface class WindowsLineOps {
  /// Raises the toast for [event]'s line, with its words supplied as data.
  Future<void> raise(NotifyEvent event);

  /// Re-words the toast already up under [event]'s id, and says whether it was
  /// there. Never throws: a line that could not be re-worded is still the line
  /// the user was told about, only a moment behind.
  Future<bool> reword(NotifyEvent event);
}

/// The client backed by `flutter_local_notifications`.
final class FlutterLocalNotificationsClient implements LocalNotificationClient {
  /// Creates a client. A second instance is harmless: the plugin it wraps is a
  /// singleton, so both talk to the same pipeline.
  ///
  /// [windowsLineOps] is the seam [WindowsLineOps] documents; nothing else about
  /// a client is configurable behind a host's back.
  FlutterLocalNotificationsClient({FlutterLocalNotificationsPlugin? plugin, WindowsLineOps? windowsLineOps})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin() {
    _windowsLineOps = windowsLineOps ?? _PluginWindowsLineOps(_plugin);
  }

  final FlutterLocalNotificationsPlugin _plugin;

  late final WindowsLineOps _windowsLineOps;

  int _nextId = kFirstPostedNotificationId;

  /// The Windows line ids this client has already raised a toast for.
  ///
  /// One per feature, emptied when the feature's line is taken down. Its whole
  /// job is to make the second repost of a line a silent content update rather
  /// than a second banner; see [showRunningLine].
  final Set<int> _windowsLines = <int>{};

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> configure(NotifySetup setup) async {
    final platform = defaultTargetPlatform;

    if (kIsWeb || !kNotifyCapablePlatforms.contains(platform)) {
      // Asked and answered here, because the plugin answers a platform it was given
      // no settings for by throwing `ArgumentError` — and `MediaCoreNotify.enable`
      // only swallows exceptions, so on Fuchsia or a Fuchsia-shaped test platform a
      // host that turned notifications on got a crash out of a library that promises
      // a notification can never break the job it reports for.
      return false;
    }

    final initialization = initializationFor(setup);

    if (platform == TargetPlatform.windows && initialization.windows == null) {
      // No identity named, so nothing to initialise with. Said as a false rather
      // than as an exception: the job runs either way, it just has no toast to show.
      return false;
    }

    if (platform == TargetPlatform.windows) {
      _ensureWindowsComApartment();
    }

    final started = await _plugin.initialize(
      settings: initialization,
      onDidReceiveNotificationResponse: (response) {
        if (response.notificationResponseType == NotificationResponseType.notificationDismissed) {
          // A swipe is not an opening, so it must not reach the host's tap callback.
          // What it does mean to us is that the line is no longer on the shade.
          ForegroundJobs.lineWasRemoved(response.id ?? 0);

          return;
        }

        setup.onTap?.call(NotifyTap(id: response.id ?? 0, payload: response.payload, actionId: response.actionId));
      },
    );

    final android = _android;

    if (android != null) {
      for (final channel in setup.channels) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            importance: _importanceOf(channel.tone),
            // The running-jobs line is a status, not an interruption: it must
            // never ring, whatever the tone of the moment it was created with.
            playSound: channel.tone != NotifyTone.progress,
          ),
        );
      }
    }

    return started ?? true;
  }

  /// What [setup] means to the plugin on the current platform.
  ///
  /// Extracted because the Linux and Windows implementations load native libraries
  /// in their constructors, so they cannot be instantiated off-platform: which
  /// platform is asked at all — and with what identity — is the half of `configure`
  /// that decides whether a desktop gets its lines, and it is checkable without one.
  @visibleForTesting
  static InitializationSettings initializationFor(NotifySetup setup) {
    return InitializationSettings(
      android: AndroidInitializationSettings(setup.androidSmallIcon),
      // Permission questions are asked explicitly through [requestPermission];
      // initialising must not raise one on first launch.
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: _linuxSettingsOf(setup.desktop),
      windows: _windowsSettingsOf(setup.desktop),
    );
  }

  /// Linux needs nothing a host has to supply: the click action's label is the
  /// only required field, and a generic one is honest.
  static LinuxInitializationSettings _linuxSettingsOf(DesktopNotifySettings? desktop) {
    return LinuxInitializationSettings(defaultActionName: desktop?.linuxActionName ?? desktop?.appName ?? '打开 / Open');
  }

  /// The Windows initialisation the setup describes, or null when the host named no
  /// identity. A toast posted under an invented user-model id is attributed to
  /// whichever app guessed the same words first, so this stays the host's to say.
  static WindowsInitializationSettings? _windowsSettingsOf(DesktopNotifySettings? desktop) {
    final modelId = desktop?.windowsAppUserModelId;
    final guid = desktop?.windowsGuid;

    if (desktop == null || modelId == null || guid == null) {
      return null;
    }

    return WindowsInitializationSettings(appName: desktop.appName, appUserModelId: modelId, guid: guid);
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => await _android?.requestNotificationsPermission() ?? false,
      TargetPlatform.iOS =>
        await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false,
      TargetPlatform.macOS =>
        await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false,
      // No question to ask: Linux and Windows report what they already allow.
      _ => await notificationsEnabled(),
    };
  }

  @override
  Future<bool> notificationsEnabled() async {
    if (kIsWeb) {
      return false;
    }

    final android = _android;

    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    // Where the plugin cannot answer, assume yes: a Linux desktop with no
    // notification server fails at post time, and that is reported there.
    return true;
  }

  @override
  Future<void> post(NotifyEvent event) async {
    final id = event.id ?? _nextId++;

    try {
      await _plugin.show(
        id: id,
        title: event.title,
        body: event.body,
        payload: event.payload,
        notificationDetails: detailsFor(event.copyWith(id: id), ongoing: false),
      );
    } on Object catch (error) {
      _log.warning('notification show failed', error: error);
      rethrow;
    }
  }

  @override
  Future<void> dismiss(int id) async {
    // Deliberately not `_windowsLines.remove(id)`: a line the host took down was
    // still raised once, and a recording that carries on re-wording it must not
    // answer the viewer's swipe with a fresh banner a second later. The ledger is
    // emptied by [clearRunningLine], which is what a feature actually ending is.
    try {
      await _plugin.cancel(id: id);
    } on Object catch (error) {
      _log.warning('notification dismiss failed', error: error);
      rethrow;
    }
  }

  @override
  Future<void> showRunningLine(NotifyEvent event) async {
    // One id per feature, replaced in place: a line is one notification about
    // several jobs of that feature, and a second show() must not stack a second one
    // under it.
    final id = event.id ?? kRunningLineNotificationId;
    final ongoing = event.copyWith(id: id, tone: NotifyTone.progress);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _showWindowsLine(ongoing);

      return;
    }

    try {
      await _plugin.show(
        id: ongoing.id!,
        title: ongoing.title,
        body: ongoing.body,
        payload: ongoing.payload,
        notificationDetails: detailsFor(ongoing, ongoing: true),
      );
    } on Object catch (error) {
      _log.warning('notification show failed', error: error);
      rethrow;
    }
  }

  /// Draws — or, from the second call on, quietly re-words — one Windows line.
  ///
  /// A toast has no persistent form. `show()` always goes through
  /// `ToastNotifier.Show`, and Windows reads that as *a new notification*: the
  /// Action Center entry is replaced under the shared tag, but the banner drops
  /// again every time. A recording's line moves once a second, so drawing it the
  /// way the other platforms do gave the viewer a fresh toast every second of
  /// every recording — the noise this package's repost window exists to keep
  /// down, arriving through the one door that window cannot reach.
  ///
  /// So the line is raised once, and every later change re-words the toast that
  /// is already up and raises nothing. Once the toast has expired into the
  /// history the re-word simply misses, and it is allowed to miss: the honest
  /// desktop shape of a running line is one announcement when the work starts,
  /// not a metronome, and re-raising to keep the text current is the bug again.
  /// The line comes back with the next feature that starts, because
  /// [clearRunningLine] forgets it.
  Future<void> _showWindowsLine(NotifyEvent event) async {
    final id = event.id!;

    if (_windowsLines.contains(id)) {
      await _windowsLineOps.reword(event);

      return;
    }

    _windowsLines.add(id);

    try {
      await _windowsLineOps.raise(event);
    } on Object {
      _windowsLines.remove(id);

      rethrow;
    }
  }

  @override
  Future<void> clearRunningLine({required int id}) async {
    _windowsLines.remove(id);

    try {
      await _plugin.cancel(id: id);
    } on Object catch (error) {
      _log.warning('notification dismiss failed', error: error);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Tone mapping
  // ---------------------------------------------------------------------------

  /// The plugin's own description of [event] on every platform.
  ///
  /// [textAsBindings] is Windows' running line only: it puts the title and body in
  /// the toast's data rather than in its markup, so a later `updateBindings` can
  /// move the words without raising the toast again — and the caller then shows
  /// the `{name}` tokens in place of the text.
  ///
  /// The tone table is this package's whole rule about how insistent an event may
  /// be, so it is checked without a notification server, an Android or a toast API:
  /// the platform-specific details classes cannot be round-tripped off-platform any
  /// other way (see [initializationFor] for the same reason).
  @visibleForTesting
  static NotificationDetails detailsFor(
    NotifyEvent event, {
    required bool ongoing,
    bool textAsBindings = false,
  }) {
    return NotificationDetails(
      android: _androidDetails(event, ongoing: ongoing),
      iOS: _darwinDetails(event.tone),
      macOS: _darwinDetails(event.tone),
      linux: LinuxNotificationDetails(
        urgency: _linuxUrgencyOf(event.tone),
        // A progress line is reposted as the numbers move; on a notification server
        // that rings per message that is the shelf noise the throttle exists for.
        suppressSound: event.tone == NotifyTone.progress,
        resident: ongoing,
        transient: !ongoing && event.tone == NotifyTone.progress,
      ),
      windows: WindowsNotificationDetails(
        audio: event.tone == NotifyTone.progress ? WindowsNotificationAudio.silent() : null,
        duration: ongoing ? WindowsNotificationDuration.long : null,
        bindings: textAsBindings ? windowsLineBindings(event) : const <String, String>{},
      ),
    );
  }

  /// The words [event] carries, in the data-binding form a Windows line needs.
  ///
  /// A missing body is an empty string rather than an absent binding: a `{name}`
  /// in the markup that no data answers is rendered as the literal token, and a
  /// line the user reads must never turn into that.
  @visibleForTesting
  static Map<String, String> windowsLineBindings(NotifyEvent event) {
    return <String, String>{
      kWindowsLineTitleBinding: event.title,
      kWindowsLineBodyBinding: event.body ?? '',
    };
  }

  static LinuxNotificationUrgency _linuxUrgencyOf(NotifyTone tone) => switch (tone) {
    NotifyTone.progress => LinuxNotificationUrgency.low,
    NotifyTone.info => LinuxNotificationUrgency.normal,
    NotifyTone.success => LinuxNotificationUrgency.normal,
    NotifyTone.warning => LinuxNotificationUrgency.normal,
    NotifyTone.failure => LinuxNotificationUrgency.critical,
  };

  static AndroidNotificationDetails _androidDetails(NotifyEvent event, {required bool ongoing}) {
    final progress = event.tone == NotifyTone.progress;
    final fraction = event.progress;

    return AndroidNotificationDetails(
      event.channel.id,
      event.channel.name,
      channelDescription: event.channel.description,
      importance: _importanceOf(event.tone),
      priority: _priorityOf(event.tone),
      // The bar only exists on this platform; the others read the percentage
      // the running line's body already carries.
      showProgress: progress && (fraction != null || event.indeterminate),
      maxProgress: 100,
      progress: fraction == null ? 0 : (fraction.clamp(0.0, 1.0) * 100).round(),
      indeterminate: progress && fraction == null && event.indeterminate,
      playSound: !progress,
      silent: progress,
      // The line is the one thing here worth knowing when it goes away on its own,
      // and Android only reports a swipe back through the response callback when
      // asked to. Darwin needs the notification's category to carry
      // `customDismissAction`, which this package does not register, so a line
      // swiped on iOS or macOS stays away until the feature's own text moves —
      // which is what its contract already says.
      dismissIsolate: ongoing ? NotificationDismissedIsolate.main : null,
      // A progress line is reposted several times a second; without this the
      // shelf re-animates on every one of them.
      onlyAlertOnce: progress,
      ongoing: ongoing,
      autoCancel: !ongoing,
      visibility: progress ? NotificationVisibility.public : NotificationVisibility.private,
      icon: _iconFor(event.kind),
      groupKey: 'media_core.jobs',
    );
  }

  static DarwinNotificationDetails _darwinDetails(NotifyTone tone) {
    final progress = tone == NotifyTone.progress;

    return DarwinNotificationDetails(
      // iOS and macOS banner a notification every time it is posted, so a
      // progress line would fire a banner per update. It stays in the centre
      // without interrupting.
      presentAlert: !progress,
      presentSound: tone != NotifyTone.info && !progress,
      presentBadge: !progress,
      presentBanner: !progress,
      presentList: true,
      interruptionLevel: progress ? InterruptionLevel.passive : InterruptionLevel.timeSensitive,
    );
  }

  static Importance _importanceOf(NotifyTone tone) => switch (tone) {
    NotifyTone.progress => Importance.low,
    NotifyTone.info => Importance.defaultImportance,
    NotifyTone.success => Importance.high,
    NotifyTone.warning => Importance.high,
    NotifyTone.failure => Importance.max,
  };

  static Priority _priorityOf(NotifyTone tone) => switch (tone) {
    NotifyTone.progress => Priority.min,
    NotifyTone.info => Priority.defaultPriority,
    NotifyTone.success => Priority.high,
    NotifyTone.warning => Priority.high,
    NotifyTone.failure => Priority.max,
  };

  /// The small icon for a job kind, using the glyphs `media_core_native`
  /// already ships in its Android resources.
  static String? _iconFor(BackgroundJobKind? kind) => switch (kind) {
    BackgroundJobKind.record => '@drawable/ic_stat_media_core_record',
    BackgroundJobKind.download => '@drawable/ic_stat_media_core_download',
    BackgroundJobKind.task => '@drawable/ic_stat_media_core_task',
    null => null,
  };
}

/// [WindowsLineOps] on the real toast mechanism.
final class _PluginWindowsLineOps implements WindowsLineOps {
  /// Wraps the plugin a client is already talking to.
  const _PluginWindowsLineOps(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> raise(NotifyEvent event) async {
    // The tokens, not the text: the words arrive as data so `reword` can move
    // them later without a new toast. A body the event does not carry binds to
    // empty rather than staying a bare `{name}` in the user's face.
    try {
      await _plugin.show(
        id: event.id!,
        title: '{$kWindowsLineTitleBinding}',
        body: '{$kWindowsLineBodyBinding}',
        payload: event.payload,
        notificationDetails: FlutterLocalNotificationsClient.detailsFor(
          event,
          ongoing: true,
          textAsBindings: true,
        ),
      );
    } on Object catch (error) {
      _log.warning('notification show failed', error: error);

      rethrow;
    }
  }

  @override
  Future<bool> reword(NotifyEvent event) async {
    final windows = _plugin.resolvePlatformSpecificImplementation<FlutterLocalNotificationsWindows>();

    if (windows == null) {
      return false;
    }

    try {
      return await windows.updateBindings(
        id: event.id!,
        bindings: FlutterLocalNotificationsClient.windowsLineBindings(event),
      ).then((result) => result == NotificationUpdateResult.success);
    } on Object catch (error) {
      // A line that could not be re-worded is still the line the user was told
      // about; only the words are a moment behind.
      _log.debug('windows running line reword failed', fields: <String, Object?>{'error': error});

      return false;
    }
  }
}
