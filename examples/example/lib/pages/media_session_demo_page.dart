import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

import '../ui/demo_log.dart';
import '../ui/demo_page_scaffold.dart';
import 'player_demo_page.dart' show kSampleSources;

/// A video player with a system media surface.
///
/// The notification, the lock screen, SMTC and MPRIS are one capability, and it
/// is not an audio feature: this page plays a *video* and publishes it to the
/// platform. Look at your device's notification shade (or Windows' volume
/// overlay, or GNOME's media applet) while it plays: the title, the progress and
/// the controls come from the handle through `MediaSessionDriver`, and pressing
/// them drives the same handle — which the log below shows as it happens.
///
/// Android needs the `audio_service` manifest entries and, on API 33+, the
/// notification permission; the package README lists them. On a platform where
/// the surface cannot appear, the driver still publishes state, so this page
/// remains a truthful demonstration of what the host would see.
class MediaSessionDemoPage extends StatefulWidget {
  /// Creates the page.
  const MediaSessionDemoPage({super.key});

  @override
  State<MediaSessionDemoPage> createState() => _MediaSessionDemoPageState();
}

final class _MediaSessionDemoPageState extends State<MediaSessionDemoPage> {
  final DemoLog _log = DemoLog();
  final TextEditingController _url = TextEditingController(text: kSampleSources.first.url);

  late final PlayerKernel _kernel;
  late final MediaSessionDriver _session;

  PlayerHandle? _handle;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<void>? _surfaceSub;
  StreamSubscription<void>? _itemSub;

  bool _attached = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();

    _kernel = PlayerKernel();
    _kernel.registerBackend(const MediaKitAdapterFactory().registration());

    // A video player has no queue: seek buttons instead of skip buttons, and
    // its own notification channel so a user can mute "video playback" without
    // muting music.
    _session = MediaSessionDriver(config: const MediaSessionConfig.video());

    _log.add('driver created: channel "${const MediaSessionConfig.video().androidNotificationChannelId}"');
    _log.add('attach it and the platform gets play/pause, ±'
        '${const MediaSessionConfig.video().seekStep.inSeconds}s and stop');
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _surfaceSub?.cancel();
    _itemSub?.cancel();

    _session.dispose();
    _handle?.dispose();
    _kernel.dispose();
    _url.dispose();
    _log.dispose();

    super.dispose();
  }

  /// Starts the platform surface and binds the kernel to it.
  Future<void> _attach() async {
    if (_attached || _initializing) {
      return;
    }

    setState(() => _initializing = true);

    try {
      await _session.initialize();

      // The kernel hands over whichever player becomes active; a handle that
      // was already playing is picked up by `refresh`.
      _kernel.attachAudio(_session);
      _session.refresh();

      _observeSurface();

      if (!mounted) {
        return;
      }

      setState(() {
        _attached = true;
        _initializing = false;
      });

      _log.add('attached: $_session');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _initializing = false);

      _log.add('initialize failed: $error');
    }
  }

  /// Logs what the platform is being told.
  ///
  /// Two streams, deliberately not one: the media item changes when a source
  /// opens, while the playback state arrives with every progress tick — logging
  /// all of it would bury the log. So the state is logged on *transitions*
  /// (playing flag, control set) plus position jumps, which is also exactly
  /// where a pressed notification button shows up: the platform sends the
  /// command, the handle acts, and the change comes back here.
  void _observeSurface() {
    final handler = _session.handler;

    if (handler == null) {
      return;
    }

    _itemSub = handler.mediaItem.listen((item) {
      _log.add('surface ← item: ${item?.title ?? '(cleared)'}  art=${item?.artUri?.pathSegments.last ?? 'none'}');
    });

    String lastSignature = '';
    Duration lastPosition = Duration.zero;

    _surfaceSub = handler.playbackState.listen((state) {
      final signature = '${state.playing}|${state.controls.length}|${state.processingState.name}';

      if (signature != lastSignature) {
        lastSignature = signature;

        _log.add('surface ← state: ${state.playing ? 'playing' : 'paused'}, '
            '${state.controls.length} controls, ${state.processingState.name}');

        lastPosition = state.updatePosition;

        return;
      }

      // A jump bigger than a progress tick means the position was moved —
      // by the ±10s buttons as much as by the UI.
      final delta = (state.updatePosition - lastPosition).abs();

      if (delta > const Duration(milliseconds: 1500)) {
        _log.add('surface ← seek: ${lastPosition.inSeconds}s → ${state.updatePosition.inSeconds}s');

        lastPosition = state.updatePosition;
      }
    });
  }

  Future<void> _detach() async {
    if (!_attached) {
      return;
    }

    _kernel.detachAudio();

    await _playbackSub?.cancel();
    _playbackSub = null;

    await _surfaceSub?.cancel();
    _surfaceSub = null;

    _log.add('detached (the surface keeps the last state until the app is closed)');

    setState(() => _attached = false);
  }

  Future<void> _open() async {
    final previous = _handle;

    if (previous != null) {
      _playbackSub?.cancel();
      await previous.dispose();
    }

    final url = _url.text.trim();
    final source = PlayerSource(
      id: SourceId.generate(),
      uri: Uri.parse(url),
      title: url.split('/').last,
    );

    final handle = await _kernel.create(source: source, config: const PlayerConfig(autoPlay: true));

    if (!mounted) {
      await handle.dispose();

      return;
    }

    setState(() => _handle = handle);

    _playbackSub = handle.stateChanges.listen((state) {
      if (mounted && state.isPlaying) {
        setState(() {});
      }
    });

    _log.add('opened ${handle.id.value} (backend ${handle.backendId})');
    _log.add('active player for the surface: ${_session.active?.id.value ?? 'none'}');
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;

    return DemoPageScaffold(
      title: '系统媒体面：通知 / 锁屏 / SMTC',
      subtitle: '视频播放器同样该有系统媒体控件：标题、进度、播放暂停、±10 秒、停止。接入后播一会儿，'
          '再看设备的通知栏（Windows 的音量浮层、GNOME 的媒体部件也行）——按上面的按钮，下面的日志会出现对应的状态变化。'
          ' · The same system surface a music app gets, for a video player: attach it, play, then press the '
          "notification's buttons and watch the transitions land in the log below.",
      log: _log,
      actions: <Widget>[
        FilledButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('打开并播放'),
        ),
        OutlinedButton.icon(
          onPressed: _attached ? _detach : (_initializing ? null : _attach),
          icon: Icon(_attached ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
          label: Text(_attached ? '解除媒体面' : '接入媒体面'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: handle == null
                  ? const Center(child: Text('打开一个地址后出现画面', style: TextStyle(color: Colors.white70)))
                  : MediaPlayerView(handle: handle),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _row('driver', _session.toString()),
                  _row('platform surface', _attached ? 'attached' : 'not attached'),
                  _row('active player', _session.active?.id.value ?? 'none'),
                  _row('controls offered', _attached ? 'play/pause · ±10s · stop' : '—'),
                  _row('title shown', handle?.source?.hasTitle == true ? handle!.source!.title! : '—'),
                  _row(
                    'artwork',
                    _session.artUriResolver == null ? 'source metadata only' : 'resolver installed',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: '视频地址 / URL',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final sample in kSampleSources)
                ActionChip(
                  label: Text(sample.label),
                  onPressed: () => setState(() => _url.text = sample.url),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
