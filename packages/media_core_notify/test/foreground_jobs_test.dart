import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart'
    show
        BackgroundAcquireSuccess,
        BackgroundBackendGranted,
        BackgroundBackendLease,
        BackgroundBackendOutcome,
        BackgroundCapability,
        BackgroundExecutionBackend,
        BackgroundExecutionKind,
        BackgroundJobProgress,
        BackgroundLease,
        BackgroundLeaseRegistry,
        BackgroundRequest,
        BackgroundRuntimes,
        BackgroundServiceOwner,
        BackgroundSessionStatus;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;
import 'package:media_core_notify/media_core_notify.dart';

/// The platform underneath the registry: it grants what the test tells it to and
/// remembers the session it started.
///
/// A projection over a hand-written session list would prove the projection
/// agrees with itself. Drawing from the real registry is the only way to show it
/// agrees with the thing the jobs actually hold.
final class _PlatformBackend implements BackgroundExecutionBackend {
  /// Whether this platform's job service draws its own notification — Android —
  /// or whether the Dart line is the only one the user would ever see.
  bool persistent = false;

  final List<BackgroundRequest> opened = <BackgroundRequest>[];
  final List<_PlatformLease> leases = <_PlatformLease>[];

  @override
  Set<BackgroundCapability> get supportedCapabilities => persistent
      ? const <BackgroundCapability>{
          BackgroundCapability.foregroundExecution,
          BackgroundCapability.persistentNotification,
        }
      : const <BackgroundCapability>{BackgroundCapability.foregroundExecution, BackgroundCapability.cpuWakeLock};

  @override
  Future<BackgroundBackendOutcome> open(BackgroundRequest request) async {
    opened.add(request);

    final lease = _PlatformLease(request);
    leases.add(lease);

    return BackgroundBackendGranted(lease);
  }

  _PlatformLease? leaseFor(String id) {
    for (final lease in leases.reversed) {
      if (lease.request.id == id) {
        return lease;
      }
    }

    return null;
  }
}

final class _PlatformLease implements BackgroundBackendLease {
  _PlatformLease(this.request);

  BackgroundRequest request;

  final StreamController<BackgroundSessionStatus> _status = StreamController<BackgroundSessionStatus>.broadcast();
  final List<BackgroundRequest> updates = <BackgroundRequest>[];

  bool released = false;

  @override
  Stream<BackgroundSessionStatus> get statusChanges => _status.stream;

  @override
  Future<void> update(BackgroundRequest request) async {
    this.request = request;
    updates.add(request);
  }

  @override
  Future<void> release() async {
    released = true;
    await _status.close();
  }
}

BackgroundRequest _job(
  String id, {
  String title = '正在下载',
  String? description,
  BackgroundExecutionKind kind = BackgroundExecutionKind.download,
  int priority = 0,
}) {
  return BackgroundRequest(
    id: id,
    kind: kind,
    title: title,
    description: description,
    requiresCpuWakeLock: false,
    progress: const BackgroundJobProgress.determinate(current: 1, total: 4),
    priority: priority,
  );
}

/// The client this suite needs: what the lines were told to show.
final class _LineClient implements LocalNotificationClient {
  final List<NotifyEvent> shown = <NotifyEvent>[];
  final List<String> calls = <String>[];

  /// The line ids that were taken down, in order.
  final List<int> cleared = <int>[];

  int get clearCount => cleared.length;

  /// Events posted for one line id, so a test can ask what *that* feature's line did.
  List<NotifyEvent> forId(int id) => shown.where((event) => event.id == id).toList();

  @override
  Future<bool> configure(NotifySetup setup) async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<void> post(NotifyEvent event) async {}

  @override
  Future<void> dismiss(int id) async {}

  @override
  Future<void> showRunningLine(NotifyEvent event) async {
    calls.add('showRunningLine');

    final failure = _throwOnShow;

    if (failure != null) {
      throw failure;
    }

    shown.add(event);
  }

  /// Set to make the next repost fail, the way a platform refuses a channel that
  /// is not ready yet.
  Error? _throwOnShow;

