import 'dart:async';

import 'package:media_core/media_core.dart';
import 'package:media_core_audio/src/lyric/lyric_document.dart';
import 'package:media_core_audio/src/lyric/lyric_loader.dart';
import 'package:media_core_audio/src/player/audio_playback_config.dart';
import 'package:media_core_audio/src/player/audio_playback_state.dart';
import 'package:media_core_audio/src/queue/play_mode.dart';
import 'package:media_core_audio/src/queue/play_queue.dart';
import 'package:media_core_audio/src/source/music_source_registry.dart';
import 'package:media_core_audio/src/track/music_quality.dart';
import 'package:media_core_audio/src/track/music_track.dart';
import 'package:media_core_audio/src/track/track_source.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.audio);

/// decides how that looks.
final class AudioPlaybackController {
  /// Creates a controller.
  AudioPlaybackController(
    PlayerKernel kernel, {
    PlayQueue? queue,
    MusicSourceRegistry? registry,
    LyricLoader? lyrics,
    AudioPlaybackConfig config = const AudioPlaybackConfig(),
    PlayerConfig? playerConfig,
  }) : this._(
         kernel,
         queue: queue,
         registry: registry ?? MusicSourceRegistry(),
         lyrics: lyrics,
         config: config,
         playerConfig: playerConfig,
       );

  AudioPlaybackController._(
    this._kernel, {
    required MusicSourceRegistry registry,
    required this.config,
    PlayQueue? queue,
    LyricLoader? lyrics,
    PlayerConfig? playerConfig,
  }) : _quality = config.initialQuality,
       _playerConfig = playerConfig,
       _registry = registry,
       queue = queue ?? PlayQueue(),
       // One registry backs both resolution and lyrics: constructing the
       // loader from the raw (possibly null) parameter left it on its own
       // registry, and sources a host registered later never served lyrics.
       lyrics = lyrics ?? LyricLoader(registry: registry);

  /// Tuning.
  final AudioPlaybackConfig config;

  /// The play list.
  final PlayQueue queue;

  /// Lyric loading/caching, shared with any desktop-lyric overlay.
  final LyricLoader lyrics;

  final PlayerKernel _kernel;
  final MusicSourceRegistry _registry;

  /// How the player this controller opens should treat the app going to the
  /// background, or null to take the kernel's answer.
  ///
  /// This is the music module's side of one mechanism: the kernel observes the
  /// app and deactivates what is playing, and a narration or podcast player says
  /// here that it is the exception. A host that would rather not think per player
  /// passes `KernelOptions(pauseWhenBackgrounded: false)` instead.
  final PlayerConfig? _playerConfig;

  final StreamController<AudioPlaybackState> _states = StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _state = AudioPlaybackState.idle;
  PlayerHandle? _handle;
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;
  StreamSubscription<PlayerTransportState>? _playbackSub;

  /// Resolutions cached by track key; value carries its own expiry.
  final Map<String, TrackSource> _resolved = <String, TrackSource>{};

  /// Tracks whose source has already been refreshed once.
  final Set<String> _refreshed = <String>{};

  /// Tracks whose playback URL must not be reused (they failed once).
  final Set<String> _failed = <String>{};

  Timer? _loadTimer;

  MusicQuality _quality;
  Duration _lyricOffset = Duration.zero;
  final Map<String, LyricDocument> _lyricOverrides = <String, LyricDocument>{};
  int _lyricRevision = 0;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndsAt;
  bool _pauseAfterCurrentTrack = false;
  bool _disposed = false;
  int _operation = 0;

  /// Playback state stream; replays nothing, so seed from [state].
  Stream<AudioPlaybackState> get stateStream => _states.stream;

  /// Loudness levels from an analysis filter in the audio chain, in
  /// LUFS (EBU R128 momentary and short-term).
  ///
  /// Events arrive only while the chain itself carries a probe; a
  /// quiet stream means "no meter installed", never silence.
  Stream<AudioLoudness> get loudnessStream => _loudness.stream;

