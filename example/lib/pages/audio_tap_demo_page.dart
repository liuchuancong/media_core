import 'dart:async';

import 'package:example/ui/demo_log.dart';
import 'package:example/ui/demo_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;

/// Stage B1 + B2 of the spectrum plan, run against a real engine.
///
/// The page itself is only a host: it opens one audio-capable URL on a bare
/// media_kit player (no kernel, no video) and hands the player to
/// [mk.MediaKitAudioTapProbe], which mounts `astats` into `af` and reads the
/// levels back through `af-metadata`. The numbers a host actually needs for
/// the go/no-go are the ones on screen: the callback rate (B2 budget ≥30 Hz)
/// and the parse cost (B2 budget <2 ms), next to the live dB readings (B1).
class AudioTapDemoPage extends StatefulWidget {
  /// Creates the page.
  const new({super.key});

  @override
  State<AudioTapDemoPage> createState() => _AudioTapDemoPageState();
}

final class _AudioTapDemoPageState extends State<AudioTapDemoPage> {
  final DemoLog _log = DemoLog();
  final TextEditingController _url = TextEditingController(
    text: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );

  mk.Player? _player;
  mk.MediaKitAudioTapProbe? _probe;
  StreamSubscription<mk.AudioTapStats>? _statsSub;
  StreamSubscription<mk.AudioTapLevelFrame>? _frameSub;

  bool _tapRunning = false;
  mk.AudioTapStats _stats = const mk.AudioTapStats(
    frames: 0,
    hz: 0,
    lastParseUs: 0,
    maxParseUs: 0,
    window: 0,
  );
  mk.AudioTapLevelFrame? _lastFrame;

  @override
  void dispose() {
    unawaited(_teardown());
    _url.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await _teardown();
    final player = mk.Player();
    final probe = mk.MediaKitAudioTapProbe(player);
    _player = player;
    _probe = probe;
    _statsSub = probe.stats.listen((stats) {
      if (mounted) setState(() => _stats = stats);
    });
    _frameSub = probe.frames.listen((frame) {
      if (mounted) setState(() => _lastFrame = frame);
    });
    await player.open(mk.Media(_url.text));
    await player.play();
    _log.add('opened: ${_url.text}');
  }

  Future<void> _toggleTap() async {
    final probe = _probe;
    if (probe == null) return;
    if (_tapRunning) {
      await probe.stop();
      _tapRunning = false;
      _log.add('tap stopped');
    } else {
      final mounted0 = await probe.start();
      _tapRunning = mounted0;
      _log.add(mounted0 ? 'tap started: ${mk.MediaKitAudioTapProbe.filterEntry}' : 'tap failed to start');
    }
    if (mounted) setState(() {});
  }

  Future<void> _teardown() async {
    await _statsSub?.cancel();
    await _frameSub?.cancel();
    _statsSub = null;
    _frameSub = null;
    final probe = _probe;
    final player = _player;
    _probe = null;
    _player = null;
    _tapRunning = false;
    await probe?.stop();
    await player?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hzPass = _stats.hz >= 30;
    final parsePass = _stats.maxParseUs > 0 && _stats.maxParseUs < 2000;
    return DemoPageScaffold(
      title: '音频分析 B1/B2：astats 探针',
      subtitle: '挂 astats 进 af，经 af-metadata 读电平；实测回调率与解析耗时',
      log: _log,
      actions: [
        FilledButton(onPressed: () => unawaited(_open()), child: const Text('打开并播放')),
        FilledButton.tonal(
          onPressed: _player == null ? null : () => unawaited(_toggleTap()),
          child: Text(_tapRunning ? '停止探针' : '启动探针'),
        ),
      ],
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: '媒体地址', isDense: true),
            ),
          ),
          _row('回调率 (B2 ≥30 Hz)', _stats.hz.toStringAsFixed(1), pass: _tapRunning && hzPass),
          _row('解析耗时 (B2 <2 ms)', '${(_stats.lastParseUs / 1000).toStringAsFixed(2)} ms', pass: parsePass),
          _row('最差解析', '${(_stats.maxParseUs / 1000).toStringAsFixed(2)} ms', pass: parsePass),
          _row('帧数', '${_stats.frames}'),
          _row(
            '整体 RMS / Peak (B1)',
            '${_lastFrame?.overallRmsDb?.toStringAsFixed(1) ?? '-'} / '
                '${_lastFrame?.overallPeakDb?.toStringAsFixed(1) ?? '-'} dB',
          ),
          _row('声道数', '${_lastFrame?.channels.length ?? 0}'),
          if (_tapRunning && _stats.frames > 60)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                hzPass && parsePass
                    ? 'B1/B2 通过：通道满足频谱预算'
                    : 'B1/B2 未达预算：降低帧率预算或改走 B3/B4 通道',
                style: TextStyle(color: hzPass && parsePass ? Colors.green : theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool? pass}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: pass == null
                  ? null
                  : pass
                      ? Colors.green
                      : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
