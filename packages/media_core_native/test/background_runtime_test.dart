import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_native/media_core_native.dart';

/// Everything the fake platform was told to do.
final class _Calls {
  final List<Map<String, Object?>> acquires = <Map<String, Object?>>[];
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];
  final List<int> releases = <int>[];

  /// The id the next `acquire` answers with. Null is the platform's own "I will
  /// not start this", which is a different answer from a missing plugin.
  int? idToGive = 1;

  /// Thrown instead of answering, to stand in for a service the system refuses.
  PlatformException? throwWith;

  Future<Object?> Function(MethodCall call) get handler => (call) async {
    switch (call.method) {
      case 'acquire':
        acquires.add(_argumentsOf(call));

        if (throwWith != null) {
          throw throwWith!;
        }

        final id = idToGive;
        idToGive = id == null ? null : id + 1;

        return id;
      case 'update':
        updates.add(_argumentsOf(call));

        return null;
      case 'release':
        releases.add((_argumentsOf(call)['id'] as int?)!);

        return null;
      default:
        throw PlatformException(code: 'unknown-method', message: call.method);
    }
  };

  /// The notification half of the last call, as the plugin would read it.
  Map<String, Object?> get lastNotification => _notificationOf(acquires.last);

  /// The notification half of the last `update` call.
  Map<String, Object?> get lastUpdateNotification => _notificationOf(updates.last);

  Map<String, Object?> _notificationOf(Map<String, Object?> call) =>
      Map<String, Object?>.from(call['notification']! as Map<Object?, Object?>);

  Map<String, Object?> _argumentsOf(MethodCall call) =>
      Map<String, Object?>.from(call.arguments as Map<Object?, Object?>);
}