  final StreamController<AudioLoudness> _loudness = StreamController<AudioLoudness>.broadcast();

  /// Latest state snapshot.
  AudioPlaybackState get state => _state;

  /// The registered music sources.
  MusicSourceRegistry get registry => _registry;

  /// The engine handle, once a track has been played.
  PlayerHandle? get handle => _handle;

  /// Requested quality tier.
  MusicQuality get quality => _quality;

  /// Viewer-adjusted lyric delay; positive values delay the highlight.
  Duration get lyricOffset => _lyricOffset;

  /// When the sleep timer will pause playback, or null when none is armed.
  DateTime? get sleepTimerEndsAt => _sleepTimerEndsAt;

  /// Time left on the sleep timer, or null when none is armed.
  Duration? get sleepTimerRemaining {
    final endsAt = _sleepTimerEndsAt;

    if (endsAt == null) {
      return null;
    }

    final left = endsAt.difference(DateTime.now());

    return left.isNegative ? Duration.zero : left;
  }

  /// Whether playback pauses when the current track ends.
  bool get pauseAfterCurrentTrack => _pauseAfterCurrentTrack;

  // ---------------------------------------------------------------------------
  // Queue and track selection
  // ---------------------------------------------------------------------------

  /// Replaces the queue and starts at [startIndex].
  Future<void> setQueue(Iterable<MusicTrack> tracks, {int startIndex = 0, bool autoPlay = true}) async {
    queue.setTracks(tracks, startIndex: startIndex);
    _publish(queueLength: queue.length, index: queue.index, ended: false, mode: queue.mode);

    if (!autoPlay || queue.current == null) {
      if (!autoPlay) {
        // The engine would keep playing the replaced queue's track while the
        // published state already names the new current one.
        await stop();
      }
      _publish(track: queue.current, clearTrack: queue.current == null);

      return;
    }

    await playAt(queue.index);
  }

  /// Plays [track], adding it to the queue when it is not there yet.
  ///
  /// [insertNext] makes it the next entry instead of appending (lx-music's
  /// "下一首播放").
  Future<void> playTrack(MusicTrack track, {MusicQuality? quality, bool insertNext = false}) async {
    final existing = queue.indexOfTrack(track);

    if (existing >= 0) {
      await playAt(existing);

      return;
    }

    if (queue.isEmpty) {
      queue.setTracks(<MusicTrack>[track]);

      await playAt(0);

      return;
    }

    final index = insertNext ? queue.insertNext(track) : queue.append(track);

    _publish(queueLength: queue.length);

    await playAt(index);
  }

  /// Plays the queue entry at [index].
  ///
  /// [resetRetry] clears the track's "already refreshed once" budget. It must
  /// stay true for anything the user asked for (a tap, next/previous, a queue
  /// edit) and false for the controller's own re-entries — the error handler
  /// and the load timeout both call back into here, and clearing the budget on
  /// those paths is exactly how a broken track turns into an endless
  /// resolve/retry loop.
  Future<void> playAt(int index, {bool resetRetry = true}) async {
    if (index < 0 || index >= queue.length || _disposed) {
      return;
    }

    queue.jumpTo(index);

    final track = queue.current;

    if (track == null) {
      return;
    }

    final operation = ++_operation;

    _publish(
      track: track,
      index: index,
      queueLength: queue.length,
      loading: true,
      clearError: true,
      ended: false,
      position: Duration.zero,
      duration: track.duration ?? Duration.zero,
    );

    final handle = await _ensureHandle();

    if (handle == null || _disposed || operation != _operation) {
      return;
    }

    if (resetRetry) {
      // A new track is a new error story: the previous one's retry budget must
      // not carry over and silently skip the refresh.
      _refreshed.remove(_keyOf(track));
    }

    try {
      await _openTrack(handle, track, quality: _quality, operation: operation);
    } on Object catch (error) {
      await _fail(track, error, operation: operation);
    }
  }

