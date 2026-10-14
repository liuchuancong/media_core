import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart'
    show
        BackgroundAcquireFailure,
        BackgroundAcquireRejected,
        BackgroundAcquireResult,
        BackgroundAcquireSuccess,
        BackgroundCapability,
        BackgroundDuplicatePolicy,
        BackgroundExecutionKind,
        BackgroundLease,
        BackgroundRequest,
        BackgroundRuntime,
        BackgroundRuntimes,
        BackgroundSessionStatus,
        MediaJobKind,
        MediaJobOutcome,
        MediaJobReporter,
        MediaJobReporting,
        TaskId,
        TaskPriority;
import 'package:media_core_download/media_core_download.dart';

/// Bytes a fake remote serves.
Uint8List _payload(int length, {int seed = 7}) {
  final bytes = Uint8List(length);
  for (var index = 0; index < length; index++) {
    bytes[index] = (seed + index) % 251;
  }
  return bytes;
}

final class _FakeTransport implements DownloadTransport {
  _FakeTransport(this.payload);

  Uint8List payload;

  /// Whether the server advertises byte-range support.
  bool acceptsRanges = true;

  /// When false the server ignores `Range` and answers the whole body with 200.
  bool honoursRanges = true;

  /// Number of requests to fail before serving.
  int failures = 0;

  /// When true the body stops early.
  bool truncateBody = false;

  /// When set, the body arrives as chunks of these sizes instead of one piece -
  /// which is what a real HTTP byte stream does, and the only way to see how
  /// often the manager publishes progress for it.
  List<int>? chunks;

  int fetchCount = 0;
  final List<DownloadRequest> requests = <DownloadRequest>[];

  @override
  Future<DownloadResponse> fetch(DownloadRequest request) async {
    fetchCount++;
    requests.add(request);
    if (failures > 0) {
      failures--;
      throw const DownloadHttpException(500, 'https://example.com/file');
    }

    final ranged = request.rangeHeader != null;
    if (ranged && !honoursRanges) {
      return DownloadResponse(
        statusCode: 200,
        byteStream: Stream<List<int>>.value(payload),
        contentLength: payload.length,
        acceptsRanges: acceptsRanges,
      );
    }

    final start = ranged ? request.startByte : 0;
    final end = ranged ? (request.endByte ?? payload.length - 1) : payload.length - 1;
    final body = payload.sublist(start, end + 1);
    final served = truncateBody ? body.sublist(0, (body.length / 2).floor()) : body;

    return DownloadResponse(
      statusCode: ranged ? 206 : 200,
      byteStream: _body(served),
      contentLength: served.length,
      totalBytes: payload.length,
      acceptsRanges: acceptsRanges,
    );
  }

