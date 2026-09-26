import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

final class _FakeExecution implements FfmpegExecution {
  _FakeExecution(this.arguments);

  final List<String> arguments;
  final Completer<int> _exit = Completer<int>();
  bool stopCalled = false;
  bool cancelCalled = false;

  @override
  bool get isRunning => !_exit.isCompleted;

  @override
  Future<int> get exitCode => _exit.future;

  void finish(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    finish(255);
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    finish(255);
  }
}

final class _FakeExecutor implements FfmpegExecutor {
  final List<_FakeExecution> executions = <_FakeExecution>[];
  void Function(FfmpegStatistics statistics)? lastStatistics;
  int initializeCount = 0;
  int disposeCount = 0;
  bool initialized = false;

  @override
  Future<void> initialize() async {
    initializeCount++;
    initialized = true;
  }

  @override
  Future<FfmpegExecution> start({
    required List<String> arguments,
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(String message)? onLog,
  }) async {
    lastStatistics = onStatistics;
    final execution = _FakeExecution(arguments);
    executions.add(execution);
    return execution;
  }

  @override
  Future<void> dispose() async => disposeCount++;
}

/// A temporary directory that is removed when the test ends.
Directory _tempDirectory() {
  final directory = Directory.systemTemp.createTempSync('media_core_recording_test');
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return directory;
}

RecordingSource _source() => const RecordingSource.network('https://example.com/live.m3u8', id: 'room-1');