  /// Advances the queue.
  ///
  /// [automatic] is the "track ended" case, which is the only one single-loop
  /// repeats and the only one that stops at the end of a [PlayMode.list] queue.
  Future<void> next({bool automatic = false}) async {
    final target = queue.indexAfter(automatic: automatic);

    if (target == null) {
      await _stopAtEnd();

      return;
    }

    await playAt(target);
  }

  /// Goes back: restarts the current track, or moves to the previous entry.
  Future<void> previous() async {
    if (_state.position > config.restartThreshold) {
      await seek(Duration.zero);

      return;
    }

    final target = queue.indexBefore();

    if (target == null) {
      await seek(Duration.zero);

      return;
    }

    await playAt(target);
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  /// Resumes playback of the current track.
  Future<void> play() async {
    final handle = _handle;

    if (handle == null) {
      await playAt(queue.index >= 0 ? queue.index : 0);

      return;
    }

    await handle.play();
    _publish(playing: true, ended: false);
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _handle?.pause();
    _log.debug('pause');
    _publish(playing: false);
  }

  /// Toggles play/pause.
  Future<void> toggle() => _state.playing ? pause() : play();

  /// Seeks within the current track.
  Future<void> seek(Duration position) async {
    await _handle?.seek(position);
    _log.debug('seek', fields: <String, Object?>{'positionMs': position.inMilliseconds});
    _publish(position: position);
  }

  /// Sets output volume (0.0–1.0).
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);