  @override
  Future<void> clearRunningLine({required int id}) async {
    calls.add('clearRunningLine');
    cleared.add(id);
  }
}

/// Runs [future] to its value inside the fake zone.
///
/// `fakeAsync` wants a **synchronous** callback: an async one hands back a future
/// nothing pumps, so the test waits on it until the 30 second timeout with the
/// zone already closed. Every step of this group resolves on microtasks — the
/// client is a fake, and the only timers are the ones a test elapses by hand — so
/// a flush is all an `await` costs here, and the check below is what keeps that
/// claim honest rather than assumed.
T _resolve<T>(FakeAsync async, Future<T> future) {
  late T value;
  var settled = false;
  unawaited(
    future.then((result) {
      value = result;
      settled = true;
    }),
  );
  async.flushMicrotasks();

  expect(settled, isTrue, reason: 'This step should need no timer, only the microtasks flushed above.');

  return value;
}

/// Runs a step that returns nothing, the way [_resolve] runs one that does.
void _settle(FakeAsync async, Future<void> future) {
  var settled = false;
  unawaited(future.whenComplete(() => settled = true));
  async.flushMicrotasks();

  expect(settled, isTrue, reason: 'This step should need no timer, only the microtasks flushed above.');
}

/// Advances the fake clock, then drains what the deadline started.
///
/// `elapse` only fires the window's callback; the repost itself is a future on the
/// client, so a test that reads `shown` straight after `elapse` sees the old line.
void tick(FakeAsync async, Duration gap) {
  async
    ..elapse(gap)
    ..flushMicrotasks();
}

