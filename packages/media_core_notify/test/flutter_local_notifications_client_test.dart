// The adapter's own tests. Everything else in the package is asserted against a
// hand-written fake client, which says what *this package* asks for; nothing said
// what `flutter_local_notifications` 22.x is then told. Those shapes — the id a line
// is posted under, the tone table, the per-feature channel registration, the
// permission question each platform has — are only visible on a device unless they
// are pinned here, and the platform seam is fakeable without one.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' show BackgroundServiceOwner;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;
import 'package:media_core_notify/media_core_notify.dart';

/// The Android implementation, recording what the client asked it to do.
///
/// Extends the real class rather than the platform interface because
/// `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()`
/// — how the client reaches every Android-only method — only answers when the
/// registered instance really is one.
final class _FakeAndroid extends AndroidFlutterLocalNotificationsPlugin {
  bool? initializeResult;
  bool? enabledResult;
  bool? permissionResult;

  AndroidInitializationSettings? initializedWith;
  DidReceiveNotificationResponseCallback? responseHandler;
  final List<AndroidNotificationChannel> channels = <AndroidNotificationChannel>[];
  final List<_Shown> shown = <_Shown>[];
  final List<int> cancelled = <int>[];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializedWith = settings;
    responseHandler = onDidReceiveNotificationResponse;

    return initializeResult ?? true;
  }

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel notificationChannel) async {
    channels.add(notificationChannel);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown.add(_Shown(id: id, title: title, body: body, payload: payload, details: notificationDetails));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add(id);
  }

  @override
  Future<bool?> areNotificationsEnabled() async => enabledResult;

  @override
  Future<bool?> requestNotificationsPermission() async => permissionResult;
}

final class _Shown {
  _Shown({required this.id, this.title, this.body, this.payload, this.details});

  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final AndroidNotificationDetails? details;
}

final class _FakeIOS extends IOSFlutterLocalNotificationsPlugin {
  bool? permissionResult;
  String? requestedFor;

  @override
  Future<bool?> initialize({
    required DarwinInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requestedFor = 'alert:$alert badge:$badge sound:$sound';

    return permissionResult;
  }
}

final class _FakeMacOS extends MacOSFlutterLocalNotificationsPlugin {
  bool? permissionResult;

  @override
  Future<bool?> initialize({
    required DarwinInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async => true;

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) async => permissionResult;
}

/// A base-interface implementation: what a platform with no plugin of its own
/// registers as.
final class _FakeBase extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAndroid android;
  late FlutterLocalNotificationsClient client;

  setUp(() {
    android = _FakeAndroid();
    FlutterLocalNotificationsPlatform.instance = android;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    client = FlutterLocalNotificationsClient();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    FlutterLocalNotificationsPlatform.instance = _FakeBase();
  });

  AndroidNotificationDetails onlyDetails(_FakeAndroid fake) => fake.shown.single.details!;

  group('configure', () {
    test('initialises with the setup icon', () async {
      await client.configure(const NotifySetup());

      expect(android.initializedWith?.defaultIcon, '@mipmap/ic_launcher');
    });

    test('registers every channel with the importance of its own tone, and keeps the job lines silent', () async {
      await client.configure(const NotifySetup());

      expect(android.channels.map((channel) => channel.id), <String>[
        'media_core_recording',
        'media_core_download',
        'media_core_jobs',
        'media_core_results',
      ]);

      final byId = {for (final channel in android.channels) channel.id: channel};
      expect(byId['media_core_results']?.importance, Importance.high);
      // The running line is a status, not an interruption: it must never ring,
      // whatever else lands on the same channel.
      expect(byId['media_core_jobs']?.playSound, isFalse);
      expect(byId['media_core_results']?.playSound, isTrue);
    });

    test('a platform with no mechanism answers false instead of throwing', () async {
      // The plugin answers a platform it has no settings for with an ArgumentError,
      // and `MediaCoreNotify.enable` only swallows exceptions — so an unsupported
      // platform was a crash out of a library whose promise is that a notification
      // can never break the job it reports for.
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      expect(await client.configure(const NotifySetup()), isFalse);
      expect(android.initializedWith, isNull);
      expect(android.channels, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await client.configure(const NotifySetup()), isTrue, reason: 'iOS has a mechanism to ask');
    });

    test('the tap reaches the host with the id, payload and action the platform gave', () async {
      final taps = <NotifyTap>[];

      await client.configure(NotifySetup(onTap: taps.add));
      android.responseHandler?.call(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          id: 7,
          payload: 'file://vlog.ts',
          actionId: 'open',
        ),
      );
      // A response that carries no id still reaches the host, as id 0.
      android.responseHandler?.call(
        const NotificationResponse(notificationResponseType: NotificationResponseType.selectedNotification),
      );

      android.responseHandler?.call(
        const NotificationResponse(notificationResponseType: NotificationResponseType.notificationDismissed, id: 7),
      );

      expect(taps.map((tap) => tap.id), <int>[7, 0]);
      expect(taps.first.payload, 'file://vlog.ts');
      expect(taps.first.actionId, 'open');
      expect(
        taps,
        hasLength(2),
        reason: 'a swipe is not an opening; forwarding it as one would send the host to the file it just dismissed',
      );
    });
  });