void main() {
  group('FfmpegRecordArguments', () {
    const builder = FfmpegRecordArguments();

    test('builds a segmented MPEG-TS capture of the source', () {
      final arguments = builder.recordArguments(
        url: 'https://example.com/live.m3u8',
        outputDirectory: '/recordings',
        segmentPattern: 'room_%06d.clock-v1.ts',
        journalPath: '/recordings/room.clock-v1.csv',
      );

      expect(arguments, contains('-i'));
      expect(arguments[arguments.indexOf('-i') + 1], 'https://example.com/live.m3u8');
      expect(arguments, contains('segment'));
      expect(arguments, contains('mpegts'));
      expect(arguments, contains('copy'), reason: 'recording must not transcode');
      // Segment list and naming.
      expect(arguments, contains('/recordings/room.clock-v1.csv'));
      expect(arguments, contains('/recordings/room_%06d.clock-v1.ts'));
      // The journal is CSV so segments can be joined later.
      expect(arguments[arguments.indexOf('-segment_list_type') + 1], 'csv');
      // Never overwrite an existing recording.
      expect(arguments.first, '-n');
    });

    test('maps first streams, tolerating absence', () {
      final preferred = builder.recordArguments(
        url: 'https://example.com/live.m3u8',
        outputDirectory: '/r',
        segmentPattern: 'p_%06d.ts',
        journalPath: '/r/p.csv',
      );
      final all = const FfmpegRecordArguments(
        config: FfmpegRecordConfig(preferBestStream: false),
      ).recordArguments(
        url: 'https://example.com/live.m3u8',
        outputDirectory: '/r',
        segmentPattern: 'p_%06d.ts',
        journalPath: '/r/p.csv',
      );

      expect(preferred, contains('0:v:0?'));
      expect(preferred, contains('0:a:0?'));
      expect(all, contains('0:v?'));
      expect(all, contains('0:a?'));
    });

    test('arms reconnect for HTTP and only for HTTP', () {
      final http = builder.inputProtocolOptions('https://example.com/live.m3u8');
      final rtsp = builder.inputProtocolOptions('rtsp://example.com/live');
      final udp = builder.inputProtocolOptions('udp://239.0.0.1:1234');

      expect(http, contains('-reconnect'));
      expect(http, contains('-reconnect_on_http_error'));
      expect(http[http.indexOf('-reconnect_on_http_error') + 1], '5xx', reason: 'only server failures are retried');
      expect(rtsp, contains('-rtsp_transport'));
      expect(rtsp, isNot(contains('-reconnect')), reason: 'a live RTSP input has nothing to resume');
      expect(udp, contains('-overrun_nonfatal'));
    });

    test('clamps the segment time and queue size', () {
      final arguments = const FfmpegRecordArguments(
        config: FfmpegRecordConfig(segmentTime: 1, threadQueueSize: 1),
      ).recordArguments(url: 'https://e.com/a.m3u8', outputDirectory: '/r', segmentPattern: 'p.ts', journalPath: '/r/p.csv');

      expect(arguments[arguments.indexOf('-segment_time') + 1], '10');
      expect(arguments[arguments.indexOf('-thread_queue_size') + 1], '64');
    });

    test('adds discontinuity handling only for network inputs', () {
      final network = builder.recordArguments(
        url: 'https://e.com/a.m3u8',
        outputDirectory: '/r',
        segmentPattern: 'p.ts',
        journalPath: '/r/p.csv',
      );
      final local = builder.recordArguments(
        url: 'file:///tmp/a.ts',
        outputDirectory: '/r',
        segmentPattern: 'p.ts',
        journalPath: '/r/p.csv',
      );

      expect(network, contains('-dts_delta_threshold'));
      expect(local, isNot(contains('-dts_delta_threshold')));
    });

    test('separates the user agent from the header block', () {
      final arguments = builder.recordArguments(
        url: 'https://e.com/a.m3u8',
        outputDirectory: '/r',
        segmentPattern: 'p.ts',
        journalPath: '/r/p.csv',
        headers: <String, String>{'User-Agent': 'PureLive/1.0', 'Referer': 'https://e.com/'},
      );

      expect(arguments[arguments.indexOf('-user_agent') + 1], 'PureLive/1.0');
      final headerBlock = arguments[arguments.indexOf('-headers') + 1];
      expect(headerBlock, contains('referer: https://e.com/'));
      expect(headerBlock, isNot(contains('user-agent')), reason: 'the agent has its own option');
      expect(headerBlock, endsWith('\r\n'));
    });

    test('rejects hostile headers', () {
      final normalized = FfmpegRecordArguments.normalizeHeaders(<String, String>{
        'X-Ok': 'value',
        'X-Bad\nInjected': 'value',
        'X-Empty': '   ',
        'X-Inject': 'a\r\nX-Evil: 1',
      });

      expect(normalized.keys, contains('x-ok'));
      expect(normalized.containsKey('x-bad\ninjected'), isFalse);
      expect(normalized.containsKey('x-empty'), isFalse);
      expect(normalized['x-inject'], 'a X-Evil: 1', reason: 'a newline would inject another header');
    });

    test('keeps a hostile file prefix inside the output directory', () {
      expect(FfmpegRecordArguments.safeFilePrefix('../../etc/passwd'), 'etc_passwd');
      expect(FfmpegRecordArguments.safeFilePrefix('my room: live!'), 'my_room_live');
      expect(FfmpegRecordArguments.safeFilePrefix('///'), isNotEmpty, reason: 'falls back to a timestamp');
    });

    test('builds the audio relay for a single track', () {
      final arguments = builder.audioRelayArguments(url: 'https://e.com/a.m3u8', port: 8099);

      expect(arguments, contains('-vn'));
      expect(arguments[arguments.indexOf('-c:a') + 1], 'copy');
      expect(arguments, contains('http://127.0.0.1:8099/live.ts'));
    });

    test('formats arguments for logs without changing the list', () {
      final formatted = FfmpegRecordArguments.formatArguments(<String>['-i', 'a b.mp4']);

      expect(formatted, '-i "a b.mp4"');
    });
  });

  group('FfmpegRecordingBackend', () {
    late _FakeExecutor executor;
    late Directory directory;
    late FfmpegRecordingBackend backend;

    setUp(() {
      executor = _FakeExecutor();
      directory = _tempDirectory();
      backend = FfmpegRecordingBackend(executor: executor, outputDirectory: directory.path);
    });

    tearDown(() => backend.dispose());

    test('starts a recording and reports progress from statistics', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      expect(executor.initialized, isTrue);
      expect(backend.state.status, RecordingStatus.recording);

      executor.lastStatistics!(const FfmpegStatistics(timeMs: 4200, sizeBytes: 1024 * 512));

      expect(backend.state.duration, const Duration(milliseconds: 4200));
      expect(backend.state.bytesWritten, 1024 * 512);
    });

    test('writes into the configured directory and creates it', () async {
      final nested = Directory('${directory.path}${Platform.pathSeparator}new${Platform.pathSeparator}room');
      await backend.initialize();

      await backend.start(_source(), RecordingConfig(outputPath: nested.path));

      expect(nested.existsSync(), isTrue);
      expect(
        executor.executions.single.arguments.any((argument) => argument.startsWith(nested.path)),
        isTrue,
        reason: 'the segment pattern and journal are written under the configured directory',
      );
    });

    test('refuses a second concurrent recording', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      await expectLater(backend.start(_source(), const RecordingConfig()), throwsA(isA<StateError>()));
    });

    test('refuses a local file source', () async {
      await backend.initialize();

      await expectLater(
        backend.start(const RecordingSource.file('/tmp/a.ts'), const RecordingConfig()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('refuses to start without a directory', () async {
      final homeless = FfmpegRecordingBackend(executor: executor);
      addTearDown(homeless.dispose);
      await homeless.initialize();

      await expectLater(homeless.start(_source(), const RecordingConfig()), throwsA(isA<StateError>()));
    });

    test('a user stop is a successful recording', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());
      executor.lastStatistics!(const FfmpegStatistics(timeMs: 9000, sizeBytes: 2048));

      final result = await backend.stop();

      expect(executor.executions.single.stopCalled, isTrue);
      expect(result.success, isTrue, reason: 'the viewer ended it on purpose; the file is playable');
      expect(result.duration, const Duration(milliseconds: 9000));
      expect(result.bytesWritten, 2048);
      expect(result.outputPath, backend.activeDirectory);
    });

    test('cancel is not a successful recording', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      await backend.cancel();

      expect(executor.executions.single.cancelCalled, isTrue);
      expect(backend.state.status, RecordingStatus.cancelled);
      expect(backend.state.status.isTerminal, isTrue, reason: 'cancelled is a terminal state');
      expect(backend.state.isCompleted, isFalse, reason: 'but it is not a completed recording');
    });

    test('a process that ends on its own reports success for code 0', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      executor.executions.single.finish(0);
      await Future<void>.delayed(Duration.zero);

      expect(backend.state.status, RecordingStatus.completed);
      expect(backend.state.error, isNull);
    });

    test('a process that dies reports an error with the code', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      executor.executions.single.finish(255);
      await Future<void>.delayed(Duration.zero);

      expect(backend.state.status, RecordingStatus.error);
      expect(backend.state.error.toString(), contains('255'));
    });

    test('an error from the previous attempt does not survive a new start', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());
      executor.executions.single.finish(1);
      await Future<void>.delayed(Duration.zero);
      expect(backend.state.hasError, isTrue);

      await backend.start(_source(), const RecordingConfig());

      expect(backend.state.status, RecordingStatus.recording);
      expect(backend.state.error, isNull);
    });

    test('reports state transitions to listeners', () async {
      await backend.initialize();
      final seen = <RecordingStatus>[];
      backend.onStateChanged.listen((state) => seen.add(state.status));

      await backend.start(_source(), const RecordingConfig());
      await backend.stop();
      await Future<void>.delayed(Duration.zero);

      expect(seen, containsAllInOrder(<RecordingStatus>[
        RecordingStatus.starting,
        RecordingStatus.recording,
        RecordingStatus.stopping,
      ]));
    });

    test('dispose ends a running recording', () async {
      await backend.initialize();
      await backend.start(_source(), const RecordingConfig());

      await backend.dispose();

      expect(executor.executions.single.cancelCalled, isTrue);
      expect(executor.disposeCount, 1);
    });
  });
}
