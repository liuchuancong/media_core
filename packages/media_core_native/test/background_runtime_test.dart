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
      expect(calls.acquires.single['owner'], 'recording', reason: 'a recording session belongs to the recording service');

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
      await registry.acquire(const BackgroundRequest(id: 'misc-1', kind: BackgroundExecutionKind.generic, title: '别的工作'));

      expect(
        calls.acquires.map((call) => call['owner']),
        ['recording', 'download', 'generic'],
        reason: 'three kinds, three services: what ends one of them cannot end the others',
      );
    });

    test('playback is not a job this backend would route', () {
      expect(
        () => NativeBackgroundBackend.targetFor(BackgroundServiceOwner.mediaSession),
        throwsUnsupportedError,
        reason: 'the media session owns its own service; parking playback on a job line would be a second owner of one surface',
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
}

class _NoopBackend implements BackgroundExecutionBackend {
  const _NoopBackend();

  @override
  Set<BackgroundCapability> get supportedCapabilities => const <BackgroundCapability>{};

  @override
  Future<BackgroundBackendOutcome> open(BackgroundRequest request) async =>
      const BackgroundBackendRefused(BackgroundAcquireFailure.unsupportedPlatform);
}
