import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_core_media_activity/media_core_media_activity.dart';

/// One demo track: title, artist and its lyric lines.
class DemoTrack {
  /// Creates a demo track.
  const DemoTrack({required this.title, required this.artist, required this.lyrics});

  /// Song title.
  final String title;

  /// Artist name.
  final String artist;

  /// Lyric lines, in order; the demo walks them line by line.
  final List<String> lyrics;
}

/// A simulated playback session that drives the media activity exactly the
/// way a real host would (spec §8): typed events only — track changes, lyric
/// boundaries, play/pause flips, seeks — never progress ticks.
///
/// The lyric `Timer` below belongs to the *simulated lyric engine*, the thing
/// that detects boundaries in a real app. It is deliberately NOT pushing
/// position into the activity every tick: between updates the lock screen
/// advances its own clock by `rate × Δt`, which is the whole point of the
/// event-driven sync policy (spec §8.1, §8.4).
///
/// The class also plays the host's other role: remote commands from the lock
/// screen route back here through [MediaActivityController.commandSink] and
/// flip the same state the UI buttons flip (spec §11.2, §20.1.7).
class DemoPlaybackSession implements MediaActivityCommandSink {
  /// Creates the session over [platform], defaulting to the runtime's own
  /// resolution (the iOS bridge on iOS, the no-op everywhere else).
  DemoPlaybackSession({MediaActivityPlatform? platform})
    : _platform = platform ?? PlatformMediaActivity.resolve() {
    _controller = MediaActivityController(platform: _platform);
    _coordinator = MediaActivityCoordinator(controller: _controller, playerId: 'demo');
    _controller.commandSink = this;

    // Capability is a one-shot question (spec §13.2); ask it now so the UI
    // can explain why the feature is off instead of silently doing nothing.
    unawaited(
      _controller.capabilities().then((report) {
        usable = report.usable;
        capabilityText = report.usable
            ? 'Live Activities 可用（iOS ${report.systemMajorVersion}）'
            : '当前设备不支持 Live Activities，功能保持关闭';
        _notify();
      }),
    );
  }

  final MediaActivityPlatform _platform;

  late final MediaActivityController _controller;
  late final MediaActivityCoordinator _coordinator;

  /// The two demo tracks; 换一首 walks between them.
  static const tracks = [
    DemoTrack(
      title: '夜航星',
      artist: 'demo',
      lyrics: ['夜色把站台淹没', '车灯划开了沉默', '你说星星在坠落', '落在谁的眼窝', '风穿过旧唱片的沟壑', '把我们唱成了歌'],
    ),
    DemoTrack(
      title: '南方车站',
      artist: 'demo',
      lyrics: ['站台亮着昏黄的光', '行李箱滚过地上', '列车带走了黄昏', '留下了南方', '我们在站台相望', '像两颗不说话的星'],
    ),
  ];

  /// How often the simulated lyric engine detects a boundary.
  static const lyricCadence = Duration(seconds: 4);

  /// Whether the capability probe answered green; false before it answers.
  bool usable = false;

  int _trackIndex = 0;
  int _lyricIndex = 0;
  bool _isPlaying = false;
  int _positionMs = 0;
  int _sessionSeq = 0;
  bool _disposed = false;

  /// The simulated lyric engine. Runs only while playing; a paused session
  /// stops producing events (spec §9.4).
  Timer? _lyricTimer;

  /// What the capability probe answered; shown before anything plays.
  String capabilityText = '正在探测 Live Activities 能力…';

  /// Lock-screen commands that came back through the bridge, newest last.
  final ValueNotifier<List<String>> commandLog = ValueNotifier<List<String>>([]);

  /// Whether playback is advancing right now.
  bool get isPlaying => _isPlaying;

  /// Title of the demo track currently loaded.
  String get trackTitle => DemoPlaybackSession.tracks[_trackIndex].title;

  /// Artist of the demo track currently loaded.
  String get trackArtist => DemoPlaybackSession.tracks[_trackIndex].artist;

  /// The lyric line the simulated engine considers on screen.
  String get currentLyric => DemoPlaybackSession.tracks[_trackIndex].lyrics[_lyricIndex];

  /// The demo's internal playback clock, in milliseconds.
  int get positionMs => _positionMs;

  /// Whether an activity is live right now (the controller's ledger).
  bool get hasActiveActivity => _controller.activeMetadata != null;

  /// Every lock-screen command that arrived so far, oldest first.
  List<String> get commands => List.unmodifiable(commandLog.value);

  /// Starts (or restarts) playback of the current track.
  Future<void> start() async {
    if (_disposed) {
      return;
    }

    _lyricIndex = 0;
    _positionMs = 0;
    _isPlaying = true;
    await _announceTrack();
    _startLyricEngine();
    _notify();
  }

