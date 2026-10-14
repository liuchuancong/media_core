import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';

/// A platform that records what it was asked to do.
class _FakeBackend implements BackgroundExecutionBackend {
  _FakeBackend({
    this.capabilities = const <BackgroundCapability>{
      BackgroundCapability.foregroundExecution,
      BackgroundCapability.cpuWakeLock,
      BackgroundCapability.persistentNotification,
    },
  });

  final Set<BackgroundCapability> capabilities;

  /// Every open, in order. A test that cares about "started twice for one id"
  /// counts these rather than trusting the registry's own numbers.
  final List<BackgroundRequest> opened = <BackgroundRequest>[];

  /// Refuses the next opens instead of granting them.
  BackgroundAcquireFailure? refuseWith;

  /// Throws instead of answering, which is a backend's own bug.
  Error? throwOnOpen;

  /// Held so a test can decide when a service finishes starting.
  Completer<BackgroundBackendOutcome>? gate;

  /// Gate for the release call, so a release can be observed mid-flight.
  Completer<void>? releaseGate;

  int get releases => _leases.where((lease) => lease.released).length;

  final List<_FakeLease> _leases = <_FakeLease>[];

  _FakeLease? leaseFor(String id) {
    for (final lease in _leases.reversed) {
      if (lease.request.id == id) {
        return lease;
      }
    }

    return null;
  }

  @override
  Set<BackgroundCapability> get supportedCapabilities => capabilities;

  @override
  Future<BackgroundBackendOutcome> open(BackgroundRequest request) async {
    opened.add(request);

    final error = throwOnOpen;

    if (error != null) {
      throw error;
    }

    final refusal = refuseWith;

    if (refusal != null) {
      return BackgroundBackendRefused(refusal, 'the fake was told to refuse');
    }

    final gate = this.gate;

    if (gate != null) {
      final outcome = await gate.future;
      _remember(outcome, request);

      return outcome;
    }

    final outcome = BackgroundBackendGranted(_FakeLease(request, releaseGate: releaseGate));
    _remember(outcome, request);

    return outcome;
  }

  void _remember(BackgroundBackendOutcome outcome, BackgroundRequest request) {
    if (outcome is BackgroundBackendGranted) {
      _leases.add(outcome.lease as _FakeLease);
    }
  }
}

class _FakeLease implements BackgroundBackendLease {
  _FakeLease(this.request, {this.releaseGate});

  BackgroundRequest request;
  final Completer<void>? releaseGate;

  final StreamController<BackgroundSessionStatus> _status = StreamController<BackgroundSessionStatus>.broadcast();
  final List<BackgroundRequest> updates = <BackgroundRequest>[];

  bool released = false;

  @override
  Stream<BackgroundSessionStatus> get statusChanges => _status.stream;

  void say(BackgroundSessionStatus status) {
    if (!_status.isClosed) {
      _status.add(status);
    }
  }

  @override
  Future<void> update(BackgroundRequest request) async {
    this.request = request;
    updates.add(request);
  }

  @override
  Future<void> release() async {
    released = true;

    if (releaseGate != null) {
      await releaseGate!.future;
    }

    await _status.close();
  }
}

BackgroundRequest _request(
  String id, {
  String title = '正在录制',
  BackgroundExecutionKind kind = BackgroundExecutionKind.recording,
  bool wakeLock = true,
  int priority = 0,
  BackgroundDuplicatePolicy duplicate = BackgroundDuplicatePolicy.reject,
}) {
  return BackgroundRequest(
    id: id,
    kind: kind,
    title: title,
    requiresCpuWakeLock: wakeLock,
    priority: priority,
    duplicatePolicy: duplicate,
  );
}

Future<BackgroundAcquireSuccess> _grant(BackgroundLeaseRegistry registry, BackgroundRequest request) async {
  final result = await registry.acquire(request);

  expect(result, isA<BackgroundAcquireSuccess>(), reason: '$request should have been granted: $result');

  return result as BackgroundAcquireSuccess;
}