    await _handle?.setVolume(clamped);
    _publish(volume: clamped, muted: clamped == 0);
  }

  /// Sets the playback rate.
  Future<void> setRate(double rate) async {
    await _handle?.setRate(rate);
    _publish(rate: rate);
  }

  /// Mutes or unmutes output.
  Future<void> setMute({required bool muted}) async {
    await _handle?.setMute(muted: muted);
    _publish(muted: muted);
  }

  /// Changes the play mode.
  void setPlayMode(PlayMode mode) {
    queue.setMode(mode);
    _publish(mode: mode);
  }

  /// Changes the requested quality.
  ///
  /// Takes effect on the next resolution: re-resolving the current track would
  /// restart it, and a quality switch is expected to be audible on the *next*
  /// track, not to interrupt this one.
  void setQuality(MusicQuality quality) {
    _quality = quality;
    _publish();
  }

  /// Arms or clears the sleep timer.
  ///
  /// A positive [duration] pauses playback when it elapses; null or a
  /// non-positive duration clears the timer. This is the logic half of
  /// lx-music's 定时停止 — the host renders the remaining time from
  /// [sleepTimerEndsAt] and does not need its own countdown.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    // A time-based timer and "after this track" are one choice, so arming or
    // clearing either clears the other.
    _pauseAfterCurrentTrack = false;

    if (duration == null || duration <= Duration.zero) {
      _sleepTimerEndsAt = null;
      _publish(clearSleepTimer: true, pauseAfterCurrentTrack: false);

      return;
    }

    final endsAt = DateTime.now().add(duration);

    _sleepTimerEndsAt = endsAt;
    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      _sleepTimerEndsAt = null;

      // Pausing is the point of the timer; publishing afterwards keeps the
      // UI's "timer armed" indicator and the actual transport in step.
      unawaited(pause());
      _publish(clearSleepTimer: true);
    });

    _publish(sleepTimerEndsAt: endsAt, pauseAfterCurrentTrack: false);
  }

  /// Arms or clears the reference's 定时停止「播完当前歌曲」.
  ///
  /// It is a one-shot: the flag is spent when the current track ends, and
  /// enabling it replaces a pending time-based timer because the reference
  /// offers the two as one choice.
  void setPauseAfterCurrentTrack({required bool enabled}) {
    _pauseAfterCurrentTrack = enabled;

    if (enabled) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerEndsAt = null;
    }

    _publish(pauseAfterCurrentTrack: enabled, clearSleepTimer: enabled);
  }

  // ---------------------------------------------------------------------------
  // Queue editing
  // ---------------------------------------------------------------------------

  /// Adds [track] to the queue.
  Future<void> enqueue(MusicTrack track, {bool next = false}) async {
    if (queue.isEmpty) {
      queue.append(track);
      _publish(queueLength: queue.length, index: queue.index);

      return;
    }

    if (next) {
      queue.insertNext(track);
    } else {
      queue.append(track);
    }

    _publish(queueLength: queue.length);
  }

  /// Adds [tracks] after the current one, in order.
  Future<void> enqueueAll(Iterable<MusicTrack> tracks, {bool next = false}) async {
    var insertAt = next ? queue.index + 1 : queue.length;

    for (final track in tracks) {
      queue.insertAt(insertAt++, track);
    }

    _publish(queueLength: queue.length);
  }

  /// Removes a queue entry, keeping playback coherent.
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= queue.length) {
      return;
    }

    final wasCurrent = index == queue.index;

    queue.removeAt(index);

    if (queue.isEmpty) {
      await stop();
      _publish(clearTrack: true, index: -1, queueLength: 0);

      return;
    }

    _publish(queueLength: queue.length, index: queue.index);

    if (wasCurrent) {
      // Removing the playing track advances to whatever took its place —
      // matching what the standard players do, and what a user pressing the
      // delete key on the current row expects.
      await playAt(queue.index.clamp(0, queue.length - 1));
    }
  }

  /// Empties the queue and stops playback.
  Future<void> clearQueue() async {
    queue.clear();
    await stop();
    _publish(clearTrack: true, index: -1, queueLength: 0, playing: false);
  }

  /// Stops playback, keeping the queue.
  Future<void> stop() async {
    // An open that is still resolving must not land afterwards: bumping the
    // operation fails its guard, and an armed load timer would otherwise
    // restart audio through playAt once the current resolve gives up.
    _operation++;
    _clearLoadTimeout();
    // Stopping is the viewer ending the session, so a pending "after this
    // track" must not fire into it.
    _pauseAfterCurrentTrack = false;
    await _handle?.stop();
    _publish(playing: false, position: Duration.zero, pauseAfterCurrentTrack: false);
  }

  // ---------------------------------------------------------------------------
  // Lyrics
  // ---------------------------------------------------------------------------

  /// Loads the lyric for the current track, with [lyricOffset] applied.
  ///
  /// The parsed document is cached without the offset, so moving the slider
  /// and reloading never refetches; [force] still bypasses the cache for a
  /// user-requested refresh. A host-supplied lyric (see [setLyricOverride])
  /// wins over both.
  Future<LyricDocument> loadCurrentLyric({bool force = false}) async {
    final track = queue.current;

    if (track == null) {
      return LyricDocument.empty;
    }

    final override = _lyricOverrides[_keyOf(track)];
    final document = override ?? await lyrics.load(track, force: force);

    return document.withOffset(_lyricOffset);
  }

  /// The lyric a host supplied for [track], when one is set.
  LyricDocument? lyricOverrideFor(MusicTrack track) => _lyricOverrides[_keyOf(track)];

  /// Replaces [track]'s lyric with [document], or removes the override when
  /// null — the reference's 关联歌词, where the viewer points a song at a
  /// lyric file instead of the source's guess.
  ///
  /// [AudioPlaybackState.lyricRevision] moves so a lyric view reloads even
  /// though the track itself did not change.
  void setLyricOverride(MusicTrack track, LyricDocument? document) {
    final key = _keyOf(track);

    if (document == null) {
      if (_lyricOverrides.remove(key) == null) {
        return;
      }
    } else {
      _lyricOverrides[key] = document;
    }

    _lyricRevision++;
    _publish(lyricRevision: _lyricRevision);
  }

  /// Sets the viewer's lyric delay.
  ///
  /// Positive values delay the highlight; the change is published so an
  /// in-app lyric view and the desktop overlay move together.
  void setLyricOffset(Duration offset) {
    if (_lyricOffset == offset) {
      return;
    }

    _lyricOffset = offset;
    _publish(lyricOffset: offset);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Creates and binds the engine handle on first use.
  Future<PlayerHandle?> _ensureHandle() {
    final existing = _handle;

    if (existing != null && !existing.disposed) {
      return Future<PlayerHandle?>.value(existing);
    }

    // Memoized: two rapid playAt calls both seeing no handle must share one
    // creation, or the second bind overwrites - and orphans - the first
    // engine player for the rest of the session.
    return _creating ??= _createHandle().whenComplete(() => _creating = null);
  }

  Future<PlayerHandle?>? _creating;

  Future<PlayerHandle?> _createHandle() async {
    try {
      final handle = _playerConfig == null ? await _kernel.create() : await _kernel.create(config: _playerConfig);

      if (_disposed) {
        await _kernel.release(handle.id);

        return null;
      }

      _bind(handle);

      return handle;
    } on Object catch (error) {
      _publish(loading: false, error: 'PlayerIdentity creation failed: $error');

      return null;
    }
  }

  void _bind(PlayerHandle handle) {
    _handle = handle;

    unawaited(_adapterSub?.cancel());
    _adapterSub = handle.adapterEvents.listen(_onAdapterEvent, onError: (Object _) {});

    unawaited(_playbackSub?.cancel());
    _playbackSub = handle.playbackStream.listen(_onPlaybackState, onError: (Object _) {});
  }

  /// Resolves a fresh URL (unless a live cache entry is usable) and opens it.
  Future<void> _openTrack(
    PlayerHandle handle,
    MusicTrack track, {
    required MusicQuality quality,
    required int operation,
  }) async {
    final trackKey = _keyOf(track);
    // The cache key carries the requested quality: an entry resolved at one
    // tier must not be served for another, or setQuality is silently ignored
    // on every replay or prefetched advance.
    final resolvedKey = _resolvedKey(track, quality);
    final cached = _resolved[resolvedKey];

    final TrackSource source;

    if (cached != null && !cached.isExpired() && !_failed.contains(trackKey)) {
      source = cached;
    } else {
      // Local files never expire and never fail to resolve, so they are not
      // cached: a re-resolve is a stat, and caching would hide a file the user
      // just edited or replaced.
      source = await _registry.resolveTrackSource(track, quality: quality);

      if (!track.isLocal) {
        // The other tiers' entries for this track are stale the moment a
        // fresh resolution exists; dropping them keeps the cache bounded by
        // the queue rather than by quality switches.
        _resolved.removeWhere((key, _) => key.startsWith('$trackKey\u0000'));
        _resolved[resolvedKey] = source;
      }

      _failed.remove(trackKey);
    }

    if (_disposed || operation != _operation) {
      return;
    }

    _armLoadTimeout(track, operation);

    await handle.open(
      source.toPlayerSource(trackId: track.id, title: track.displayName),
      // Explicit: a music player starts the song it was asked to play. The
      // handle's config default exists for VOD callers who open-then-decide.
      autoPlay: true,
    );

    _publish(quality: source.quality, duration: source.duration ?? track.duration ?? Duration.zero);

    _log.info(
      'track opened',
      fields: <String, Object?>{'track': track.displayName, 'index': queue.index, 'quality': source.quality?.id},
    );
  }

  void _onAdapterEvent(PlayerAdapterEvent event) {
    switch (event) {
      case PlayerAdapterPlaying():
        _clearLoadTimeout();

        // Playback started, so the track's retry budget is whole again: a
        // later stall in the same track deserves its one refresh.
        final playing = queue.current;

        if (playing != null) {
          _refreshed.remove(_keyOf(playing));
        }
        _publish(playing: true, loading: false, buffering: false, clearError: true);
        unawaited(_prefetchNext());

        final current = queue.current;

        if (current != null) {
          unawaited(lyrics.prefetch(current));
        }

      case PlayerAdapterPaused():
        _publish(playing: false);

      case PlayerAdapterBuffering(:final buffering):
        _publish(buffering: buffering, loading: buffering && !_state.playing);

      case PlayerAdapterCompleted():
        if (_pauseAfterCurrentTrack) {
          // Spent: the next completed track advances as usual. Pausing in
          // place keeps the finished song on screen instead of jumping to the
          // next one, which is what "stop after this song" promises.
          _pauseAfterCurrentTrack = false;
          unawaited(pause());
          _publish(pauseAfterCurrentTrack: false);
        } else {
          unawaited(next(automatic: true));
        }

      case PlayerAdapterStopped():
        _publish(playing: false);

      case PlayerAdapterErrorEvent(:final message):
        unawaited(_onAdapterError(message));

      case PlayerAdapterLoudnessChanged(:final momentary, :final shortTerm):
        if (!_loudness.isClosed) {
          _loudness.add(AudioLoudness(momentary: momentary, shortTerm: shortTerm));
        }

      case PlayerAdapterPositionChanged():
      case PlayerAdapterDurationChanged():
      case PlayerAdapterVolumeChanged():
      case PlayerAdapterRateChanged():
      case PlayerAdapterOpened():
      case PlayerAdapterVideoSizeChanged():
      case PlayerAdapterVideoFrameProgress():
      case PlayerAdapterVideoReconfigured():
      case PlayerAdapterHwdecChanged():
      case PlayerAdapterAudioReconfigured():
      case PlayerAdapterAudioDeviceChanged():
      case PlayerAdapterSubtitleChanged():
      case PlayerAdapterCacheChanged():
      case PlayerAdapterMetadataChanged():
      case PlayerAdapterPlaylistChanged():
      case PlayerAdapterClientMessage():
      case PlayerAdapterLogMessage():
        break;
    }
  }

  void _onPlaybackState(PlayerTransportState playback) {
    _publish(
      playing: playback.isPlaying,
      position: playback.position,
      duration: playback.duration > Duration.zero ? playback.duration : _state.duration,
    );
  }

  /// Handles an engine error: refresh once, then surface it.
  Future<void> _onAdapterError(String message) async {
    final track = queue.current;

    if (track == null) {
      return;
    }

    final key = _keyOf(track);

    if (config.refreshSourceOnError && !_refreshed.contains(key)) {
      _refreshed.add(key);
      _dropResolved(track);

      await playAt(queue.index, resetRetry: false);

      return;
    }

    await _fail(track, message, operation: _operation);
  }

  /// Records a failure for [track] and stops trying.
  ///
  /// A failed entry is poisoned for the rest of the session: its cached URL is
  /// dropped so a later attempt resolves fresh, but it is not re-resolved
  /// automatically — a broken track must not turn into an infinite retry loop
  /// while the queue moves past it.
  Future<void> _fail(MusicTrack track, Object error, {required int operation}) async {
    if (_disposed || operation != _operation) {
      return;
    }

    _clearLoadTimeout();
    _failed.add(_keyOf(track));
    _dropResolved(track);

    _publish(loading: false, playing: false, buffering: false, error: error.toString());

    MediaCoreLog.warning(
      LogCategory.error,
      'music track failed: ${track.displayName}',
      error: error,
      fields: <String, Object?>{'source': track.sourceId, 'id': track.id},
    );
  }

  /// Arms the "did it ever start" deadline for the current open.
  void _armLoadTimeout(MusicTrack track, int operation) {
    _clearLoadTimeout();

    if (config.loadTimeout <= Duration.zero) {
      return;
    }

    _loadTimer = Timer(config.loadTimeout, () {
      if (_disposed || operation != _operation) {
        return;
      }

      final key = _keyOf(track);
      final alreadyRefreshed = _refreshed.contains(key);

      // First timeout: the URL is the prime suspect (signed links expire, CDN
      // nodes go cold). Re-resolve once; a second timeout is a real failure.
      if (config.refreshSourceOnError && !alreadyRefreshed) {
        _refreshed.add(key);
        _dropResolved(track);

        unawaited(playAt(queue.index, resetRetry: false));

        return;
      }

      unawaited(_fail(track, 'Playback did not start within ${config.loadTimeout.inSeconds}s', operation: operation));
    });
  }

  void _clearLoadTimeout() {
    _loadTimer?.cancel();
    _loadTimer = null;
  }

  /// Warms the next entry's URL and lyric.
  Future<void> _prefetchNext() async {
    if (!config.prefetchNext) {
      return;
    }

    final target = queue.indexAfter(automatic: true);

    if (target == null || target == queue.index) {
      return;
    }

    final nextTrack = target >= 0 && target < queue.length ? queue.tracks[target] : null;

    if (nextTrack == null) {
      return;
    }

    final key = _resolvedKey(nextTrack, _quality);

    if (_resolved[key] == null || _resolved[key]!.isExpired()) {
      try {
        _resolved[key] = await _registry.resolveTrackSource(nextTrack, quality: _quality);
      } on Object catch (error) {
        // Prefetch is best-effort; the real attempt reports the failure.
        _log.debug('prefetch resolve failed', fields: <String, Object?>{'error': error.toString()});
      }
    }

    await lyrics.prefetch(nextTrack);
  }

  /// Stops at the end of a non-looping queue.
  Future<void> _stopAtEnd() async {
    await _handle?.stop();
    _publish(playing: false, ended: true, position: _state.duration);
  }

  String _keyOf(MusicTrack track) => '${track.sourceId}\u0000${track.id}';

  String _resolvedKey(MusicTrack track, MusicQuality quality) => '${_keyOf(track)}\u0000${quality.id}';

  void _dropResolved(MusicTrack track) {
    final prefix = '${_keyOf(track)}\u0000';
    _resolved.removeWhere((key, _) => key.startsWith(prefix));
  }

  void _publish({
    MusicTrack? track,
    bool clearTrack = false,
    int? index,
    int? queueLength,
    PlayMode? mode,
    bool? playing,
    bool? buffering,
    bool? loading,
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    bool? muted,
    MusicQuality? quality,
    String? error,
    bool clearError = false,
    bool? ended,
    Duration? lyricOffset,
    int? lyricRevision,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    bool? pauseAfterCurrentTrack,
  }) {
    if (_disposed) {
      return;
    }

    final next = _state.copyWith(
      track: track,
      clearTrack: clearTrack,
      index: index,
      queueLength: queueLength,
      mode: mode,
      playing: playing,
      buffering: buffering,
      loading: loading,
      position: position,
      duration: duration,
      volume: volume,
      rate: rate,
      muted: muted,
      quality: quality,
      error: error,
      clearError: clearError,
      ended: ended,
      lyricOffset: lyricOffset,
      lyricRevision: lyricRevision,
      sleepTimerEndsAt: sleepTimerEndsAt,
      clearSleepTimer: clearSleepTimer,
      pauseAfterCurrentTrack: pauseAfterCurrentTrack,
    );

    if (next == _state) {
      return;
    }

    _state = next;

    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  /// Releases the engine handle and stops publishing.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _operation++;
    _clearLoadTimeout();
    _sleepTimer?.cancel();
    _sleepTimer = null;

    await _adapterSub?.cancel();
    _adapterSub = null;
    await _playbackSub?.cancel();
    _playbackSub = null;

    final handle = _handle;
    _handle = null;

    if (handle != null) {
      try {
        await _kernel.release(handle.id);
      } on Object catch (_) {
        // Releasing an engine that is already gone is not an error here.
      }
    }

    await _states.close();
    await _loudness.close();
  }
}