void main() {
  late _LineClient client;
  late _PlatformBackend backend;
  late BackgroundLeaseRegistry registry;

  setUp(() {
    client = _LineClient();
    ForegroundJobs.resetForTest();
    BackgroundRuntimes.reset();
  });

  tearDown(() async {
    await ForegroundJobs.hide();
    await MediaCoreNotify.disable();
    BackgroundRuntimes.reset();
    ForegroundJobs.resetForTest();
  });

  /// Builds the runtime and arms the line inside the fake zone.
  ///
  /// A listener belongs to the zone that created it: construct the registry in
  /// `setUp`, outside `fakeAsync`, and every `changes` event — and the repost
  /// window the projector opens from it — runs against the real clock, which
  /// `async.elapse` cannot advance. The line then opens once and never updates,
  /// which reads like a projector bug and is a harness one.
  void arm(FakeAsync async, {bool persistent = false}) {
    backend = _PlatformBackend()..persistent = persistent;
    registry = BackgroundLeaseRegistry(backend: backend);
    BackgroundRuntimes.current = registry;

    _resolve(async, MediaCoreNotify.enable(client: client));
  }

  Future<BackgroundLease> hold(BackgroundRequest request) async {
    final result = await registry.acquire(request);

    expect(result, isA<BackgroundAcquireSuccess>(), reason: '$request should have been granted: $result');

    return (result as BackgroundAcquireSuccess).lease;
  }

  group('several jobs of one feature, one line', () {
    test('the first session opens its feature line on its own channel and id', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'room-42 · 25%')));
        async.flushMicrotasks();

        expect(client.shown, hasLength(1));
        expect(client.shown.single.tone, NotifyTone.progress);
        expect(client.shown.single.channel.id, kNotifyChannelDownload.id);
        expect(client.shown.single.title, '正在下载');
        expect(client.shown.single.body, 'room-42 · 25%');
        expect(client.shown.single.kind, BackgroundJobKind.download);
        expect(client.shown.single.id, kDownloadLineNotificationId);
        expect(ForegroundJobs.isShowingLine, isTrue);
      });
    });

    test('a second job of the same feature joins the line instead of taking another notification', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'room-42 · 25%')));
        _resolve(async, hold(_job('download/b', description: 'room-7 · 00:12', priority: 10)));
        tick(async, const Duration(milliseconds: 1100));

        expect(
          client.forId(kDownloadLineNotificationId),
          hasLength(2),
          reason: 'one line, opened and then repainted — never a second notification',
        );
        expect(client.shown.map((event) => event.id).toSet(), {
          kDownloadLineNotificationId,
        }, reason: 'several jobs of one feature, one notification id');
        expect(ForegroundJobs.runningCount, 2);
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.download), 'room-7 · 00:12  (还有 1 个任务)');
      });
    });

    test('another feature is another line, not a count in this one', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'a · 25%')));
        _resolve(
          async,
          hold(_job('recording/b', title: '正在录制', description: 'b · 00:12', kind: BackgroundExecutionKind.recording)),
        );
        tick(async, const Duration(milliseconds: 1100));

        expect(client.shown.map((event) => event.id).toSet(), {
          kDownloadLineNotificationId,
          kRecordingLineNotificationId,
        }, reason: 'two features, two lines: neither one buries the other in a "+1"');
        expect(
          client.forId(kRecordingLineNotificationId).single.channel.id,
          kNotifyChannelRecording.id,
          reason: 'and each on its own channel, so a user can silence one',
        );
        expect(ForegroundJobs.titleFor(BackgroundServiceOwner.recording), '正在录制');
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.recording), 'b · 00:12');
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.download), 'a · 25%');
      });
    });

    test('the job the host put first is what its own line names first', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'a · 25%')));
        _resolve(async, hold(_job('download/b', description: 'b · 00:12', priority: 10)));
        _resolve(
          async,
          hold(_job('recording/c', title: '正在录制', description: 'c', kind: BackgroundExecutionKind.recording)),
        );
        tick(async, const Duration(milliseconds: 1100));

        expect(ForegroundJobs.titleFor(BackgroundServiceOwner.download), '正在下载');
        expect(
          ForegroundJobs.bodyFor(BackgroundServiceOwner.download),
          'b · 00:12  (还有 1 个任务)',
          reason: 'the loudest *download* heads the download line',
        );
        expect(
          ForegroundJobs.bodyFor(BackgroundServiceOwner.recording),
          'c',
          reason: 'a recording with nothing else running says nothing about the transfers',
        );
      });
    });

    test('the line falls back to what is left when the loudest job ends', () {
      fakeAsync((async) {
        arm(async);
        final loud = _resolve(async, hold(_job('download/b', description: 'b · 00:12', priority: 10)));
        _resolve(async, hold(_job('download/a', description: 'a · 25%')));
        tick(async, const Duration(milliseconds: 1100));

        expect(client.shown.last.body, contains('b · 00:12'));

        _settle(async, loud.release());
        tick(async, const Duration(milliseconds: 1100));

        expect(client.shown.last.body, 'a · 25%', reason: 'the line says what is running, not what ran');
        expect(client.clearCount, 0, reason: 'one job ended; the other still needs the line');
      });
    });

    test('the last session of a feature clears that line and no other', () {
      fakeAsync((async) {
        arm(async);
        final a = _resolve(async, hold(_job('download/a', description: 'a')));
        final b = _resolve(async, hold(_job('download/b', description: 'b')));
        final c = _resolve(
          async,
          hold(_job('recording/c', title: '正在录制', description: 'c', kind: BackgroundExecutionKind.recording)),
        );
        tick(async, const Duration(milliseconds: 1100));

        _settle(async, a.release());
        _settle(async, b.release());
        async.flushMicrotasks();

        expect(client.cleared, [
          kDownloadLineNotificationId,
        ], reason: 'the download line went down; the recording line was never touched');
        expect(ForegroundJobs.isShowingLineFor(BackgroundServiceOwner.download), isFalse);
        expect(ForegroundJobs.isShowingLineFor(BackgroundServiceOwner.recording), isTrue);
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.recording), 'c');
        expect(ForegroundJobs.runningCount, 1);

        _settle(async, c.release());
        async.flushMicrotasks();

        expect(client.cleared, [kDownloadLineNotificationId, kRecordingLineNotificationId]);
        expect(ForegroundJobs.isShowingLine, isFalse);
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.recording), isNull);
      });
    });

    test('another feature changing does not repost this feature line', () {
      fakeAsync((async) {
        arm(async);
        _resolve(
          async,
          hold(_job('recording/a', title: '正在录制', description: '00:01', kind: BackgroundExecutionKind.recording)),
        );
        async.flushMicrotasks();

        expect(client.forId(kRecordingLineNotificationId), hasLength(1));

        _resolve(async, hold(_job('download/b', description: '50%')));
        tick(async, const Duration(milliseconds: 1100));
        _resolve(async, hold(_job('download/c', description: '25%')));
        tick(async, const Duration(milliseconds: 1100));

        expect(
          client.forId(kRecordingLineNotificationId),
          hasLength(1),
          reason: 'the recording line says the same thing, so the transfers do not spend it again',
        );
      });
    });
  });

  group('a platform whose service already shows the jobs', () {
    test('the line is composed but not drawn', () {
      fakeAsync((async) {
        arm(async, persistent: true);
        _resolve(async, hold(_job('download/a', description: 'room-42 · 25%')));
        _resolve(
          async,
          hold(
            _job(
              'recording/b',
              title: '正在录制',
              description: 'room-7 · 00:12',
              kind: BackgroundExecutionKind.recording,
              priority: 10,
            ),
          ),
        );
        tick(async, const Duration(seconds: 5));

        expect(client.shown, isEmpty, reason: 'two persistent notifications for one job is the bug, not the feature');
        expect(ForegroundJobs.drawsLine, isFalse);
        expect(
          ForegroundJobs.bodyFor(BackgroundServiceOwner.recording),
          'room-7 · 00:12',
          reason: 'each feature still composes its own line, and only its own',
        );
        expect(ForegroundJobs.bodyFor(BackgroundServiceOwner.download), 'room-42 · 25%');
      });
    });
  });

  group('the line is reposted on a clock, not on byte reports', () {
    test('six updates inside one window become one repost', () {
      fakeAsync((async) {
        arm(async);
        final lease = _resolve(async, hold(_job('download/a', description: '0%')));
        async.flushMicrotasks();

        // A download manager reports several times a second; a notification that
        // re-animates on every one is worse than a slightly stale one.
        for (var percent = 10; percent <= 60; percent += 10) {
          _settle(async, lease.update(lease.request.copyWith(description: '$percent%')));
        }

        tick(async, const Duration(milliseconds: 500));

        expect(
          client.shown.where((event) => event.id == kDownloadLineNotificationId).length,
          1,
          reason: 'the window opened by the first paint has not expired',
        );

        tick(async, const Duration(milliseconds: 700));

        expect(client.shown.last.body, '60%', reason: 'the newest content survives, the intermediates do not');
      });
    });

    test('a quiet stretch posts nothing further', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: '30%')));

        tick(async, const Duration(seconds: 5));

        expect(client.shown, hasLength(1));
      });
    });

    test('an update from a released session cannot resurrect the line', () {
      fakeAsync((async) {
        arm(async);
        final lease = _resolve(async, hold(_job('download/a', description: '30%')));
        async.flushMicrotasks();

        _settle(async, lease.release());
        _settle(async, lease.update(lease.request.copyWith(description: '90%')));

        tick(async, const Duration(seconds: 3));

        expect(client.shown, hasLength(1), reason: 'the line that opened; nothing after the release');
        expect(client.clearCount, 1);
        expect(ForegroundJobs.isShowingLine, isFalse);
      });
    });
  });

  group('attaching and detaching', () {
    test('a runtime that appears later still gets the line', () {
      // The ordering this class exists for: a host enables notifications in
      // `main()`, and the background backend shows up at the first job. A projector
      // that answered "no runtime, then" would leave the line never coming, which is
      // the switch-wired-to-nothing bug in a new costume.
      fakeAsync((async) {
        _resolve(async, MediaCoreNotify.enable(client: client));
        ForegroundJobs.watch();

        expect(ForegroundJobs.isWatching, isTrue);
        expect(client.shown, isEmpty, reason: 'nothing is running, so nothing is drawn');

        final later = BackgroundLeaseRegistry(backend: _PlatformBackend());
        BackgroundRuntimes.current = later;
        async.flushMicrotasks();

        _resolve(
          async,
          later.acquire(_job('download/a', description: 'room-42 · 25%')).then((result) {
            expect(result, isA<BackgroundAcquireSuccess>());
          }),
        );
        async.flushMicrotasks();

        expect(client.shown, hasLength(1), reason: 'the runtime that arrived late is the one being watched');
        expect(ForegroundJobs.sessions.map((request) => request.id), ['download/a']);
      });
    });

    test('watch() twice does not stack two watchers', () {
      fakeAsync((async) {
        arm(async);
        ForegroundJobs.watch();
        ForegroundJobs.watch();

        _resolve(async, hold(_job('download/a', description: 'a')));
        async.flushMicrotasks();

        expect(client.shown, hasLength(1), reason: 'one change, one repost — not one repost per watcher');
      });
    });

    test('hiding the line leaves the jobs themselves alone', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'a')));
        async.flushMicrotasks();

        _settle(async, ForegroundJobs.hide());

        expect(client.clearCount, 1);
        expect(backend.leaseFor('download/a')!.released, isFalse, reason: 'a silenced line is not a stopped download');
        expect(registry.activeSessionCount, 1);
      });
    });

    test('a line that was never drawn is not cleared twice', () {
      fakeAsync((async) {
        arm(async);
        _settle(async, ForegroundJobs.hide());

        expect(client.clearCount, 0, reason: 'nothing was on the shade to take away');
      });
    });
  });

  group('a line the platform refused', () {
    test('it is tried again rather than remembered as already said', () {
      fakeAsync((async) {
        arm(async);
        client._throwOnShow = StateError('the channel is not ready yet');
        _resolve(async, hold(_job('download/a', description: 'a · 25%')));
        async.flushMicrotasks();

        expect(client.forId(kDownloadLineNotificationId), isEmpty);
        expect(
          ForegroundJobs.isShowingLine,
          isFalse,
          reason: 'a refused repost is not a line on the shade, whatever the projector meant to believe',
        );

        client._throwOnShow = null;
        tick(async, const Duration(milliseconds: 1100));

        expect(
          client.forId(kDownloadLineNotificationId),
          hasLength(1),
          reason: 'the window that covered the failure has to retry, not report silence as success',
        );
        expect(ForegroundJobs.isShowingLine, isTrue);
      });
    });

    test('a runtime replaced under the projector takes its old lines down', () {
      fakeAsync((async) {
        arm(async);
        _resolve(async, hold(_job('download/a', description: 'a')));
        async.flushMicrotasks();

        expect(ForegroundJobs.isShowingLine, isTrue);

        // The host swaps the installed registry: the line up there belongs to the
        // runtime being left, and the new one has no idea it exists.
        BackgroundRuntimes.current = BackgroundLeaseRegistry(backend: _PlatformBackend());
        async.flushMicrotasks();

        expect(client.cleared, [
          kDownloadLineNotificationId,
        ], reason: 'an orphaned ongoing notification is worse than no notification');
        expect(ForegroundJobs.isShowingLine, isFalse);
      });
    });

    test('the new runtime gets lines of its own', () {
      fakeAsync((async) {
        arm(async);
        final replaced = BackgroundLeaseRegistry(backend: _PlatformBackend());
        BackgroundRuntimes.current = replaced;
        async.flushMicrotasks();

        final request = _job('recording/b', title: '正在录制', description: 'b', kind: BackgroundExecutionKind.recording);
        _resolve(async, replaced.acquire(request).then((_) {}));
        _settle(async, replaced.acquire(request));
        async.flushMicrotasks();

        expect(
          client.forId(kRecordingLineNotificationId),
          hasLength(1),
          reason: 'following the slot is what makes the second runtime projectable',
        );
      });
    });
  });
}