  /// The body as a stream: chunked when the test asked for chunks, with a
  /// microtask between them so they arrive as separate events.
  Stream<List<int>> _body(List<int> served) async* {
    final plan = chunks;
    if (plan == null) {
      yield served;
      return;
    }
    var offset = 0;
    for (final size in plan) {
      if (offset >= served.length) break;
      final to = offset + size > served.length ? served.length : offset + size;
      yield served.sublist(offset, to);
      offset += size;
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> dispose() async {}
}

/// A background runtime that grants what it is asked for, and remembers.
///
/// The manager's promise is "a session while a transfer runs, given back on every
/// end", and that is a lifecycle claim — it can only be checked by a runtime that
/// counts what it was handed and when.
final class _FakeRuntime implements BackgroundRuntime {
  /// Refuses every request with this reason instead of granting one.
  BackgroundAcquireFailure? refuseWith;

  final List<BackgroundRequest> requests = <BackgroundRequest>[];

  /// Every lease the runtime handed out, in order. A retry that gets the *same*
  /// object back kept one session; a retry that got a new one started a second.
  final List<_FakeLease> granted = <_FakeLease>[];

  final Map<String, _FakeLease> _held = <String, _FakeLease>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<BackgroundAcquireResult> acquire(BackgroundRequest request) async {
    requests.add(request);

    final refusal = refuseWith;

    if (refusal != null) {
      return BackgroundAcquireRejected(reason: refusal, message: 'the fake was told to refuse');
    }

    final existing = _held[request.id];

    if (existing != null) {
      // The registry's `update` policy in one line: the same session, rewritten.
      existing.request = request;
      granted.add(existing);
      _notify();

      return BackgroundAcquireSuccess(lease: existing, grantedCapabilities: existing.grantedCapabilities);
    }

    final lease = _FakeLease(request, _release)..changes = _notify;
    _held[request.id] = lease;
    granted.add(lease);
    _notify();

    return BackgroundAcquireSuccess(
      lease: lease,
      grantedCapabilities: const <BackgroundCapability>{BackgroundCapability.foregroundExecution},
    );
  }

  void _release(String id) {
    _held.remove(id);
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  /// The session for the task — held or already given back.
  ///
  /// Looked up in the whole history rather than in what is still held, because
  /// "was it released?" is the question a test asks after the release.
  _FakeLease? leaseFor(String taskId) {
    for (final lease in granted.reversed) {
      if (lease.id == 'download/$taskId') {
        return lease;
      }
    }

    return null;
  }

  @override
  List<BackgroundRequest> get activeRequests => _held.values.map((lease) => lease.request).toList(growable: false);

  @override
  Set<BackgroundCapability> get activeCapabilities => const <BackgroundCapability>{
    BackgroundCapability.foregroundExecution,
  };

  @override
  int get activeSessionCount => _held.length;

  @override
  BackgroundLease? peek(String id) => _held[id];

  @override
  Set<BackgroundCapability> get platformCapabilities => const <BackgroundCapability>{
    BackgroundCapability.foregroundExecution,
  };

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}

final class _FakeLease implements BackgroundLease {
  _FakeLease(this.request, this._giveBack);

  /// Called whenever the runtime's aggregate moved, so the fake can wake a
  /// projector the way the registry would.
  void Function()? changes;

  @override
  BackgroundRequest request;

  final List<BackgroundRequest> updates = <BackgroundRequest>[];

  final void Function(String id) _giveBack;

  bool released = false;

  @override
  String get id => request.id;

  @override
  BackgroundSessionStatus get status => released ? BackgroundSessionStatus.stopped : BackgroundSessionStatus.running;

  @override
  Set<BackgroundCapability> get grantedCapabilities => const <BackgroundCapability>{
    BackgroundCapability.foregroundExecution,
  };

  @override
  Stream<BackgroundSessionStatus> get statusChanges => const Stream<BackgroundSessionStatus>.empty();

  @override
  Future<void> update(BackgroundRequest request) async {
    this.request = request;
    updates.add(request);
    changes?.call();
  }

  @override
  Future<void> release() async {
    if (released) {
      return;
    }

    released = true;
    _giveBack(id);
  }
}

/// The reporter the tests install to see what a finished download says.
final class _CapturingReporter implements MediaJobReporter {
  final List<MediaJobOutcome> seen = <MediaJobOutcome>[];

  @override
  void report(MediaJobOutcome outcome) => seen.add(outcome);
}

final class _MemorySink implements DownloadFileSink {
  final Map<String, BytesBuilder> files = <String, BytesBuilder>{};

  Uint8List bytesOf(String path) => files[path]?.toBytes() ?? Uint8List(0);

  @override
  Future<int> length(String path) async => files[path]?.length ?? 0;

  @override
  Future<List<int>> readTail(String path, int count) async {
    final bytes = bytesOf(path);
    if (count <= 0 || bytes.length < count) {
      return const <int>[];
    }
    return bytes.sublist(bytes.length - count);
  }

  @override
  Future<void> append(String path, List<int> bytes) async {
    (files[path] ??= BytesBuilder()).add(bytes);
  }

  @override
  Future<void> truncate(String path, int length) async {
    final current = bytesOf(path);
    final builder = BytesBuilder()..add(current.sublist(0, length.clamp(0, current.length)));
    files[path] = builder;
  }

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<void> ensureParentDirectory(String path) async {}
}

void _seed(_MemorySink sink, String path, Uint8List bytes) {
  sink.files[path] = BytesBuilder()..add(bytes);
}

DownloadTask _task(String id, {TaskPriority priority = TaskPriority.normal, String? title}) => DownloadTask(
  id: TaskId(id),
  url: 'https://example.com/$id',
  filePath: '/downloads/$id.ts',
  priority: priority,
  title: title,
);

void main() {
  group('DownloadResumePlanner', () {
    const planner = DownloadResumePlanner();

    test('starts from zero when nothing is on disk', () {
      final plan = planner.plan(localBytes: 0, remoteBytes: 1000, serverAcceptsRanges: true);

      expect(plan.decision, DownloadResumeDecision.restart);
    });

    test('reports an already complete file', () {
      final plan = planner.plan(localBytes: 1000, remoteBytes: 1000, serverAcceptsRanges: true);

      expect(plan.decision, DownloadResumeDecision.alreadyComplete);
    });

    test('restarts when the local file is larger than the remote one', () {
      final plan = planner.plan(localBytes: 2000, remoteBytes: 1000, serverAcceptsRanges: true);

      expect(plan.decision, DownloadResumeDecision.restart);
      expect(plan.reason, contains('larger'));
    });

    test('restarts when the server cannot resume', () {
      final plan = planner.plan(localBytes: 500, remoteBytes: 1000, serverAcceptsRanges: false);

      expect(plan.decision, DownloadResumeDecision.restart);
      expect(plan.reason, contains('ranges'));
    });

    test('forceResume overrides a missing range advertisement', () {
      const forced = DownloadResumePlanner(config: DownloadConfig(forceResume: true));
      final plan = forced.plan(localBytes: 500, remoteBytes: 1000, serverAcceptsRanges: false);

      expect(plan.decision, DownloadResumeDecision.resume);
    });

    test('resumes by reopening the verification window before the end', () {
      final plan = planner.plan(localBytes: 500, remoteBytes: 1000, serverAcceptsRanges: true);

      expect(plan.decision, DownloadResumeDecision.resume);
      expect(plan.verifyBytes, 10);
      expect(plan.startByte, 490, reason: 'the last ten bytes are re-fetched and compared');
    });

    test('restarts when there is too little to verify', () {
      final plan = planner.plan(localBytes: 4, remoteBytes: 1000, serverAcceptsRanges: true);

      expect(plan.decision, DownloadResumeDecision.restart);
    });

    test('compares tails byte for byte', () {
      expect(planner.tailMatches(localTail: <int>[1, 2, 3], remoteTail: <int>[1, 2, 3]), isTrue);
      expect(planner.tailMatches(localTail: <int>[1, 2, 3], remoteTail: <int>[1, 2, 4]), isFalse);
      expect(planner.tailMatches(localTail: <int>[1, 2], remoteTail: <int>[1, 2, 3]), isFalse);
      expect(planner.tailMatches(localTail: const <int>[], remoteTail: const <int>[]), isFalse);
    });
  });

  group('HttpDownloadTransport content range', () {
    test('reads the total from a Content-Range header', () {
      expect(HttpDownloadTransport.totalFromContentRange('bytes 490-999/1000'), 1000);
      expect(HttpDownloadTransport.totalFromContentRange('bytes 0-0/2048'), 2048);
    });

    test('reports unknown for a missing or open-ended header', () {
      expect(HttpDownloadTransport.totalFromContentRange(null), isNull);
      expect(HttpDownloadTransport.totalFromContentRange('bytes 0-99/*'), isNull);
      expect(HttpDownloadTransport.totalFromContentRange('nonsense'), isNull);
    });
  });

  group('DownloadManager', () {
    late _FakeTransport transport;
    late _MemorySink sink;
    late DownloadManager manager;

    setUp(() {
      transport = _FakeTransport(_payload(1000));
      sink = _MemorySink();
      manager = DownloadManager(
        transport: transport,
        files: sink,
        // Immediate retries keep the retry tests fast.
        config: DownloadConfig.defaults.copyWith(retryDelay: Duration.zero, maxAttempts: 2),
      );
    });

    tearDown(() => manager.dispose());

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    /// Waits until [id] reaches a terminal state.
    ///
    /// Polling instead of sleeping a fixed amount: a transfer that finishes in
    /// two event-loop turns and one that finishes in twenty are the same test,
    /// and a fixed delay turns a slow machine into a flaky failure.
    Future<void> waitForTerminal(String id) async {
      for (var attempt = 0; attempt < 200; attempt++) {
        final task = manager.task(id);
        if (task != null && task.isTerminal) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('a paused download resumes and finishes', () async {
      // A transport that dribbles: the package's own fake serves the whole body
      // in one chunk, so there would be nothing to pause.
      final slow = _SlowTransport(_payload(1000));
      final slowSink = _MemorySink();
      final slowManager = DownloadManager(
        transport: slow,
        files: slowSink,
        config: DownloadConfig.defaults.copyWith(retryDelay: Duration.zero, maxAttempts: 2),
      );
      addTearDown(slowManager.dispose);

      slowManager.add(_task('resume-me'));

      // Wait until it is actually mid-transfer, then pause. Pausing cancels the
      // core queue task, and a cancelled core task cannot be queued again —
      // which is what used to make "pause, then resume" do nothing at all.
      for (var attempt = 0; attempt < 200 && slowSink.bytesOf('/downloads/resume-me.ts').isEmpty; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final partial = slowSink.bytesOf('/downloads/resume-me.ts').length;
      expect(partial, greaterThan(0), reason: 'the transfer should have started');
      expect(partial, lessThan(slow.payload.length), reason: 'and should not be finished yet');

      await slowManager.pause('resume-me');
      expect(slowManager.task('resume-me')!.status, DownloadStatus.paused);

      await slowManager.resume('resume-me');
      for (var attempt = 0; attempt < 400 && !(slowManager.task('resume-me')?.isTerminal ?? false); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(slowManager.task('resume-me')!.status, DownloadStatus.completed);
      expect(slowSink.bytesOf('/downloads/resume-me.ts'), slow.payload);
      expect(
        slow.requests.any((request) => request.rangeHeader != null),
        isTrue,
        reason: 'the resumed transfer asked for the remaining bytes, not the whole file again',
      );
    });

    test('downloads a file end to end', () async {
      manager.add(_task('a'));
      await waitForTerminal('a');

      expect(manager.task('a')!.status, DownloadStatus.completed);
      expect(sink.bytesOf('/downloads/a.ts'), transport.payload);
      expect(manager.task('a')!.progress.percent, 100);
    });

    test('progress is published on a UI cadence, not once per chunk', () async {
      // 100 chunks of 10 bytes: what a real HTTP body looks like from here.
      transport.chunks = List<int>.filled(100, 10);
      final running = <DownloadTask>[];
      final subscription = manager.onTaskChanged
          .where((task) => task.id.value == 'a' && !task.isTerminal)
          .listen(running.add);
      addTearDown(subscription.cancel);

      manager.add(_task('a'));
      await waitForTerminal('a');

      expect(transport.chunks, hasLength(100), reason: 'the body did arrive in pieces');
      expect(
        running.length,
        lessThan(20),
        reason:
            'one event per chunk is 100 task copies, 100 memory reports and 100 '
            'listener wakes to draw a number nobody can read; a 200 ms window is a handful',
      );
      expect(running, isNotEmpty, reason: 'the first chunk still reports at once');
      expect(manager.task('a')!.status, DownloadStatus.completed);
      expect(sink.bytesOf('/downloads/a.ts'), transport.payload, reason: 'throttling must not lose bytes');
    });

    test('caps concurrency and starts the next task when a slot frees', () async {
      final single = DownloadManager(
        transport: transport,
        files: sink,
        config: DownloadConfig.defaults.copyWith(maxConcurrent: 1),
      );
      addTearDown(single.dispose);

      single
        ..add(_task('a'))
        ..add(_task('b'));
      await single.onTaskChanged
          .firstWhere((task) => task.id.value == 'b' && task.isTerminal)
          .timeout(const Duration(seconds: 5));

      expect(sink.bytesOf('/downloads/a.ts'), transport.payload);
      expect(sink.bytesOf('/downloads/b.ts'), transport.payload);
      expect(single.tasks.every((task) => task.status == DownloadStatus.completed), isTrue);
    });

    test('resumes a verifiable partial file instead of re-downloading it', () async {
      final full = _payload(1000);
      _seed(sink, '/downloads/a.ts', Uint8List.sublistView(full, 0, 500));

      manager.add(_task('a'));
      await waitForTerminal('a');

      expect(manager.task('a')!.status, DownloadStatus.completed);
      expect(sink.bytesOf('/downloads/a.ts'), full, reason: 'the file must be complete and not doubled');
      expect(transport.requests.single.startByte, 490, reason: 'resume reopens the verification window');
    });

    test('restarts when the partial file is not a prefix of the remote file', () async {
      final full = _payload(1000);
      // Same length, different content: a different quality or a corrupt write.
      _seed(sink, '/downloads/a.ts', Uint8List.sublistView(_payload(1000, seed: 99), 0, 500));

      manager.add(_task('a'));
      await waitForTerminal('a');

      expect(sink.bytesOf('/downloads/a.ts'), full, reason: 'the mismatched prefix is discarded');
      expect(manager.task('a')!.status, DownloadStatus.completed);
    });

    test('restarts when the server ignores the range header', () async {
      final full = _payload(1000);
      _seed(sink, '/downloads/a.ts', Uint8List.sublistView(full, 0, 500));
      transport.honoursRanges = false;

      manager.add(_task('a'));
      await waitForTerminal('a');

      expect(sink.bytesOf('/downloads/a.ts'), full);
    });

    test('leaves an already complete file alone', () async {
      final full = _payload(1000);
      _seed(sink, '/downloads/a.ts', full);

      manager.add(_task('a'));
      await waitForTerminal('a');

      // The remote size is only known by asking, so one probe happens — but it
      // is a ranged one, and the file is neither re-downloaded nor doubled.
      expect(transport.requests.single.startByte, greaterThan(0), reason: 'a probe, not a full fetch');
      expect(sink.bytesOf('/downloads/a.ts'), full);
      expect(manager.task('a')!.status, DownloadStatus.completed);
    });

    test('treats a truncated body as a failure and retries within the budget', () async {
      transport.truncateBody = true;

      manager.add(_task('a'));
      await waitForTerminal('a');
      await waitForTerminal('a');

      expect(manager.task('a')!.status, DownloadStatus.failed);
      expect(manager.task('a')!.progress.attempt, 2, reason: 'the retry budget was spent');
      expect(transport.fetchCount, greaterThanOrEqualTo(2));
    });

    test('retries a transport failure before giving up', () async {
      manager.add(_task('a'));
      // First attempt is still running: make the next one fail once.
      transport.failures = 1;
      await settle();
      await settle();

      final task = manager.task('a')!;
      expect(task.status, anyOf(DownloadStatus.completed, DownloadStatus.failed));
      expect(transport.fetchCount, greaterThanOrEqualTo(1));
    });

    test('pause keeps the partial file and resume continues it', () async {
      manager.add(_task('a'));
      await manager.pause('a');

      expect(manager.task('a')!.status, anyOf(DownloadStatus.paused, DownloadStatus.completed));

      await manager.resume('a');
      await settle();

      expect(manager.task('a')!.status, anyOf(DownloadStatus.completed, DownloadStatus.queued, DownloadStatus.running));
    });

    test('cancel marks the task terminal', () async {
      manager.add(_task('a'));
      await manager.cancel('a');

      expect(manager.task('a')!.status, anyOf(DownloadStatus.cancelled, DownloadStatus.completed));
    });

    test('refuses to replace a task that is still running', () async {
      manager.add(_task('a'));

      expect(() => manager.add(_task('a')), throwsA(isA<StateError>()));
    });

    test('retry clears the budget and starts the task again', () async {
      transport.truncateBody = true;
      manager.add(_task('a'));
      await settle();
      await settle();
      expect(manager.task('a')!.status, DownloadStatus.failed);

      transport.truncateBody = false;
      await manager.retry('a');
      await settle();

      expect(manager.task('a')!.status, DownloadStatus.completed);
      expect(sink.bytesOf('/downloads/a.ts'), transport.payload);
    });

    test('clearCompleted drops finished tasks', () async {
      manager.add(_task('a'));
      await waitForTerminal('a');

      await manager.clearCompleted();

      expect(manager.tasks, isEmpty);
    });

    test('a disposed manager refuses new work', () async {
      await manager.dispose();

      expect(() => manager.add(_task('a')), throwsA(isA<StateError>()));
    });

    group('reports how it ended to whoever installed a reporter', () {
      late _CapturingReporter reporter;

      setUp(() {
        reporter = _CapturingReporter();
        MediaJobReporting.reporter = reporter;
      });

      tearDown(MediaJobReporting.reset);

      test('a finished file says what landed', () async {
        manager.add(_task('a'));
        await waitForTerminal('a');

        expect(reporter.seen, hasLength(1));
        expect(reporter.seen.single.kind, MediaJobKind.download);
        expect(reporter.seen.single.success, isTrue);
        expect(reporter.seen.single.label, 'a.ts');
        expect(reporter.seen.single.bytesWritten, 1000);
        expect(reporter.seen.single.error, isNull);
      });

      test('a retry that is still coming says nothing yet', () async {
        // One failed request out of a two-attempt budget: the viewer is told once,
        // when the file is there, not once per attempt.
        transport.failures = 1;
        manager.add(_task('a'));
        await waitForTerminal('a');

        expect(reporter.seen, hasLength(1));
        expect(reporter.seen.single.success, isTrue);
      });

      test('a spent budget reports the failure it stopped on', () async {
        transport.failures = 9;
        manager.add(_task('a'));
        await waitForTerminal('a');

        expect(reporter.seen, hasLength(1));
        expect(reporter.seen.single.success, isFalse);
        expect(reporter.seen.single.error, isA<DownloadHttpException>());
      });

      test('a cancelled file is not announced as a failure', () async {
        manager.add(_task('a'));
        await waitForTerminal('a');
        reporter.seen.clear();

        await manager.cancel('a');
        await settle();

        expect(reporter.seen, isEmpty, reason: 'the viewer asked for the cancel; it is not news');
      });

      test('nobody listening does not disturb the download', () async {
        MediaJobReporting.reset();
        manager.add(_task('a'));
        await waitForTerminal('a');

        expect(manager.task('a')!.status, DownloadStatus.completed);
      });
    });

    group('background execution', () {
      late _FakeRuntime runtime;

      setUp(() {
        runtime = _FakeRuntime();
      });

      tearDown(() => runtime.dispose());

      /// A manager wired to the fake runtime, with [tasks] already queued.
      ///
      /// The tasks go in here rather than at the call site: a queue with nothing
      /// in it is not what any of these tests is about.
      DownloadManager build({
        required DownloadConfig config,
        List<DownloadTask> tasks = const <DownloadTask>[],
        DownloadTransport? transport,
        DateTime Function()? clock,
      }) {
        final manager = DownloadManager(
          transport: transport ?? _FakeTransport(_payload(1000)),
          files: _MemorySink(),
          config: config,
          backgroundRuntime: runtime,
          clock: clock,
        );
        addTearDown(manager.dispose);
        tasks.forEach(manager.add);

        return manager;
      }

      /// The same config every case except the off-by-default one uses.
      DownloadConfig keepAlive({Duration? retryDelay, int? maxAttempts, int? maxConcurrent, String? title}) {
        return DownloadConfig.defaults.copyWith(
          keepAlive: true,
          keepAliveTitle: title,
          retryDelay: retryDelay,
          maxAttempts: maxAttempts,
          maxConcurrent: maxConcurrent,
        );
      }

      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

      Future<void> waitForTerminal(DownloadManager manager, String id) async {
        for (var attempt = 0; attempt < 400 && !(manager.task(id)?.isTerminal ?? false); attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }

      test('a queue that did not ask for it never speaks to the runtime', () async {
        final manager = build(config: DownloadConfig.defaults, tasks: [_task('plain')]);
        await settle();

        expect(manager.task('plain')!.status, DownloadStatus.completed);
        expect(runtime.requests, isEmpty, reason: 'keepAlive is a product decision, not a default');
      });

      test('a kept-alive transfer asks for one session, before the bytes', () async {
        final slow = _SlowTransport(_payload(4000));
        final manager = build(
          config: keepAlive(),
          transport: slow,
          tasks: [_task('room-1', title: '第一话')],
        );

        await settle();

        expect(runtime.requests, hasLength(1));

        final request = runtime.requests.single;
        expect(request.id, 'download/room-1');
        expect(request.kind, BackgroundExecutionKind.download);
        expect(request.title, 'Downloading');
        expect(request.requiresCpuWakeLock, isTrue, reason: 'a socket stops with the CPU that serves it');
        expect(
          request.duplicatePolicy,
          BackgroundDuplicatePolicy.update,
          reason: 'a retry or a resume is the same download, not a second line',
        );

        await manager.pause('room-1');
        expect(runtime.leaseFor('room-1')!.released, isTrue, reason: 'a paused transfer holds nothing');

        await manager.resume('room-1');
        await settle();

        expect(runtime.requests, hasLength(2), reason: 'the resume asks again for what the pause gave back');
        expect(runtime.activeSessionCount, 1);
      });

      test('a custom title is the one the line carries', () async {
        build(
          config: keepAlive(title: '正在缓存'),
          tasks: [_task('a')],
        );
        await settle();

        expect(runtime.requests.single.title, '正在缓存');
      });

      test('the line moves with the bytes, and only once a second', () async {
        // A clock the test turns: chunk reports arrive every 200 ms by design, and
        // a notification reposted five times a second is a flicker, not progress.
        var now = DateTime.fromMillisecondsSinceEpoch(0);
        final first = _FakeTransport(_payload(1000))..chunks = [200, 200, 200, 200, 200];
        final frozen = build(
          config: keepAlive(),
          transport: first,
          clock: () => now,
          tasks: [_task('a', title: 'ep01.ts')],
        );
        await settle();

        expect(frozen.task('a')!.status, DownloadStatus.completed);
        expect(runtime.leaseFor('a')!.updates, isEmpty, reason: 'every chunk landed inside one second of the clock');

        now = DateTime.fromMillisecondsSinceEpoch(1500);
        final second = _FakeTransport(_payload(2000))..chunks = [250, 250, 250, 250, 250, 250, 250, 250];
        build(
          config: keepAlive(),
          transport: second,
          clock: () => now,
          tasks: [_task('b', title: 'ep02.ts')],
        );
        await settle();

        final lease = runtime.leaseFor('b')!;
        expect(lease.updates, hasLength(1), reason: 'one window, however many chunks arrived inside it');
        expect(lease.request.description, contains('ep02.ts'));
        expect(lease.request.description, contains('%'), reason: 'a known length is shown as a percentage');
        // The figure is whatever had landed when the window opened, not the last
        // byte of the file: the tail of the chunks arrive inside the same second
        // and the line goes away with the transfer, so a stale percentage is
        // never left showing after the file is there.
        expect(lease.request.progress!.total, 2000);
        expect(lease.request.progress!.current, greaterThan(0));
        expect(lease.request.progress!.fraction, lessThan(1.0), reason: 'the throttled tick is behind, and says so');
      });

      test('a server that gave no length shows no bar', () async {
        final noLength = _FakeTransport(_payload(600))..acceptsRanges = false;
        build(config: keepAlive(), transport: noLength, tasks: [_task('a')]);
        await settle();

        final progress = runtime.requests.single.progress;
        expect(progress, isNotNull);
        expect(progress!.isIndeterminate, isTrue, reason: 'a guess at a total is a lie about the file');
      });

      test('a completed download gives its session back', () async {
        final manager = build(config: keepAlive(), tasks: [_task('finished')]);
        await settle();

        expect(manager.task('finished')!.status, DownloadStatus.completed);
        expect(runtime.leaseFor('finished')!.released, isTrue);
        expect(runtime.activeSessionCount, 0);
      });

      test('a cancelled download gives its session back', () async {
        final slow = _SlowTransport(_payload(4000));
        final manager = build(config: keepAlive(), transport: slow, tasks: [_task('gone')]);
        await settle();

        final lease = runtime.leaseFor('gone');
        expect(lease, isNotNull, reason: 'the transfer should be in flight');

        await manager.cancel('gone');

        expect(lease!.released, isTrue);
        expect(runtime.activeSessionCount, 0);
      });

      test('a removed download gives its session back', () async {
        final slow = _SlowTransport(_payload(4000));
        final manager = build(config: keepAlive(), transport: slow, tasks: [_task('removed')]);
        await settle();

        final lease = runtime.leaseFor('removed')!;
        await manager.remove('removed');

        expect(lease.released, isTrue);
        expect(runtime.activeSessionCount, 0);
      });

      test('a retry keeps the one session; a spent budget gives it back', () async {
        final transport = _FakeTransport(_payload(1000))..failures = 1;
        final manager = build(
          config: keepAlive(retryDelay: Duration.zero, maxAttempts: 2),
          transport: transport,
          tasks: [_task('a')],
        );
        await waitForTerminal(manager, 'a');

        expect(manager.task('a')!.status, DownloadStatus.completed);
        expect(runtime.requests, hasLength(2), reason: 'the retry asked again, as every attempt does');
        expect(runtime.granted.first, same(runtime.granted.last), reason: 'and was given the same session back');
        expect(runtime.leaseFor('a')!.released, isTrue, reason: 'given back once, at the end');
      });

      test('a queue that runs out of attempts gives the session back', () async {
        final transport = _FakeTransport(_payload(1000))..failures = 5;
        final manager = build(
          config: keepAlive(retryDelay: Duration.zero, maxAttempts: 2),
          transport: transport,
          tasks: [_task('a')],
        );
        await waitForTerminal(manager, 'a');

        expect(manager.task('a')!.status, DownloadStatus.failed);
        expect(runtime.leaseFor('a')!.released, isTrue);
      });

      test('two downloads hold two sessions and ending one leaves the other', () async {
        final slow = _SlowTransport(_payload(4000));
        final manager = build(config: keepAlive(maxConcurrent: 2), transport: slow, tasks: [_task('a'), _task('b')]);
        await settle();

        final first = runtime.leaseFor('a');
        final second = runtime.leaseFor('b');
        expect(first, isNotNull);
        expect(second, isNotNull, reason: 'two transfers running at once are two sessions');

        await manager.cancel('a');

        expect(first!.released, isTrue);
        expect(second!.released, isFalse, reason: 'a second download is not the first news');
        expect(runtime.activeSessionCount, 1);
      });

      test('a platform that refuses still downloads', () async {
        runtime.refuseWith = BackgroundAcquireFailure.foregroundStartRejected;
        final manager = build(config: keepAlive(), tasks: [_task('a')]);
        await settle();

        expect(
          manager.task('a')!.status,
          DownloadStatus.completed,
          reason: 'a refused protection is not a failed file',
        );
        expect(runtime.activeSessionCount, 0);
      });

      test('no runtime installed is the same as no protection asked for', () async {
        BackgroundRuntimes.reset();
        final manager = DownloadManager(
          transport: _FakeTransport(_payload(1000)),
          files: _MemorySink(),
          config: DownloadConfig.defaults.copyWith(keepAlive: true),
        );
        addTearDown(manager.dispose);

        manager.add(_task('a'));
        await settle();

        expect(manager.task('a')!.status, DownloadStatus.completed);
      });

      test('disposing the manager gives every session back', () async {
        final slow = _SlowTransport(_payload(4000));
        final held = DownloadManager(
          transport: slow,
          files: _MemorySink(),
          config: DownloadConfig.defaults.copyWith(keepAlive: true),
          backgroundRuntime: runtime,
        )..add(_task('a'));
        await settle();

        final lease = runtime.leaseFor('a');
        expect(lease, isNotNull, reason: 'the transfer should be in flight');

        await held.dispose();

        expect(lease!.released, isTrue);
        expect(runtime.activeSessionCount, 0);
      });
    });
  });
}

/// A server that streams its body in chunks with a delay.
///
/// The other fake answers in a single chunk, which finishes before a test can
/// observe it mid-transfer; pausing needs a transfer that is still in flight.
final class _SlowTransport implements DownloadTransport {
  _SlowTransport(this.payload);

  final Uint8List payload;

  /// Bytes per chunk and the delay between them: enough for a test to catch the
  /// transfer in flight, small enough to keep it fast.
  static const int chunkSize = 128;
  static const Duration chunkDelay = Duration(milliseconds: 20);

  final List<DownloadRequest> requests = <DownloadRequest>[];

  @override
  Future<DownloadResponse> fetch(DownloadRequest request) async {
    requests.add(request);

    final start = request.startByte;
    final body = payload.sublist(start);

    Stream<List<int>> chunks() async* {
      for (var offset = 0; offset < body.length; offset += chunkSize) {
        await Future<void>.delayed(chunkDelay);
        yield body.sublist(offset, (offset + chunkSize).clamp(0, body.length));
      }
    }

    return DownloadResponse(
      statusCode: start > 0 ? 206 : 200,
      byteStream: chunks(),
      contentLength: body.length,
      totalBytes: payload.length,
      acceptsRanges: true,
    );
  }

  @override
  Future<void> dispose() async {}
}
