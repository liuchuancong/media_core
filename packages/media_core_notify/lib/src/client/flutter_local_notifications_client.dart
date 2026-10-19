/// The `flutter_local_notifications` implementation of [LocalNotificationClient].
///
/// All of the plugin's surface that this package needs lives here, so the tone
/// mapping (what an event is allowed to do to the user) is one table rather than
/// scattered decisions, and so a host can replace the whole mechanism by passing
/// a different client.
library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;

import 'package:media_core_notify/src/client/notification_client.dart';
import 'package:media_core_notify/src/client/notify_event.dart';
import 'package:media_core_notify/src/jobs/foreground_jobs.dart';

/// The client backed by `flutter_local_notifications`.
final class FlutterLocalNotificationsClient implements LocalNotificationClient {
  /// Creates a client. A second instance is harmless: the plugin it wraps is a
  /// singleton, so both talk to the same pipeline.
  FlutterLocalNotificationsClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  int _nextId = kFirstPostedNotificationId;

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

    await _plugin.show(
      id: id,
      title: event.title,
      body: event.body,
      payload: event.payload,
      notificationDetails: detailsFor(event.copyWith(id: id), ongoing: false),
    );
  }

  @override
  Future<void> dismiss(int id) => _plugin.cancel(id: id);

  @override
  Future<void> showRunningLine(NotifyEvent event) async {
    // One id per feature, replaced in place: a line is one notification about
    // several jobs of that feature, and a second show() must not stack a second one
    // under it.
    final ongoing = event.copyWith(id: event.id ?? kRunningLineNotificationId, tone: NotifyTone.progress);

    await _plugin.show(
      id: ongoing.id!,
      title: ongoing.title,
      body: ongoing.body,
      payload: ongoing.payload,
      notificationDetails: detailsFor(ongoing, ongoing: true),
    );
  }

  @override
  Future<void> clearRunningLine({required int id}) => _plugin.cancel(id: id);

  // ---------------------------------------------------------------------------
  // Tone mapping
  // ---------------------------------------------------------------------------

  /// The plugin's own description of [event] on every platform.
  ///
  /// The tone table is this package's whole rule about how insistent an event may
  /// be, so it is checked without a notification server, an Android or a toast API:
  /// the platform-specific details classes cannot be round-tripped off-platform any
  /// other way (see [initializationFor] for the same reason).
  @visibleForTesting
  static NotificationDetails detailsFor(NotifyEvent event, {required bool ongoing}) {
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
      ),
    );
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
