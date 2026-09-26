import 'package:media_core/media_core.dart' show RecordingConfig, RecordingSource, RecordingStatus;
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

import '../fakes/fake_ffmpeg.dart';
import '../module_demo.dart';

/// Recording a live stream: the argument list, then the process lifecycle.
///
/// FFmpeg failures are almost always statement about the argument list, and
/// "exit code 255" says nothing on its own — so the demo prints the exact argv it
/// would hand to FFmpeg, and then drives the state machine with a fake process so
/// the transitions are visible on a machine that has no FFmpeg installed.
class RecordingDemo extends ModuleDemo {
  /// Creates the demo.
  const RecordingDemo();

  @override
  String get id => 'recording';

  @override
  ModuleCategory get category => ModuleCategory.capability;

  @override
  String get nameZh => '录播：FFmpeg 参数与状态机';

  @override
  String get nameEn => 'Recording: FFmpeg arguments and the state machine';

  @override
  String get purposeZh =>
      '录播把一条直播流转成分段 MPEG-TS 文件：分段让"失败只丢几秒而不是整场"，音频中继让同一份录制里既有流也能有本地音轨。参数构造是纯函数（可复制去 shell 复现），状态机与退出码归因由 backend 负责，两者都能在没有 FFmpeg 的机器上跑。';

  @override
  String get purposeEn =>
      'Recording turns a live stream into segmented MPEG-TS files: segments make a failure cost seconds instead of a whole session, and the audio relay lets one recording carry both the stream and a local audio track. The argument builder is a pure function (paste it into a shell to reproduce), and the state machine plus exit-code attribution sit in the backend — both run without FFmpeg installed.';

  @override
  List<String> get pointsZh => const <String>[
        'FfmpegRecordArguments.recordArguments — 纯函数：URL / 输出目录 / 分段模板 / CSV 日志路径',
        '分段：segmentTime + %06d 模式，边录边出可播文件',
        '同一 FFmpeg 里多一路输入做音频中继（-map 两路），避免二次封装',
        '退出码 255 既可能是流断了也可能是被主动停止，所以 backend 记录"停止意图"来归因',
        '统计回调给出已写字节与媒体时间 → 同时喂给进度条和 memory 模块',
      ];

  @override
  List<String> get pointsEn => const <String>[
        'FfmpegRecordArguments.recordArguments — a pure function: URL, output directory, segment pattern, CSV journal path',
        'Segmentation: segmentTime with a %06d pattern, so playable files appear while recording',
        'A second input inside the same FFmpeg relays audio (-map twice), avoiding a re-mux step',
        'Exit code 255 means both "the stream died" and "someone stopped us", so the backend tracks the stop intent to attribute it',
        'The statistics callback gives bytes written and media time — feeding a progress bar and the memory module at once',
      ];

  @override
  String get snippet => '''
final backend = FfmpegRecordingBackend(outputDirectory: '\${dir}/recordings');

backend.onStateChanged.listen((state) => print('\${state.status.name}: \${state.bytesWritten}B'));

await backend.start(
  RecordingSource.network('https://example.com/live/stream.flv'),
  const RecordingConfig(recordAudio: true),
);

// ... and later:
final result = await backend.stop();   // per-segment files are already playable
''';

  @override
  Future<String> run() async {
    final buffer = StringBuffer();

    _argumentsSection(buffer);
    await _lifecycleSection(buffer);

    return buffer.toString();
  }

