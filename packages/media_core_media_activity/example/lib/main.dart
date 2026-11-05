import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:media_core_media_activity_example/demo_session.dart';

void main() {
  runApp(const MediaActivityDemoApp());
}

/// The example app: one page, one simulated session, one Live Activity.
///
/// Run on an iOS device or simulator with the MediaActivityWidgetExtension
/// target installed (see README.md), lock the screen, and the Live Activity
/// renders the lyrics while the buttons drive the same events a real lyric
/// engine would.
class MediaActivityDemoApp extends StatelessWidget {
  /// Creates the app.
  const MediaActivityDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'media_core_media_activity demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// The demo page: capability line, now-playing card, event buttons and the
/// command log of what came back from the lock screen.
class DemoPage extends StatefulWidget {
  /// Creates the page.
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final DemoPlaybackSession _session = DemoPlaybackSession();

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    unawaited(_session.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('锁屏歌词 Live Activity 示例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CapabilityCard(text: session.capabilityText),
          const SizedBox(height: 12),
          _NowPlayingCard(session: session),
          const SizedBox(height: 12),
          _ControlGrid(session: session),
          const SizedBox(height: 12),
          _CommandLogCard(session: session),
          const SizedBox(height: 24),
          Text(
            '歌词引擎每 4 秒产生一次换行事件；两次事件之间锁屏按 rate × Δt '
            '自己走时间，不会推送进度（spec §8.1）。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The capability line at the top.
class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// What the activity should be showing right now.
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.session});

  final DemoPlaybackSession session;

  @override
  Widget build(BuildContext context) {
    final active = session.hasActiveActivity;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.album : Icons.album_outlined,
                  color: active ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(
                  active ? 'Live Activity 进行中' : '没有活动的 Live Activity',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (active)
                  Icon(
                    session.isPlaying ? Icons.play_arrow : Icons.pause,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const Divider(height: 24),
            Text(active ? session.trackTitle : '—', style: theme.textTheme.titleLarge),
            Text(active ? session.trackArtist : '', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              active ? session.currentLyric : '点「开始播放」创建 Live Activity',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: active ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              active ? 'position: ${(session.positionMs / 1000).toStringAsFixed(1)}s' : '',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The event buttons; each maps to one coordinator event.
class _ControlGrid extends StatelessWidget {
  const _ControlGrid({required this.session});

  final DemoPlaybackSession session;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => unawaited(session.start()),
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始播放'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(session.toggle()),
          icon: Icon(session.isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(session.isPlaying ? '暂停' : '继续'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(session.nextLyric()),
          icon: const Icon(Icons.lyrics),
          label: const Text('下一句'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(session.skipForward()),
          icon: const Icon(Icons.forward_30),
          label: const Text('快进30s'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(session.nextTrack()),
          icon: const Icon(Icons.skip_next),
          label: const Text('换一首'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(session.stop()),
          icon: const Icon(Icons.stop),
          label: const Text('结束'),
        ),
      ],
    );
  }
}

/// What the lock screen sent back through the bridge.
class _CommandLogCard extends StatelessWidget {
  const _CommandLogCard({required this.session});

  final DemoPlaybackSession session;

  @override
  Widget build(BuildContext context) {
    final commands = session.commands.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('锁屏指令回传', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            if (commands.isEmpty)
              const Text('在锁屏 / 灵动岛上按播放、暂停、拖动进度，指令会出现在这里'),
            for (final line in commands)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
