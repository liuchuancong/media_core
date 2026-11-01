// What a Windows running line is allowed to do to the user.
//
// A toast has no persistent form on Windows, and the plugin's `show()` is never
// an update: it always calls `ToastNotifier.Show`, which Windows reads as a new
// notification and banners again even though the Action Center entry is replaced
// under the shared tag. A recording's line moves once a second, so drawing it the
// way the other platforms draw it gave the viewer one fresh toast per second of
// one recording. These pin the shape that replaced it — raised once, then re-worded
// in place — through the seam `WindowsLineOps` exists for, since the plugin's own
// Windows half cannot be constructed off a Windows build.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_notify/media_core_notify.dart';

/// The toast mechanism, reduced to the two verbs a line has.
final class _RecordingLineOps implements WindowsLineOps {
  final List<NotifyEvent> raised = <NotifyEvent>[];
  final List<NotifyEvent> reworded = <NotifyEvent>[];

  /// Whether the toast the line was raised under is still on the screen.
  bool updatable = true;

  /// Whether raising is allowed to reach the platform at all.
  bool refuses = false;

  @override
  Future<void> raise(NotifyEvent event) async {
    if (refuses) {
      throw Exception('the toast service refused');
    }

    raised.add(event);
    updatable = true;
  }

  @override
  Future<bool> reword(NotifyEvent event) async {
    reworded.add(event);

    return updatable;
  }
}

NotifyEvent _line({required int id, required String title, String? body}) {
  return NotifyEvent(title: title, body: body, tone: NotifyTone.progress, id: id);
}

/// A platform that is there and does nothing, so the calls the client makes
/// outside the line seam (`cancel`, and the non-Windows `show`) reach an
/// implementation instead of an uninitialised singleton.
final class _NullPlatform extends FlutterLocalNotificationsPlatform {
  final List<int> cancelled = <int>[];
  final List<String?> shown = <String?>[];

  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {
    shown.add(title);
  }

  @override
  Future<void> cancel({required int id}) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingLineOps ops;
  late FlutterLocalNotificationsClient client;
  late _NullPlatform platform;

  setUp(() {
    ops = _RecordingLineOps();
    platform = _NullPlatform();
    FlutterLocalNotificationsPlatform.instance = platform;
    client = FlutterLocalNotificationsClient(plugin: FlutterLocalNotificationsPlugin(), windowsLineOps: ops);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    FlutterLocalNotificationsPlatform.instance = _NullPlatform();
  });

  group('a Windows line is raised once', () {
    test('and every later change re-words it instead of banner-ing again', () async {
      const id = kRecordingLineNotificationId;

      await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_1 · 00:00:01'));
      await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_1 · 00:00:02'));
      await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_1 · 00:00:03'));

      // The regression: three seconds of a recording used to be three banners.
      expect(ops.raised, hasLength(1));
      expect(ops.reworded, hasLength(2));
      expect(ops.reworded.last.body, 'rec_1 · 00:00:03');
    });

    test('each feature owns a line, and each is raised once', () async {
      await client.showRunningLine(_line(id: kRecordingLineNotificationId, title: '录制中'));
      await client.showRunningLine(_line(id: kDownloadLineNotificationId, title: '下载中'));
      await client.showRunningLine(_line(id: kRecordingLineNotificationId, title: '录制中', body: '2 · 30 MB'));

      expect(ops.raised.map((event) => event.id).toList(), <int>[
        kRecordingLineNotificationId,
        kDownloadLineNotificationId,
      ]);
      expect(ops.reworded, hasLength(1));
    });

    test('a re-word that misses is not retried with a new toast', () async {
      const id = kRecordingLineNotificationId;

      await client.showRunningLine(_line(id: id, title: '录制中'));
      // The toast expired into the history: this is the state a long recording
      // spends nearly all of its time in, and the answer is silence, not a banner.
      ops.updatable = false;

      for (var second = 0; second < 30; second++) {
        await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_1 · 00:00:$second'));
      }

      expect(ops.raised, hasLength(1));
    });

    test('the next recording gets a line of its own', () async {
      const id = kRecordingLineNotificationId;

      await client.showRunningLine(_line(id: id, title: '录制中'));
      await client.clearRunningLine(id: id);
      await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_2 · 00:00:01'));

      expect(ops.raised, hasLength(2));
      expect(platform.cancelled, <int>[id]);
    });

    test('a line the host dismissed comes back only with the next feature', () async {
      const id = kRecordingLineNotificationId;

      await client.showRunningLine(_line(id: id, title: '录制中'));
      await client.dismiss(id);
      await client.showRunningLine(_line(id: id, title: '录制中', body: 'rec_1 · 00:00:09'));

      // The swipe said "stop telling me"; the gesture outlives the recording.
      expect(ops.raised, hasLength(1));
      expect(ops.reworded, hasLength(1));
    });

    test('a raise the platform refused leaves no line believed up', () async {
      const id = kRecordingLineNotificationId;

      ops.refuses = true;
      await expectLater(client.showRunningLine(_line(id: id, title: '录制中')), throwsA(anything));
      ops.refuses = false;

      await client.showRunningLine(_line(id: id, title: '录制中'));

      expect(ops.raised, hasLength(1), reason: 'a line never drawn must be drawn next time');
    });
  });

  group('the toast a line is raised with', () {
    test('carries its words as data, not as markup', () {
      const event = NotifyEvent(
        title: '录制中',
        body: 'rec_1 · 00:00:09 · 8.8 MB',
        tone: NotifyTone.progress,
      );

      final details = FlutterLocalNotificationsClient.detailsFor(event, ongoing: true, textAsBindings: true).windows!;

      expect(details.bindings, <String, String>{
        kWindowsLineTitleBinding: '录制中',
        kWindowsLineBodyBinding: 'rec_1 · 00:00:09 · 8.8 MB',
      });
      expect(details.audio, isNotNull, reason: 'a reposted line must never ring');
      expect(details.duration, WindowsNotificationDuration.long);
    });

    test('an absent body binds empty, never the bare token', () {
      // A `{name}` no data answers is rendered literally, which is the one thing a
      // line the user reads must not turn into.
      expect(
        FlutterLocalNotificationsClient.windowsLineBindings(
          const NotifyEvent(title: '录制中', tone: NotifyTone.progress),
        ),
        <String, String>{kWindowsLineTitleBinding: '录制中', kWindowsLineBodyBinding: ''},
      );
    });

    test('only the line binds its text', () {
      const event = NotifyEvent(title: '录制完成', body: 'rec_1', tone: NotifyTone.success);

      expect(FlutterLocalNotificationsClient.detailsFor(event, ongoing: false).windows!.bindings, isEmpty);
      expect(
        FlutterLocalNotificationsClient.detailsFor(event, ongoing: true).windows!.bindings,
        isEmpty,
        reason: 'a job result is a one-shot toast; binding its words buys nothing',
      );
    });
  });

  group('a platform whose notification really is persistent', () {
    test('does not go through the raise-once seam at all', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      // Linux has a `resident` notification, so its line keeps being reposted and
      // the ledger stays empty; the Windows rule must not leak sideways and freeze
      // the one platform that draws the line correctly.
      await client.showRunningLine(_line(id: kRecordingLineNotificationId, title: '录制中'));
      await client.showRunningLine(_line(id: kRecordingLineNotificationId, title: '录制中', body: '00:00:02'));

      expect(ops.raised, isEmpty);
      expect(ops.reworded, isEmpty);
      expect(
        platform.cancelled,
        isEmpty,
        reason: 'nothing here took a line down; the two calls are both reposts',
      );
    });
  });
}