  /// The argument list, which is what an FFmpeg failure is usually about.
  void _argumentsSection(StringBuffer buffer) {
    buffer.writeln('argument list for a segmented capture (paste it into a shell to reproduce):');

    final cases = <({String label, String url, FfmpegRecordConfig config})>[
      (
        label: 'FLV live stream',
        url: 'https://example.com/live/room.flv',
        config: FfmpegRecordConfig.defaults,
      ),
      (
        label: 'HLS stream, 10-minute segments, no best-stream preference',
        url: 'https://example.com/live/room.m3u8',
        config: const FfmpegRecordConfig(
          segmentTime: 600,
          preferBestStream: false,
          filePrefix: 'room-8891',
          includeTimestampPrefix: true,
        ),
      ),
      (
        label: 'RTMP with a 5s read timeout and a short journal',
        url: 'rtmp://example.com/app/stream',
        // rwTimeout is in seconds.
        config: const FfmpegRecordConfig(rwTimeout: 5, journalSuffix: '.csv'),
      ),
    ];

    for (final item in cases) {
      final arguments = FfmpegRecordArguments(config: item.config).recordArguments(
        url: item.url,
        outputDirectory: '/data/recordings',
        segmentPattern: '${FfmpegRecordArguments.safeFilePrefix(item.config.filePrefix)}_%06d${item.config.segmentSuffix}',
        journalPath: '/data/recordings/journal${item.config.journalSuffix}',
        filePrefix: FfmpegRecordArguments.safeFilePrefix(item.config.filePrefix),
      );

      buffer
        ..writeln()
        ..writeln('  ${item.label}:')
        ..writeln('    ffmpeg ${arguments.join(' ')}');
    }

    buffer
      ..writeln()
      ..writeln('  → -c copy: the capture is a remux, not a transcode (no quality loss, no CPU)')
      ..writeln('  → -f segment + the %06d pattern: every N seconds a finished, playable file appears')
      ..writeln('  → per-scheme input options: HLS gets its own flags, RTMP its timeout, FLV its buffering')
      ..writeln();
  }

  /// The state machine, driven by a fake process.
  Future<void> _lifecycleSection(StringBuffer buffer) async {
    final executor = FakeFfmpegExecutor(statisticsInterval: const Duration(milliseconds: 40));
    final directory = '/tmp/media_core_recording_demo';
    final backend = FfmpegRecordingBackend(executor: executor, outputDirectory: directory);

    final transitions = <String>[];
    final subscription = backend.onStateChanged.listen((state) {
      transitions.add(
        '${state.status.name}'
        '${state.bytesWritten == 0 ? '' : ' (${state.bytesWritten ~/ 1024}KB)'}',
      );
    });

    buffer.writeln('state machine (fake FFmpeg, no native library involved):');

    await backend.start(
      RecordingSource.network('https://example.com/live/room.flv'),
      const RecordingConfig(),
    );

    // Let a few statistics ticks arrive.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final result = await backend.stop();
    await subscription.cancel();

    buffer
      ..writeln('  ${transitions.join(' → ')}')
      ..writeln('  stop() reported success=${result.success}, '
          'duration=${result.duration.inMilliseconds}ms, '
          'bytes=${result.bytesWritten}')
      ..writeln('  executor.initialized=${executor.initialized} — initialize() only warms the native '
          'library up; the first start loads it. Sessions: ${executor.started.length}')
      ..writeln();

    // The "nobody stopped it" case: the stream died, and the exit code is all
    // there is to go on.
    final failing = FakeFfmpegExecutor(statisticsInterval: const Duration(milliseconds: 30));
    final second = FfmpegRecordingBackend(executor: failing, outputDirectory: directory);
    final failures = <String>[];
    final secondSubscription = second.onStateChanged.listen((state) {
      if (state.status == RecordingStatus.error || state.status == RecordingStatus.completed) {
        failures.add('${state.status.name}: ${state.error ?? 'exit 0'}');
      }
    });

    await second.start(RecordingSource.network('https://example.com/live/dying.flv'), const RecordingConfig());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await failing.last?.cancel(); // the process ends on its own, with 255
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await secondSubscription.cancel();

    buffer
      ..writeln('a process that ends by itself (stream dropped):')
      ..writeln('  ${failures.join(' | ')}')
      ..writeln('  → the same 255 would be a normal stop if stop() had been called first;')
      ..writeln('    that is exactly what the backend\'s stop intent tracks.')
      ..writeln()
      ..writeln('memory module view of a running recording: the account reports FFmpeg\'s '
          'written bytes — one of the few measured figures in the framework.');

    await backend.dispose();
    await second.dispose();
  }
}