void main() {
  group('lease registry', () {
    test('a granted session holds exactly what the request asked for', () async {
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend());
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      expect(lease.status, BackgroundSessionStatus.running);
      expect(
        lease.grantedCapabilities,
        containsAll(<BackgroundCapability>[
          BackgroundCapability.foregroundExecution,
          BackgroundCapability.cpuWakeLock,
          BackgroundCapability.persistentNotification,
        ]),
      );
      expect(registry.activeSessionCount, 1);
      expect(registry.activeCapabilities, contains(BackgroundCapability.cpuWakeLock));
    });

    test('a job that does not want the CPU awake is not granted it', () async {
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend());
      final lease = (await _grant(registry, _request('dl-1', wakeLock: false))).lease;

      expect(lease.grantedCapabilities, {
        BackgroundCapability.foregroundExecution,
        BackgroundCapability.persistentNotification,
      });
      expect(registry.holds(BackgroundCapability.cpuWakeLock), isFalse);
    });

    test('background audio is never granted by a job lease', () async {
      final registry = BackgroundLeaseRegistry(
        backend: _FakeBackend(
          capabilities: <BackgroundCapability>{
            BackgroundCapability.foregroundExecution,
            BackgroundCapability.backgroundAudio,
          },
        ),
      );
      final lease = (await _grant(registry, _request('rec-1', wakeLock: false))).lease;

      expect(lease.grantedCapabilities, isNot(contains(BackgroundCapability.backgroundAudio)));
    });

    test('release is idempotent and only ever releases its own session', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final first = (await _grant(registry, _request('rec-1'))).lease;
      final second = (await _grant(registry, _request('rec-2'))).lease;

      await first.release();
      await first.release();

      expect(backend.leaseFor('rec-1')!.released, isTrue);
      expect(backend.leaseFor('rec-2')!.released, isFalse, reason: 'one job must not stop another');
      expect(registry.activeSessionCount, 1);

      await second.release();
      expect(registry.activeSessionCount, 0);
      expect(registry.activeCapabilities, isEmpty);
    });

    test('the capability stays held while any session holds it', () async {
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend());
      final a = (await _grant(registry, _request('rec-1'))).lease;
      final b = (await _grant(registry, _request('rec-2'))).lease;

      await a.release();

      expect(registry.holds(BackgroundCapability.cpuWakeLock), isTrue, reason: 'b still needs the CPU awake');

      await b.release();

      expect(registry.holds(BackgroundCapability.cpuWakeLock), isFalse);
    });

    test('a session update rewrites its own record and nobody else', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final a = (await _grant(registry, _request('rec-1', title: 'A'))).lease;
      final b = (await _grant(registry, _request('rec-2', title: 'B'))).lease;

      await a.update(a.request.copyWith(description: '00:12:34'));

      expect(backend.leaseFor('rec-1')!.updates.single.description, '00:12:34');
      expect(backend.leaseFor('rec-2')!.updates, isEmpty);
      expect(b.request.title, 'B');
      expect(a.request.description, '00:12:34');
    });

    test('updating a released session says nothing to the platform', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      await lease.release();
      await lease.update(lease.request.copyWith(description: 'late'));

      expect(backend.leaseFor('rec-1')!.updates, isEmpty);
      expect(lease.status, BackgroundSessionStatus.stopped);
    });

    test('an update for another id is refused by the lease', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      await lease.update(_request('rec-2'));

      expect(backend.leaseFor('rec-1')!.updates, isEmpty);
      expect(lease.request.id, 'rec-1');
    });

    test('a duplicate id is rejected without disturbing the session that holds it', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final owner = (await _grant(registry, _request('rec-1'))).lease;

      final result = await registry.acquire(_request('rec-1', title: '另开一路'));

      expect(result, isA<BackgroundAcquireRejected>());
      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.invalidRequest);
      expect(result.duplicateOfId, 'rec-1');
      expect(backend.opened.length, 1, reason: 'a rejection must not start a second service');
      expect(owner.status, BackgroundSessionStatus.running);
      expect(registry.activeSessionCount, 1);
    });

    test('a shared duplicate gives up the view, not the session', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final owner = (await _grant(registry, _request('rec-1'))).lease;
      final view = (await _grant(registry, _request('rec-1', duplicate: BackgroundDuplicatePolicy.share))).lease;

      expect(view.id, owner.id);

      await view.release();

      expect(backend.leaseFor('rec-1')!.released, isFalse, reason: 'the owner still holds it');
      expect(registry.activeSessionCount, 1);

      await owner.release();

      expect(backend.leaseFor('rec-1')!.released, isTrue);
      expect(registry.activeSessionCount, 0);
    });

    test('an update duplicate rewrites the session in place', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final owner = (await _grant(registry, _request('rec-1'))).lease;
      final again = (await _grant(
        registry,
        _request('rec-1', title: '正在录制 · 主播8891', duplicate: BackgroundDuplicatePolicy.update),
      )).lease;

      expect(backend.opened, hasLength(1));
      expect(registry.activeSessionCount, 1);
      expect(again.request.title, '正在录制 · 主播8891');
      expect(owner.request.title, '正在录制 · 主播8891');
      expect(backend.leaseFor('rec-1')!.updates.single.title, '正在录制 · 主播8891');
    });

    test('two acquires of one id while it is starting start one service', () async {
      final backend = _FakeBackend()..gate = Completer<BackgroundBackendOutcome>();
      final registry = BackgroundLeaseRegistry(backend: backend);

      final first = registry.acquire(_request('rec-1'));
      final second = registry.acquire(_request('rec-1'));

      backend.gate!.complete(BackgroundBackendGranted(_FakeLease(_request('rec-1'))));

      final a = await first;
      final b = await second;

      expect(backend.opened, hasLength(1));
      expect(a, isA<BackgroundAcquireSuccess>());
      expect(b, isA<BackgroundAcquireRejected>(), reason: 'the second one is the duplicate the policy rejects');
    });

    test('a release during start-up does not leave a service running', () async {
      final gate = Completer<BackgroundBackendOutcome>();
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend()..gate = gate);

      final acquiring = registry.acquire(_request('rec-1'));
      await Future<void>.delayed(Duration.zero);

      // The job is over before the service arrived, and the only handle is the
      // record the registry is starting under.
      expect(registry.peek('rec-1'), isNotNull);
      await registry.peek('rec-1')!.release();

      final late = _FakeLease(_request('rec-1'));
      gate.complete(BackgroundBackendGranted(late));

      final result = await acquiring;

      expect(result, isA<BackgroundAcquireRejected>());
      expect(late.released, isTrue, reason: 'a service that arrives after the job ended must not be left behind');
      expect(registry.activeSessionCount, 0);
    });

    test('an unusable request is refused before the platform is asked', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);

      final noId = await registry.acquire(_request(''));
      final noTitle = await registry.acquire(_request('rec-1', title: ''));
      final sillyPriority = await registry.acquire(_request('rec-1', priority: 9999));

      for (final result in <BackgroundAcquireResult>[noId, noTitle, sillyPriority]) {
        expect(result, isA<BackgroundAcquireRejected>());
        expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.invalidRequest);
      }

      expect(backend.opened, isEmpty);
    });

    test('a platform with no capability says so instead of granting an empty session', () async {
      final backend = _FakeBackend(capabilities: <BackgroundCapability>{});
      final registry = BackgroundLeaseRegistry(backend: backend);

      final result = await registry.acquire(_request('rec-1'));

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.unsupportedPlatform);
      expect(backend.opened, isEmpty);
    });

    test('a wake lock that cannot be had refuses the job rather than degrading it', () async {
      final backend = _FakeBackend(
        capabilities: <BackgroundCapability>{
          BackgroundCapability.foregroundExecution,
          BackgroundCapability.persistentNotification,
        },
      );
      final registry = BackgroundLeaseRegistry(backend: backend);

      final result = await registry.acquire(_request('rec-1'));

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.capabilityUnavailable);

      final withoutLock = await registry.acquire(_request('dl-1', wakeLock: false));
      expect(withoutLock, isA<BackgroundAcquireSuccess>());
    });

    test('a refused start is reported with the reason and leaves nothing held', () async {
      final backend = _FakeBackend()..refuseWith = BackgroundAcquireFailure.foregroundStartRejected;
      final registry = BackgroundLeaseRegistry(backend: backend);

      final result = await registry.acquire(_request('rec-1'));

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.foregroundStartRejected);
      expect(registry.activeSessionCount, 0);
    });

    test('a backend that throws is a refusal, not a crash in the job', () async {
      final backend = _FakeBackend()..throwOnOpen = StateError('the service died');
      final registry = BackgroundLeaseRegistry(backend: backend);

      final result = await registry.acquire(_request('rec-1'));

      expect((result as BackgroundAcquireRejected).reason, BackgroundAcquireFailure.foregroundStartRejected);
      expect(registry.activeSessionCount, 0);
    });

    test('a status the platform reports reaches the lease', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      final seen = <BackgroundSessionStatus>[];
      final subscription = lease.statusChanges.listen(seen.add);

      backend.leaseFor('rec-1')!.say(BackgroundSessionStatus.degraded);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [BackgroundSessionStatus.degraded]);
      expect(lease.status, BackgroundSessionStatus.degraded);

      await subscription.cancel();
    });

    test('a session the platform tore down stops counting as held', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final first = (await _grant(registry, _request('rec-1'))).lease;
      final second = (await _grant(registry, _request('rec-2'))).lease;

      backend.leaseFor('rec-1')!.say(BackgroundSessionStatus.stopped);
      await Future<void>.delayed(Duration.zero);

      expect(registry.activeSessionCount, 1);
      expect(first.status, BackgroundSessionStatus.stopped);
      expect(second.status, BackgroundSessionStatus.running);

      await second.release();
      expect(registry.holds(BackgroundCapability.cpuWakeLock), isFalse);
    });

    test('a session the platform tears down after its release is not a new fact', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      await lease.release();
      backend.leaseFor('rec-1')!.say(BackgroundSessionStatus.stopped);
      await Future<void>.delayed(Duration.zero);

      expect(lease.status, BackgroundSessionStatus.stopped);
      expect(registry.activeSessionCount, 0);
    });

    test('the projector is told after the record changed, not before', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final seen = <int>[];
      final subscription = registry.changes.listen((_) => seen.add(registry.activeSessionCount));

      await registry.acquire(_request('rec-1'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [1], reason: 'the event means "re-read the list", so the list must already be the new one');

      await registry.acquire(_request('rec-2'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [1, 2]);

      await subscription.cancel();
    });

    test('an update to a session announces the aggregate too', () async {
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend());
      final lease = (await _grant(registry, _request('rec-1'))).lease;
      final changes = <int>[];
      final subscription = registry.changes.listen((_) => changes.add(registry.activeSessionCount));

      await lease.update(lease.request.copyWith(description: '00:12:34'));
      await Future<void>.delayed(Duration.zero);

      expect(changes, [1], reason: 'the count did not move, but what the line says did');
      expect(registry.activeRequests.single.description, '00:12:34');

      await subscription.cancel();
    });

    test('the platform capabilities are the backend answer, not the held one', () async {
      final registry = BackgroundLeaseRegistry(
        backend: _FakeBackend(capabilities: <BackgroundCapability>{BackgroundCapability.foregroundExecution}),
      );

      expect(registry.platformCapabilities, {BackgroundCapability.foregroundExecution});
      expect(registry.activeCapabilities, isEmpty, reason: 'nothing is held until somebody asks');
    });

    test('disposing gives every session back and stops announcing', () async {
      final backend = _FakeBackend();
      final registry = BackgroundLeaseRegistry(backend: backend);
      final first = (await _grant(registry, _request('rec-1'))).lease;
      final second = (await _grant(registry, _request('rec-2'))).lease;
      expect(first.id, 'rec-1');
      expect(second.id, 'rec-2');

      final changes = <int>[];
      final subscription = registry.changes.listen((_) => changes.add(0));
      await Future<void>.delayed(Duration.zero);

      await registry.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(backend.releases, 2, reason: 'dispose gives every session back through the platform');
      expect(registry.activeSessionCount, 0);

      final after = <int>[];
      await registry.changes.forEach((_) => after.add(0));
      expect(after, isEmpty, reason: 'the announcements stop with the registry');
      await subscription.cancel();
    });

    test('the aggregate puts the loudest job first and keeps arrival order', () async {
      final registry = BackgroundLeaseRegistry(backend: _FakeBackend());
      await registry.acquire(_request('a', title: 'A'));
      await registry.acquire(_request('b', title: 'B', priority: 5));
      await registry.acquire(_request('c', title: 'C', priority: 5));

      expect(registry.activeRequests.map((request) => request.title), ['B', 'C', 'A']);
    });

    test('release waits for the platform without double-releasing', () async {
      final gate = Completer<void>();
      final backend = _FakeBackend()..releaseGate = gate;
      final registry = BackgroundLeaseRegistry(backend: backend);
      final lease = (await _grant(registry, _request('rec-1'))).lease;

      final releasing = lease.release();
      final alsoReleasing = lease.release();

      gate.complete();
      await releasing;
      await alsoReleasing;

      expect(backend.releases, 1);
      expect(lease.status, BackgroundSessionStatus.stopped);
    });
  });

  group('request value', () {
    test('every field is part of equality', () {
      const base = BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'T');
      const others = <BackgroundRequest>[
        BackgroundRequest(id: 'rec-2', kind: BackgroundExecutionKind.recording, title: 'T'),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.download, title: 'T'),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'U'),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'T', description: 'd'),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'T', requiresCpuWakeLock: false),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'T', icon: 'ic_mine'),
        BackgroundRequest(
          id: 'rec-1',
          kind: BackgroundExecutionKind.recording,
          title: 'T',
          progress: BackgroundJobProgress.determinate(current: 1, total: 4),
        ),
        BackgroundRequest(
          id: 'rec-1',
          kind: BackgroundExecutionKind.recording,
          title: 'T',
          progress: BackgroundJobProgress.determinate(current: 3, total: 4),
        ),
        BackgroundRequest(id: 'rec-1', kind: BackgroundExecutionKind.recording, title: 'T', priority: 3),
        BackgroundRequest(
          id: 'rec-1',
          kind: BackgroundExecutionKind.recording,
          title: 'T',
          duplicatePolicy: BackgroundDuplicatePolicy.share,
        ),
      ];

      for (final other in others) {
        expect(other, isNot(base), reason: '$other differs from $base in one field and must not compare equal');
        expect(other.hashCode, isNot(base.hashCode), reason: other.toString());
      }

      expect(base, base.copyWith());
      expect(base.hashCode, base.copyWith().hashCode);
    });

    test('copyWith keeps what it is not given', () {
      const request = BackgroundRequest(
        id: 'rec-1',
        kind: BackgroundExecutionKind.recording,
        title: 'T',
        description: 'd',
        priority: 2,
      );
      final updated = request.copyWith(description: 'e');

      expect(updated.description, 'e');
      expect(updated.priority, 2);
      expect(updated.title, 'T');
      expect(request.validationError(), isNull);
    });

    test('a progress is a value, and each of its two numbers is part of it', () {
      const indeterminate = BackgroundJobProgress.indeterminate();
      const quarter = BackgroundJobProgress.determinate(current: 1, total: 4);
      const sameQuarter = BackgroundJobProgress.determinate(current: 1, total: 4);

      expect(quarter, sameQuarter);
      expect(quarter.hashCode, sameQuarter.hashCode);
      expect(quarter, isNot(indeterminate), reason: '"a quarter done" and "no end in sight" are different claims');
      expect(quarter, isNot(const BackgroundJobProgress.determinate(current: 2, total: 4)));
      expect(quarter, isNot(const BackgroundJobProgress.determinate(current: 1, total: 5)));
      expect(quarter.fraction, 0.25);
      expect(indeterminate.fraction, isNull);
      expect(indeterminate.isIndeterminate, isTrue);
    });

    test('every kind belongs to the job service, not the media surface', () {
      for (final kind in BackgroundExecutionKind.values) {
        expect(kind.serviceOwner, BackgroundServiceOwner.jobService);
      }
    });
  });
}
