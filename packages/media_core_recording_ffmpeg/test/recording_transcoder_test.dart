import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

final class _Execution implements FfmpegExecution {
  _Execution(this._exit);

  final Completer<int> _exit;

  @override
  bool get isRunning => !_exit.isCompleted;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> stop() async {
    if (!_exit.isCompleted) _exit.complete(255);
  }

  @override
  Future<void> cancel() async {
    if (!_exit.isCompleted) _exit.complete(255);
  }
}

final class _FakeExecutor implements FfmpegExecutor {
  _FakeExecutor({this.exitCode = 0});

  final int exitCode;
  final List<List<String>> runs = <List<String>>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<FfmpegExecution> start({
    required List<String> arguments,
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(String message)? onLog,
  }) async {
    runs.add(arguments);
    final output = arguments.last;
    File(output).parent.createSync(recursive: true);
    File(output).writeAsStringSync('encoded');
    final exit = Completer<int>()..complete(exitCode);
    return _Execution(exit);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory directory;
  late File input;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('transcode-test');
    input = File('${directory.path}/source.combined.mp4')..writeAsStringSync('source');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('a complete encode is renamed from its partial and reported', () async {
    final executor = _FakeExecutor();
    final output = '${directory.path}/source.transcoded.mp4';

    final result = await FfmpegRecordingTranscoder(executor: executor).run(inputPath: input.path, outputPath: output);

    expect(result.success, isTrue);
    expect(result.outputPath, output);
    expect(File(output).existsSync(), isTrue);
    expect(File('${directory.path}/source.partial.mp4').existsSync(), isFalse);
    expect(executor.runs.single, containsAllInOrder(['-c:v', 'libx264']));
    expect(executor.runs.single, containsAllInOrder(['-preset', 'veryfast']));
    expect(executor.runs.single, containsAllInOrder(['-b:v', '4000k']));
    expect(executor.runs.single, containsAllInOrder(['-c:a', 'copy']));
  });

  test('a failed encode leaves no output and no partial file', () async {
    final executor = _FakeExecutor(exitCode: 1);
    final output = '${directory.path}/source.transcoded.mp4';

    final result = await FfmpegRecordingTranscoder(executor: executor).run(inputPath: input.path, outputPath: output);

    expect(result.success, isFalse);
    expect(File(output).existsSync(), isFalse);
    expect(File('${directory.path}/source.partial.mp4').existsSync(), isFalse);
  });

  test('an existing complete output is not encoded again', () async {
    final executor = _FakeExecutor();
    final output = File('${directory.path}/source.transcoded.mp4')..writeAsStringSync('done');

    final result = await FfmpegRecordingTranscoder(
      executor: executor,
    ).run(inputPath: input.path, outputPath: output.path);

    expect(result.success, isTrue);
    expect(result.alreadyThere, isTrue);
    expect(executor.runs, isEmpty);
  });

  test('a missing input is a failed result, not a throw', () async {
    final executor = _FakeExecutor();
    final result = await FfmpegRecordingTranscoder(
      executor: executor,
    ).run(inputPath: '${directory.path}/missing.mp4', outputPath: '${directory.path}/out.mp4');

    expect(result.success, isFalse);
    expect(executor.runs, isEmpty);
  });
}