BackgroundRequest _recording({
  String id = 'recording/room-42',
  String? description,
  bool wakeLock = true,
  BackgroundJobProgress? progress,
}) {
  return BackgroundRequest(
    id: id,
    kind: BackgroundExecutionKind.recording,
    title: '正在录制',
    description: description,
    requiresCpuWakeLock: wakeLock,
    progress: progress ?? const BackgroundJobProgress.indeterminate(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kBackgroundExecutionChannel);
  late _Calls calls;

  setUp(() {
    calls = _Calls();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, calls.handler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    BackgroundRuntimes.reset();
  });

  group('the native backend', () {
    test('speaks the channel in the shape the plugin reads', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final result = await registry.acquire(
        _recording(
          description: 'room-42 · 00:12:34',
          progress: const BackgroundJobProgress.determinate(current: 3, total: 10),
        ),
      );

      expect(result, isA<BackgroundAcquireSuccess>(), reason: '$result');
      expect(calls.acquires, hasLength(1));
      expect(calls.acquires.single['wakeLock'], isTrue);
      expect(
        calls.acquires.single['owner'],
        'recording',
        reason: 'a recording session belongs to the recording service',
      );

      final notification = calls.lastNotification;
      expect(notification['title'], '正在录制');
      expect(notification['text'], 'room-42 · 00:12:34');
      expect(notification['kind'], 'record');
      expect(notification['icon'], isNull);
      expect(notification['progress'], <String, Object?>{'current': 3, 'total': 10});
    });

    test('an indeterminate job sends the shape that says so, not 0 of 0', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      await registry.acquire(_recording());

      expect(calls.lastNotification['progress'], <String, Object?>{'indeterminate': true});
    });

    test('a job that needs no wake lock says so, and keeps its own kind', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      await registry.acquire(
        const BackgroundRequest(
          id: 'download/a.bin',
          kind: BackgroundExecutionKind.download,
          title: '正在下载',
          requiresCpuWakeLock: false,
        ),
      );

      expect(calls.acquires.single['wakeLock'], isFalse);
      expect(calls.lastNotification['kind'], 'download');
      expect(calls.lastNotification['progress'], isNull, reason: 'a job with no bar must not draw a spinner');
    });

    test('each kind is routed to its own service, not to one shared one', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());

      await registry.acquire(_recording());
      await registry.acquire(
        const BackgroundRequest(id: 'download/a.bin', kind: BackgroundExecutionKind.download, title: '正在下载'),
      );
      await registry.acquire(
        const BackgroundRequest(id: 'misc-1', kind: BackgroundExecutionKind.generic, title: '别的工作'),
      );

      expect(calls.acquires.map((call) => call['owner']), [
        'recording',
        'download',
        'generic',
      ], reason: 'three kinds, three services: what ends one of them cannot end the others');
    });

    test('playback is not a job this backend would route', () {
      expect(
        () => NativeBackgroundBackend.targetFor(BackgroundServiceOwner.mediaSession),
        throwsUnsupportedError,
        reason:
            'the media session owns its own service; parking playback on a job line would be a second owner of one surface',
      );
    });

    test('update and release travel by the id the platform issued', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final lease = (await registry.acquire(_recording())) as BackgroundAcquireSuccess;

      await lease.lease.update(_recording(description: 'room-42 · 00:12:35'));
      await lease.lease.release();

      expect(calls.updates, hasLength(1));
      expect(calls.updates.single['id'], 1);
      expect(calls.lastUpdateNotification['text'], 'room-42 · 00:12:35');
      expect(calls.releases, [1]);
    });

    test('a platform that gives no id is a refusal the job can read', () async {
      calls.idToGive = null;
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());

      final result = await registry.acquire(_recording());

      expect(result, isA<BackgroundAcquireRejected>());
      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.foregroundStartRejected);
      expect(registry.activeSessionCount, 0);
    });

    test('a service the system will not start is named as such', () async {
      calls.throwWith = PlatformException(code: 'background-service-not-allowed');
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());

      final result = await registry.acquire(_recording());

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.foregroundStartRejected);
      expect(registry.activeSessionCount, 0);
    });

    test('a plugin that is not linked says so instead of pretending', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());

      final result = await registry.acquire(_recording());

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.unsupportedPlatform);
    });

    test('Android is the platform that also promises a notification', () async {
      expect(
        const NativeBackgroundBackend().supportedCapabilities,
        containsAll(<BackgroundCapability>[
          BackgroundCapability.foregroundExecution,
          BackgroundCapability.cpuWakeLock,
          BackgroundCapability.persistentNotification,
        ]),
      );
    });

    test('two recordings share one registry and each releases only itself', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final first = (await registry.acquire(_recording(id: 'recording/a'))) as BackgroundAcquireSuccess;
      final second = (await registry.acquire(_recording(id: 'recording/b'))) as BackgroundAcquireSuccess;

      expect(first.grantedCapabilities, contains(BackgroundCapability.cpuWakeLock));

      await first.lease.release();

      expect(calls.releases, [1], reason: 'only the first session was given up');
      expect(registry.activeSessionCount, 1);
      expect(registry.holds(BackgroundCapability.cpuWakeLock), isTrue);

      await second.lease.release();

      expect(calls.releases, [1, 2]);
      expect(registry.activeSessionCount, 0);
      expect(registry.holds(BackgroundCapability.cpuWakeLock), isFalse);
    });
  });

  group('the shared runtime', () {
    test('is created once and is the registry every job uses', () async {
      final first = NativeBackgroundRuntime.shared;
      final second = NativeBackgroundRuntime.shared;

      expect(identical(first, second), isTrue);
      expect(BackgroundRuntimes.current, same(first));
    });

    test('a host that installed its own runtime keeps it', () async {
      final installed = BackgroundLeaseRegistry(backend: const _NoopBackend());
      BackgroundRuntimes.current = installed;

      expect(NativeBackgroundRuntime.shared, same(installed));
      expect(calls.acquires, isEmpty);
    });
  });

  group('what the platform reports back about a session', () {
    /// Reports enter through the wire form the Android services emit, so the
    /// parsing is tested together with the delivery. The seam is
    /// `BackgroundExecution.debugPublishReport`: the alternative is a mocked
    /// `EventChannel`, whose fan-out across simultaneous subscriptions is not
    /// behaviour a test should lean on.
    void report(int id, String status) =>
        BackgroundExecution.debugPublishReport(<String, Object?>{'id': id, 'status': status});

    test('a protection the platform took back reaches the lease it belongs to', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final recording = (await registry.acquire(_recording())) as BackgroundAcquireSuccess;
      final download =
          (await registry.acquire(
                const BackgroundRequest(id: 'download/a', kind: BackgroundExecutionKind.download, title: '正在下载'),
              ))
              as BackgroundAcquireSuccess;

      final seen = <BackgroundSessionStatus>[];
      final subscription = recording.lease.statusChanges.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      report(1, 'protectionLost');
      report(1, 'aNameThisVersionDoesNotKnow');
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        BackgroundSessionStatus.protectionLost,
      ], reason: 'an unknown name is dropped, not guessed at: the plugin may be newer than this Dart side');
      expect(recording.lease.status, BackgroundSessionStatus.protectionLost);
      expect(
        registry.requestsFor(BackgroundServiceOwner.recording),
        isEmpty,
        reason: 'nothing is held any more, so the registry stops counting it and that line goes down',
      );
      expect(registry.requestsFor(BackgroundServiceOwner.download).map((request) => request.id), [
        'download/a',
      ], reason: 'the download runs in another service and heard nothing about it');
      expect(
        download.lease.status,
        BackgroundSessionStatus.running,
        reason: 'a session the report was not addressed to keeps its own status',
      );

      await subscription.cancel();
    });

    test('a report addressed to another session is not news here', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final recording = (await registry.acquire(_recording())) as BackgroundAcquireSuccess;
      await registry.acquire(
        const BackgroundRequest(id: 'download/a', kind: BackgroundExecutionKind.download, title: '正在下载'),
      );

      final seen = <BackgroundSessionStatus>[];
      final subscription = recording.lease.statusChanges.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      report(2, 'protectionLost');
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: 'a handle addresses one session, not the process');
      expect(registry.requestsFor(BackgroundServiceOwner.recording).map((request) => request.id), [
        'recording/room-42',
      ], reason: 'what the platform took back is the download service, and this lease keeps its own protection');
      expect(
        registry.requestsFor(BackgroundServiceOwner.download),
        isEmpty,
        reason: 'and the session the report was about does stop counting',
      );

      await subscription.cancel();
    });

    test('a status reported before anyone listened still reaches the lease', () async {
      // The race is the ordinary one: the service reports the state it started in
      // while Dart is still holding the `acquire` reply, before the registry has
      // subscribed to the lease it just got.
      BackgroundExecution.debugPublishReport(<String, Object?>{'id': 1, 'status': 'degraded'});

      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final recording = (await registry.acquire(_recording())) as BackgroundAcquireSuccess;

      final seen = <BackgroundSessionStatus>[];
      final subscription = recording.lease.statusChanges.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        BackgroundSessionStatus.degraded,
      ], reason: 'the broadcast stream keeps nothing for a late listener; the handle-keyed memory is what does');
      expect(registry.activeSessionCount, 1, reason: 'a hidden notification is still a running session');

      await subscription.cancel();
      await recording.lease.release();
    });

    test('a hidden notification degrades the session rather than ending it', () async {
      final registry = BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
      final recording = (await registry.acquire(_recording())) as BackgroundAcquireSuccess;

      final seen = <BackgroundSessionStatus>[];
      final subscription = recording.lease.statusChanges.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      report(1, 'degraded');
      await Future<void>.delayed(Duration.zero);

      expect(seen, [BackgroundSessionStatus.degraded]);
      expect(
        registry.activeSessionCount,
        1,
        reason: 'the service runs and the lock holds; only the line in the shade is missing',
      );
      expect(registry.requestsFor(BackgroundServiceOwner.recording), hasLength(1));

      await subscription.cancel();
    });
  });
}

class _NoopBackend implements BackgroundExecutionBackend {
  const _NoopBackend();

  @override
  Set<BackgroundCapability> get supportedCapabilities => const <BackgroundCapability>{};

  @override
  Future<BackgroundBackendOutcome> open(BackgroundRequest request) async =>
      const BackgroundBackendRefused(BackgroundAcquireFailure.unsupportedPlatform);
}