  group('what the plugin is told', () {
    test('a posted event gets its own id, counting up from the first free one', () async {
      await client.post(const NotifyEvent(title: 'a'));
      await client.post(const NotifyEvent(title: 'b'));

      expect(android.shown.map((event) => event.id), <int>[kFirstPostedNotificationId, kFirstPostedNotificationId + 1]);
    });

    test('an event that names its id is posted under that id', () async {
      await client.post(const NotifyEvent(title: 'a', id: kRecordingLineNotificationId));

      expect(android.shown.single.id, kRecordingLineNotificationId);
    });

    test('the tone table is what decides how insistent the platform may be', () async {
      final details = <NotifyTone, AndroidNotificationDetails>{
        for (final tone in NotifyTone.values)
          tone: FlutterLocalNotificationsClient.detailsFor(
            NotifyEvent(title: 't', tone: tone),
            ongoing: false,
          ).android!,
      };

      expect(details[NotifyTone.success]!.importance, Importance.high);
      expect(details[NotifyTone.success]!.playSound, isTrue);
      expect(details[NotifyTone.success]!.autoCancel, isTrue, reason: 'a result is gone once it is opened');
      expect(details[NotifyTone.failure]!.importance, Importance.max);
      expect(details[NotifyTone.failure]!.priority, Priority.max);
      expect(details[NotifyTone.progress]!.silent, isTrue);
      expect(details[NotifyTone.progress]!.onlyAlertOnce, isTrue, reason: 'a repost must not re-animate the shelf');
      expect(details[NotifyTone.info]!.playSound, isTrue);
    });

    test('only a line asks Android to report a swipe back', () async {
      expect(
        FlutterLocalNotificationsClient.detailsFor(
          const NotifyEvent(title: 'x'),
          ongoing: true,
        ).android!.dismissIsolate,
        NotificationDismissedIsolate.main,
      );
      expect(
        FlutterLocalNotificationsClient.detailsFor(
          const NotifyEvent(title: 'y'),
          ongoing: false,
        ).android!.dismissIsolate,
        isNull,
        reason: 'a posted result the user swiped away is not state anyone is tracking',
      );
    });

    test('the same tone table reaches the desktops, where this package draws the line', () async {
      // A line reaches the platform details as a progress event: that is what
      // `showRunningLine` makes of whatever it was handed, so this asks the question
      // the plugin is really asked.
      final line = FlutterLocalNotificationsClient.detailsFor(
        const NotifyEvent(title: 'x', tone: NotifyTone.progress),
        ongoing: true,
      );

      expect(line.linux!.urgency, LinuxNotificationUrgency.low);
      expect(line.linux!.resident, isTrue, reason: 'the line stays while the job runs');
      expect(
        line.linux!.suppressSound,
        isTrue,
        reason: 'a line reposted as the numbers moves must not chirp on a notification server either',
      );
      expect(line.windows!.duration, WindowsNotificationDuration.long);
      expect(line.windows!.audio!.isSilent, isTrue);

      final failure = FlutterLocalNotificationsClient.detailsFor(
        const NotifyEvent(title: 'x', tone: NotifyTone.failure),
        ongoing: false,
      );
      expect(failure.linux!.urgency, LinuxNotificationUrgency.critical);
      expect(failure.linux!.suppressSound, isFalse);
      expect(failure.windows!.audio, isNull, reason: 'a result is allowed to make its noise');
    });

    test('the icon comes from the job kind, and an unnamed kind asks for none', () async {
      await client.post(const NotifyEvent(title: 'a', kind: BackgroundJobKind.record));
      expect(onlyDetails(android).icon, '@drawable/ic_stat_media_core_record');

      await client.post(const NotifyEvent(title: 'b', kind: BackgroundJobKind.download));
      expect(android.shown.last.details!.icon, '@drawable/ic_stat_media_core_download');

      await client.post(const NotifyEvent(title: 'c'));
      expect(android.shown.last.details!.icon, isNull);
    });

    test('every line and event is grouped, so a shelf can collapse them as one app', () async {
      await client.post(const NotifyEvent(title: 'a'));

      expect(onlyDetails(android).groupKey, 'media_core.jobs');
    });
  });