  /// The simulated lyric engine: one boundary event per tick while playing.
  Future<void> nextLyric() async {
    if (_disposed || !_isPlaying) {
      return;
    }

    final lyrics = DemoPlaybackSession.tracks[_trackIndex].lyrics;
    _lyricIndex = (_lyricIndex + 1) % lyrics.length;
    _positionMs += lyricCadence.inMilliseconds;

    await _coordinator.onLyricChanged(
      currentLyric: currentLyric,
      nextLyric: lyrics[(_lyricIndex + 1) % lyrics.length],
    );
    _notify();
  }

  /// Pause / resume. A pause keeps the activity and only flips the play
  /// state (spec §9.4); the lyric engine stops.
  Future<void> toggle() async {
    if (_disposed || !hasActiveActivity) {
      return;
    }

    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _startLyricEngine();
    } else {
      _lyricTimer?.cancel();
    }

    await _coordinator.onPlaybackChanged(
      isPlaying: _isPlaying,
      positionMs: _positionMs,
      playbackRate: _isPlaying ? 1.0 : 0.0,
    );
    _notify();
  }

  /// A viewer seek; the lock-screen clock re-baselines (spec §8.7).
  Future<void> skipForward() async {
    if (_disposed || !hasActiveActivity) {
      return;
    }

    _positionMs += 30_000;
    await _coordinator.onSeekCompleted(positionMs: _positionMs);
    _notify();
  }

  /// A different track took over: a new session id replaces the activity
  /// (spec §7.2).
  Future<void> nextTrack() async {
    if (_disposed) {
      return;
    }

    _trackIndex = (_trackIndex + 1) % DemoPlaybackSession.tracks.length;
    _lyricIndex = 0;
    _positionMs = 0;
    _isPlaying = true;
    await _announceTrack();
    _startLyricEngine();
    _notify();
  }

  /// The viewer stopped the session: the activity ends and Now Playing
  /// clears (stop semantics, spec §9.4).
  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    _isPlaying = false;
    _lyricTimer?.cancel();
    await _coordinator.onSessionEnded();
    _notify();
  }

  /// Tears the session down for good (page dispose).
  Future<void> dispose() async {
    _lyricTimer?.cancel();
    _disposed = true;
    await _controller.dispose();
    _notify();
  }

  Future<void> _announceTrack() async {
    final track = DemoPlaybackSession.tracks[_trackIndex];
    final lyrics = track.lyrics;

    _sessionSeq += 1;
    await _coordinator.onTrackChanged(
      MediaActivityMetadata(
        sessionId: 'demo-track-$_sessionSeq',
        title: track.title,
        artist: track.artist,
      ),
      MediaActivityContentState(
        currentLyric: lyrics[0],
        nextLyric: lyrics.length > 1 ? lyrics[1] : '',
        isPlaying: true,
        positionMs: 0,
      ),
    );
  }

  void _startLyricEngine() {
    _lyricTimer?.cancel();
    _lyricTimer = Timer.periodic(lyricCadence, (_) {
      unawaited(nextLyric());
    });
  }

  void _log(String line) {
    final log = [...commandLog.value, line];
    commandLog.value = log.length > 12 ? log.sublist(log.length - 12) : log;
    _notify();
  }

  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  /// Lets the UI listen for any state change without pulling in a state
  /// package: a plain ChangeNotifier-lite surface.
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Removes a listener added with [addListener].
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  // -- MediaActivityCommandSink: lock-screen commands route here -------------

  @override
  void onPlay(String playerId) {
    _log('锁屏指令：播放');
    if (!_isPlaying) {
      unawaited(toggle());
    }
  }

  @override
  void onPause(String playerId) {
    _log('锁屏指令：暂停');
    if (_isPlaying) {
      unawaited(toggle());
    }
  }

  @override
  void onTogglePlayPause(String playerId) {
    _log('锁屏指令：切换播放/暂停');
    unawaited(toggle());
  }

  @override
  void onNextTrack(String playerId) {
    _log('锁屏指令：下一首');
    unawaited(nextTrack());
  }

  @override
  void onPreviousTrack(String playerId) {
    _log('锁屏指令：上一首（demo 未实现，仅记录）');
  }

  @override
  void onSeek(String playerId, int positionMs) {
    _log('锁屏指令：跳转 ${positionMs ~/ 1000}s');
    _positionMs = positionMs;
    unawaited(_coordinator.onSeekCompleted(positionMs: positionMs));
    _notify();
  }

  @override
  void onActivityDismissed(String sessionId) {
    _log('系统移除了 Live Activity（$sessionId）');
    _isPlaying = false;
    _lyricTimer?.cancel();
    _notify();
  }
}