  group('the running line', () {
    test('is forced silent and ongoing however the event was described', () async {
      await client.showRunningLine(const NotifyEvent(title: '正在录制', tone: NotifyTone.success));

      final details = onlyDetails(android);
      expect(details.silent, isTrue);
      expect(details.ongoing, isTrue);
      expect(details.autoCancel, isFalse, reason: 'a status stays until the job ends, not until it is opened');
      expect(details.visibility, NotificationVisibility.public);
    });

    test('is one notification per feature, addressed by that feature id', () async {
      for (final owner in BackgroundServiceOwner.jobOwners) {
        await client.showRunningLine(NotifyEvent(title: 'x', id: runningLineIdFor(owner)));
      }

      expect(android.shown.map((event) => event.id), <int>[
        kRecordingLineNotificationId,
        kDownloadLineNotificationId,
        kRunningLineNotificationId,
      ]);

      await client.clearRunningLine(id: kDownloadLineNotificationId);

      expect(android.cancelled, <int>[kDownloadLineNotificationId]);
    });

    test('falls back to the generic id when the caller named none', () async {
      await client.showRunningLine(const NotifyEvent(title: 'x'));

      expect(android.shown.single.id, kRunningLineNotificationId);
    });

    test('a dismissed id is cancelled under that id', () async {
      await client.dismiss(kFirstPostedNotificationId + 4);

      expect(android.cancelled, <int>[kFirstPostedNotificationId + 4]);
    });
  });

  group('the permission question each platform has', () {
    test('Android is asked, and its answer is the answer', () async {
      android.permissionResult = true;
      expect(await client.requestPermission(), isTrue);

      android.permissionResult = false;
      expect(await client.requestPermission(), isFalse, reason: 'a declined ask is not a thrown error');

      android.enabledResult = true;
      expect(await client.notificationsEnabled(), isTrue);

      android.enabledResult = null;
      expect(
        await client.notificationsEnabled(),
        isFalse,
        reason: 'an Android that cannot say is treated as one that says no',
      );
    });

    test('iOS and macOS are asked for the alert/badge/sound triple, not just alerts', () async {
      final ios = _FakeIOS()..permissionResult = true;
      FlutterLocalNotificationsPlatform.instance = ios;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(await client.requestPermission(), isTrue);
      expect(ios.requestedFor, 'alert:true badge:true sound:true');

      final macos = _FakeMacOS()..permissionResult = false;
      FlutterLocalNotificationsPlatform.instance = macos;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(await client.requestPermission(), isFalse);
    });

    test('a desktop with no question to ask reports what it already allows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      // Nothing Android-shaped resolves on a desktop, and the rule there is that an
      // unanswerable question is answered yes: a Linux with no notification server
      // fails at post time, which is the place that can still say so.
      expect(await client.requestPermission(), isTrue);
      expect(await client.notificationsEnabled(), isTrue);
    });
  });

  group('the desktops this package draws lines for', () {
    test('Linux is asked to initialise, with a click label the host can override', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      expect(
        FlutterLocalNotificationsClient.initializationFor(const NotifySetup()).linux!.defaultActionName,
        '打开 / Open',
      );
      expect(
        FlutterLocalNotificationsClient.initializationFor(
          const NotifySetup(
            desktop: DesktopNotifySettings(appName: '示例', linuxActionName: '去看看'),
          ),
        ).linux!.defaultActionName,
        '去看看',
      );

      // The desktop plugin cannot be constructed off-platform (its constructor loads
      // native code), so what is checkable here is that Linux is asked at all rather
      // than refused — which is the half that used to throw.
      expect(await client.configure(const NotifySetup()), isTrue);
    });

    test('Windows is configured only when the host names its identity', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      const named = NotifySetup(
        desktop: DesktopNotifySettings(
          appName: '媒体核心示例',
          windowsAppUserModelId: 'com.example.media_core.dev',
          windowsGuid: '8a1b0d5c-0000-4000-8000-000000000001',
        ),
      );

      expect(
        FlutterLocalNotificationsClient.initializationFor(const NotifySetup()).windows,
        isNull,
        reason: 'a toast posted under an invented user-model id is attributed to the wrong app',
      );
      expect(await client.configure(const NotifySetup()), isFalse);
      expect(android.initializedWith, isNull, reason: 'a refused configure must not have asked either');

      expect(await client.configure(named), isTrue);

      final settings = FlutterLocalNotificationsClient.initializationFor(named).windows!;
      expect(settings.appUserModelId, 'com.example.media_core.dev');
      expect(settings.appName, '媒体核心示例');
      expect(settings.guid, '8a1b0d5c-0000-4000-8000-000000000001');
    });
  });
}
