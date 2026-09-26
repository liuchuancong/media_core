import 'dart:async';

import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';

import 'multiview_cell.dart';
import 'multiview_config.dart';
import 'multiview_layout.dart';

/// Decision trail for the wall.
///
/// A wall is where "why is that camera black" gets asked, and the answer is
/// spread across four mechanisms: the budget, the stall watchdog, the playlist
/// and the focus. Each one records its decisions under `multiview`, so a wall
/// that dropped a cell, restarted one, or never opened one says which.
final LogModule _log = MediaCoreLog.of(LogCategory.multiview);

/// How much quality a cell wants, relative to the best available.
enum MultiviewQualityPreference {
  /// Best available: worth looking at.
  best,

  /// Middle of the ladder: recognisable without costing the most.
  balanced,

  /// Lowest available.
  ///
  /// What a non-focused wall cell should use: the viewer needs to see that
  /// something is happening in that room, not to read the scoreboard.
  lowest,
}

/// Resolves [source] at the quality [preference] asks for.
///
/// A callback rather than an implementation because only the host knows how to
/// ask its sites for another rendition. Without one the wall plays what it was
/// given and the quality policy is inert — which is stated rather than silently
/// pretended.
typedef MultiviewQualityResolver =
    Future<MultiviewCellSource> Function(MultiviewCellSource source, MultiviewQualityPreference preference);

/// Immutable view of the wall, for a host that renders from state.
final class MultiviewSnapshot {
  const MultiviewSnapshot({
    required this.cells,
    required this.layout,
    required this.focusedIndex,
    required this.audioIndex,
    required this.pressure,
    required this.budgetExceeded,
  });

  final List<MultiviewCell> cells;
  final MultiviewLayout layout;

  /// Cell the viewer is looking at.
  final int focusedIndex;

  /// Cell that is audible, or `null` when nothing is.
  final int? audioIndex;

  /// Latest resource pressure.
  final ResourcePressure pressure;

  /// Whether the wall is currently past its decode budget.
  final bool budgetExceeded;

  /// Cells that are playing.
  int get playingCount => cells.where((cell) => cell.isPlaying).length;

  /// Cells with a room assigned.
  int get assignedCount => cells.where((cell) => !cell.isEmpty).length;

  @override
  String toString() => 'MultiviewSnapshot(${layout.name}, $playingCount playing, focus $focusedIndex)';
}

/// Runs a wall of live cells.
///
/// Responsibilities:
///
/// - own one player per cell, taken from the core's player host and given back
///   when the cell is cleared
/// - keep exactly one cell audible, and one focused
/// - hold the wall inside the device's decode budget, shrinking it under
///   resource pressure
/// - restart cells that stop making progress, within a bounded budget
/// - rotate the focus on a patrol interval
///
/// It does not:
///
/// - render the grid (the host does, from [snapshot])
/// - resolve room sources or quality ladders (the host supplies sources and may
///   supply a [MultiviewQualityResolver])
/// - own the page, the PiP window or the small window: a cell hands its player
///   over through [handOverCell], and the target is the host's
///
/// ## Why the audio owner is not the same thing as the focus
///
/// The focused cell is the one being *looked* at; the audible one is the one
/// being *listened* to. A monitoring wall usually wants both on the same cell,
/// but a viewer who pinned the audio to one room while looking around the wall
/// is a real use, so they are separate settings with separate setters.
///
/// ## Why the budget is enforced here
///
/// Every cell is a decoder. A wall that ignores that does not show more streams,
/// it shows several broken ones and starves the one the viewer cares about. The
/// core reports pressure ([ResourcePressure]); this controller turns it into a
/// decision ([MultiviewBudgetPolicy]) and reports the result in [snapshot], so
/// the host can show *why* cells went quiet instead of leaving them looking
/// broken.
final class MultiviewController {
  MultiviewController({
    required PoolPlayerHost players,
    MultiviewConfig config = MultiviewConfig.defaults,
    this.qualityResolver,
    DateTime Function()? clock,
  }) : _players = players,
       _config = config,
       _clock = clock ?? DateTime.now {
    _cells = List<MultiviewCell>.generate(_config.layout.capacity, (index) => MultiviewCell(index: index));
    _startTicking();
  }

  final PoolPlayerHost _players;

  /// Resolves quality ladders, when the host can. See [MultiviewQualityResolver].
  final MultiviewQualityResolver? qualityResolver;

  final DateTime Function() _clock;

  MultiviewConfig _config;
  late List<MultiviewCell> _cells;

  /// Cell index → the rest of its playlist, for cells that cycle.
  final Map<int, List<MultiviewCellSource>> _playlists = <int, List<MultiviewCellSource>>{};

  /// Cell index → its player handle.
  final Map<int, PoolPlayerHandle> _handles = <int, PoolPlayerHandle>{};

  /// Cell index → per-cell substreams.
  final Map<int, StreamSubscription<PlaybackState>> _progressSubscriptions = <int, StreamSubscription<PlaybackState>>{};

  /// Cell index → last observed playback position and when it changed.
  final Map<int, ({Duration position, DateTime at})> _progress = <int, ({Duration position, DateTime at})>{};

  final StreamController<MultiviewSnapshot> _snapshotController = StreamController<MultiviewSnapshot>.broadcast();

  Timer? _tick;
  Timer? _patrol;
  int _focusedIndex = 0;
  int? _audioIndex;
  ResourcePressure _pressure = ResourcePressure.none;
  bool _budgetExceeded = false;
  bool _disposed = false;

  /// How often the wall checks its cells.
  static const Duration _tickInterval = Duration(seconds: 2);

  /// Cells of the wall.
  List<MultiviewCell> get cells => List<MultiviewCell>.unmodifiable(_cells);

  /// Current configuration.
  MultiviewConfig get config => _config;

  /// Current snapshot.
  MultiviewSnapshot get snapshot => _buildSnapshot();

  /// Snapshot changes.
  Stream<MultiviewSnapshot> get onChanged => _snapshotController.stream;

  /// Cell the viewer is looking at.
  int get focusedIndex => _focusedIndex;

  /// Cell that is audible, or `null`.
  int? get audioIndex => _audioIndex;

  /// The focused cell's danmaku session.
  ///
  /// The host routes incoming messages here (through its `DanmakuSink`), and
  /// only here: a wall feeds danmaku to one cell, which is what makes
  /// [MultiviewConfig.danmakuOnlyOnFocused] a routing decision instead of a
  /// per-cell filter.
  DanmakuOverlaySession? get focusedDanmaku => _cells[_focusedIndex].danmaku;

  /// Player identity of [index], for a host that wants to render it.
  String? playerIdOf(int index) => _handles[index]?.id;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Applies a new configuration.
  ///
  /// Growing the layout adds empty cells; shrinking it clears the cells that no
  /// longer exist, releasing their players. A config that lowers the audio or
  /// focus index moves those to a cell that still exists.
  Future<void> updateConfig(MultiviewConfig config) async {
    _ensureNotDisposed();
    final previousCapacity = _cells.length;
    _config = config;

    if (config.layout.capacity != previousCapacity) {
      _log.debug(
        'resizing the wall',
        fields: <String, Object?>{
          'from': previousCapacity,
          'to': config.layout.capacity,
          'layout': config.layout.name,
          'budget': config.effectiveMaxCells,
        },
      );
      _resizeCells(config.layout.capacity);
    }

    _focusedIndex = _focusedIndex.clamp(0, _cells.length - 1);
    if (_audioIndex != null && _audioIndex! >= _cells.length) {
      _audioIndex = _cells.isEmpty ? null : _cells.length - 1;
    }

    await _applyAudio();
    _applyDanmakuRouting();
    _startPatrolIfConfigured();
    _emit();
  }

  void _resizeCells(int capacity) {
    if (capacity < _cells.length) {
      final removed = _cells.sublist(capacity);
      _cells = _cells.sublist(0, capacity);
      for (final cell in removed) {
        unawaited(_releaseCell(cell.index));
      }
      return;
    }

    for (var index = _cells.length; index < capacity; index++) {
      _cells.add(MultiviewCell(index: index));
    }
  }

  // ---------------------------------------------------------------------------
  // Cells
  // ---------------------------------------------------------------------------

  /// Assigns [source] to [index] and starts it.
  Future<void> assign(int index, MultiviewCellSource source, {List<MultiviewCellSource>? playlist}) async {
    _ensureNotDisposed();
    final cell = _cellAt(index);

    if (_config.budgetPolicy == MultiviewBudgetPolicy.refuseNewCells && _isAtBudget && cell.isEmpty) {
      _log.warning(
        'refusing a new cell: at the decode budget',
        fields: <String, Object?>{
          'index': index,
          'roomId': source.roomId,
          'playing': _playingCount,
          'budget': _config.effectiveMaxCells,
        },
      );
      throw StateError(
        'The wall is at its decode budget (${_config.effectiveMaxCells} cells); '
        'refusing to add another under MultiviewBudgetPolicy.refuseNewCells.',
      );
    }

    _log.info(
      'assigning a cell',
      fields: <String, Object?>{
        'index': index,
        'roomId': source.roomId,
        'uri': source.source.uri,
        'isLive': source.isLive,
        'playlistSize': playlist?.length,
      },
    );

    if (playlist != null && playlist.length > 1) {
      _playlists[index] = List<MultiviewCellSource>.unmodifiable(playlist);
    } else {
      _playlists.remove(index);
    }

    cell.source = source;
    cell.failure = null;
    cell.restarts = 0;
    await _openCell(cell);
    await _applyAudio();
    _emit();
  }

  /// Fills the wall from [sources], one per cell, in order.
  Future<void> assignAll(List<MultiviewCellSource> sources) async {
    _ensureNotDisposed();
    final limit = sources.length < _config.effectiveMaxCells ? sources.length : _config.effectiveMaxCells;
    for (var index = 0; index < limit; index++) {
      await assign(index, sources[index]);
    }
  }

  /// Advances [index] to the next source in its playlist, if it has one.
  ///
  /// A failed or ended cell with a playlist moves on instead of retrying the
  /// same dead room — which is what makes a wall usable as a monitor: the list
  /// keeps cycling through the rooms that are live.
  Future<bool> advanceCell(int index) async {
    _ensureNotDisposed();
    final playlist = _playlists[index];
    final current = _cells[index].source;
    if (playlist == null || playlist.isEmpty || current == null) {
      return false;
    }

    final position = playlist.indexWhere((candidate) => candidate.roomId == current.roomId);
    final next = playlist[(position + 1) % playlist.length];
    _log.debug(
      'advancing to the next room in the playlist',
      fields: <String, Object?>{
        'index': index,
        'from': current.roomId,
        'to': next.roomId,
        'playlistSize': playlist.length,
      },
    );
    await assign(index, next, playlist: playlist);
    return true;
  }

  /// Clears [index]: stops it and gives its player back.
  Future<void> clear(int index) async {
    _ensureNotDisposed();
    final cell = _cells[index];
    cell.source = null;
    cell.qualityLabel = null;
    cell.failure = null;
    cell.restarts = 0;
    cell.status = MultiviewCellStatus.empty;
    _playlists.remove(index);
    await _releaseCell(index);
    _emit();
  }

  /// Clears every cell.
  Future<void> clearAll() async {
    _ensureNotDisposed();
    for (var index = 0; index < _cells.length; index++) {
      await clear(index);
    }
    _audioIndex = null;
    _emit();
  }

  /// Starts [index] again from its current source.
  Future<void> restartCell(int index) async {
    _ensureNotDisposed();
    final cell = _cells[index];
    if (cell.source == null) {
      return;
    }
    await _releaseCell(index);
    await _openCell(cell);
    _emit();
  }

  /// Stops [index] but keeps its room assigned.
  Future<void> stopCell(int index) async {
    _ensureNotDisposed();
    final handle = _handles[index];
    if (handle != null) {
      await handle.pause();
    }
    _cells[index].status = MultiviewCellStatus.empty;
    _emit();
  }

  // ---------------------------------------------------------------------------
  // Focus
  // ---------------------------------------------------------------------------

  /// Marks [index] as the cell being looked at.
  ///
  /// The focus decides which cell is rendered large, gets the danmaku and (with
  /// [MultiviewQualityPolicy.focusFirst]) the best quality.
  Future<void> setVideoFocus(int index) async {
    _ensureNotDisposed();
    _cellAt(index);
    if (_focusedIndex != index) {
      _log.debug(
        'video focus moved',
        fields: <String, Object?>{
          'from': _focusedIndex,
          'to': index,
          'roomId': _cells[index].source?.roomId,
          'qualityPolicy': _config.qualityPolicy.name,
          'danmakuOnlyOnFocused': _config.danmakuOnlyOnFocused,
        },
      );
    }
    _focusedIndex = index;
    await _applyQuality();
    _applyDanmakuRouting();
    _emit();
  }

  /// Marks [index] as the cell being listened to.
  Future<void> setAudioFocus(int index) async {
    _ensureNotDisposed();
    _cellAt(index);
    if (_audioIndex != index) {
      _log.debug(
        'audio focus moved',
        fields: <String, Object?>{'from': _audioIndex, 'to': index, 'audioMode': _config.audioMode.name},
      );
    }
    _audioIndex = index;
    await _applyAudio();
    _emit();
  }

  /// Silences the wall without losing the audio focus.
  Future<void> muteAll({bool muted = true}) async {
    _ensureNotDisposed();
    _config = _config.copyWith(audioMode: muted ? MultiviewAudioMode.muted : MultiviewAudioMode.exclusive);
    await _applyAudio();
    _emit();
  }

  /// Hands the player of [index] to [handOver].
  ///
  /// The wall keeps the cell: it is the same player, shown somewhere else. This
  /// is how a monitoring wall sends one camera to a small window without
  /// restarting the stream — the target is the host's `PipSessionController`
  /// (`pipSession.enter(PlayerId(playerId))`) or its floating equivalent.
  Future<bool> handOverCell(int index, Future<void> Function(String playerId) handOver) async {
    _ensureNotDisposed();
    final playerId = playerIdOf(index);
    if (playerId == null) {
      _log.debug('cell has no player to hand over', fields: <String, Object?>{'index': index});
      return false;
    }
    _log.info(
      'handing a cell over to another surface',
      fields: <String, Object?>{'index': index, 'playerId': playerId},
    );
    await handOver(playerId);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Budget
  // ---------------------------------------------------------------------------

  /// Reports device pressure.
  ///
  /// Applied immediately rather than at the next tick: a device in trouble does
  /// not wait two seconds for the wall to notice.
  Future<void> reportPressure(ResourcePressure pressure) async {
    _ensureNotDisposed();
    _pressure = pressure;
    _log.debug(
      'device pressure reported',
      fields: <String, Object?>{
        'hasPressure': pressure.hasPressure,
        'stopPreload': pressure.shouldStopPreload,
        'releaseResources': pressure.shouldReleaseResources,
      },
    );
    await _applyBudget();
    _emit();
  }

  Future<void> _applyBudget() async {
    final crowded = _playingCount > _config.effectiveMaxCells || _pressure.hasPressure;
    _budgetExceeded = crowded;
    if (!crowded) {
      return;
    }

    switch (_config.budgetPolicy) {
      case MultiviewBudgetPolicy.keepFocusedOnly:
        final severe = _pressure.shouldStopPreload || _pressure.shouldReleaseResources;
        if (!severe && _playingCount <= _config.effectiveMaxCells) {
          return;
        }
        _log.warning(
          'over budget: pausing every cell but the focused one',
          fields: <String, Object?>{'playing': _playingCount, 'budget': _config.effectiveMaxCells, 'severe': severe},
        );
        for (final cell in _cells) {
          if (cell.index == _focusedIndex || !cell.isPlaying) {
            continue;
          }
          await _handles[cell.index]?.pause();
          cell.status = MultiviewCellStatus.empty;
        }
      case MultiviewBudgetPolicy.letPlatformDrop:
      case MultiviewBudgetPolicy.refuseNewCells:
        _log.debug(
          'over budget, policy leaves the cells alone',
          fields: <String, Object?>{'policy': _config.budgetPolicy.name, 'playing': _playingCount},
        );
        return;
    }
  }

  bool get _isAtBudget => _playingCount >= _config.effectiveMaxCells;

  int get _playingCount => _cells.where((cell) => cell.isPlaying).length;

  // ---------------------------------------------------------------------------
  // Patrol
  // ---------------------------------------------------------------------------

  /// Starts rotating the focus on the configured interval.
  void startPatrol() {
    _ensureNotDisposed();
    _config = _config.copyWith(patrolEnabled: true);
    _startPatrolIfConfigured();
    _emit();
  }

  /// Stops the patrol where it is.
  void stopPatrol() {
    _ensureNotDisposed();
    _patrol?.cancel();
    _patrol = null;
    _config = _config.copyWith(patrolEnabled: false);
    _emit();
  }

  void _startPatrolIfConfigured() {
    _patrol?.cancel();
    _patrol = null;
    if (!_config.patrolEnabled || _cells.length <= 1) {
      return;
    }
    _patrol = Timer.periodic(_config.patrolInterval, (_) => unawaited(_rotateFocus()));
  }

  /// Moves the focus to the next cell worth watching.
  Future<void> _rotateFocus() async {
    if (_disposed || _cells.length <= 1) {
      return;
    }

    for (var offset = 1; offset <= _cells.length; offset++) {
      final index = (_focusedIndex + offset) % _cells.length;
      final cell = _cells[index];
      if (cell.isEmpty) {
        continue;
      }
      if (_config.patrolSkipsOfflineCells && cell.status != MultiviewCellStatus.playing) {
        continue;
      }
      _log.debug('patrol moving the focus', fields: <String, Object?>{'from': _focusedIndex, 'to': index});
      await setVideoFocus(index);
      await setAudioFocus(index);
      return;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _openCell(MultiviewCell cell) async {
    final source = cell.source;
    if (source == null) {
      return;
    }

    if (!source.isLive) {
      // A room the platform reports as offline needs no player: opening one
      // would show an error the viewer already knows the reason for.
      _log.debug(
        'cell is offline; no player opened',
        fields: <String, Object?>{'index': cell.index, 'roomId': source.roomId},
      );
      cell.status = MultiviewCellStatus.offline;
      cell.qualityLabel = null;
      await _releaseCell(cell.index);
      return;
    }

    _log.debug(
      'opening a cell',
      fields: <String, Object?>{
        'index': cell.index,
        'roomId': source.roomId,
        'uri': source.source.uri,
        'restarts': cell.restarts,
        'preference': _preferenceFor(cell.index).name,
      },
    );

    cell.status = MultiviewCellStatus.starting;
    cell.failure = null;
    _emit();

    try {
      final resolved = await _resolveForCell(cell);
      final handle = await _handleFor(cell.index);
      await handle.open(resolved.source, autoPlay: true);
      cell.status = MultiviewCellStatus.playing;
      cell.qualityLabel = resolved.qualityLabel;
      _log.info(
        'cell is playing',
        fields: <String, Object?>{'index': cell.index, 'roomId': resolved.roomId, 'quality': resolved.qualityLabel},
      );
      _watchProgress(cell.index, handle);
      await _applyAudio();
    } catch (error, stackTrace) {
      cell.failure = MultiviewCellFailure(
        kind: MultiviewCellFailureKind.startFailure,
        message: error.toString(),
        attempt: cell.restarts + 1,
        cause: error,
      );
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'cell failed to open',
        error: error,
        fields: <String, Object?>{'index': cell.index, 'roomId': source.roomId},
      );
      // A cell that cannot open might still have somewhere to go: a playlist
      // moves on, which is what turns a dead room into the next live one.
      if (_playlists.containsKey(cell.index)) {
        unawaited(advanceCell(cell.index));
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<MultiviewCellSource> _resolveForCell(MultiviewCell cell) async {
    final resolver = qualityResolver;
    final source = cell.source!;
    if (resolver == null) {
      return source;
    }
    return resolver(source, _preferenceFor(cell.index));
  }

  MultiviewQualityPreference _preferenceFor(int index) {
    if (_config.qualityPolicy == MultiviewQualityPolicy.uniform) {
      return MultiviewQualityPreference.best;
    }
    return index == _focusedIndex ? MultiviewQualityPreference.best : MultiviewQualityPreference.lowest;
  }

  Future<PoolPlayerHandle> _handleFor(int index) async {
    final existing = _handles[index];
    if (existing != null && !existing.isDisposed) {
      return existing;
    }
    final handle = await _players.acquire();
    _handles[index] = handle;
    return handle;
  }

  Future<void> _releaseCell(int index) async {
    final subscription = _progressSubscriptions.remove(index);
    await subscription?.cancel();
    _progress.remove(index);
    final handle = _handles.remove(index);
    if (handle == null) {
      return;
    }
    await handle.pause();
    await handle.recycle();
    // Back to the host, which may return it from the kernel's instance pool: a
    // wall that keeps switching rooms must not pay for a cold player each time.
    await _players.release(handle);
  }

  void _watchProgress(int index, PoolPlayerHandle handle) {
    unawaited(_progressSubscriptions.remove(index)?.cancel());
    _progress[index] = (position: Duration.zero, at: _clock());
    _progressSubscriptions[index] = handle.playbackStream.listen(
      (state) => _noteProgress(index, state.position),
      onError: (_) {},
    );
  }

  void _noteProgress(int index, Duration position) {
    final previous = _progress[index];
    if (previous == null) {
      return;
    }
    if (position != previous.position) {
      _progress[index] = (position: position, at: _clock());
    }
  }

  Future<void> _applyAudio() async {
    if (_cells.isEmpty) {
      return;
    }

    for (final cell in _cells) {
      final handle = _handles[cell.index];
      if (handle == null) {
        continue;
      }

      final desired = switch (_config.audioMode) {
        MultiviewAudioMode.muted => 0.0,
        MultiviewAudioMode.mixed => _config.focusedVolume,
        MultiviewAudioMode.exclusive =>
          cell.index == (_audioIndex ?? _focusedIndex) ? _config.focusedVolume : _config.backgroundVolume,
      };

      cell.hasAudioFocus = desired > 0;
      await handle.setVolume(desired);
      await handle.setMute(desired <= 0);
    }
  }

  Future<void> _applyQuality() async {
    final resolver = qualityResolver;
    if (resolver == null || !_config.degradeQualityWhenCrowded) {
      return;
    }
    // The desired quality is reported per cell; the host decides when to act on
    // it. A wall does not tear down a playing stream to change its ladder mid
    // wall — that would cost every other cell a re-buffer.
    for (final cell in _cells) {
      if (cell.isEmpty) {
        continue;
      }
      cell.hasVideoFocus = cell.index == _focusedIndex;
    }
  }

  void _applyDanmakuRouting() {
    for (final cell in _cells) {
      cell.hasVideoFocus = cell.index == _focusedIndex;
      final session = cell.danmaku;
      if (session == null) {
        continue;
      }
      // One queue per cell, fed only while the cell is the one being read.
      final shouldFeed = !_config.danmakuOnlyOnFocused || cell.index == _focusedIndex;
      session.updateConfig(session.config.copyWith(enabled: shouldFeed));
    }
  }

  /// Creates the focused cell's danmaku session on demand.
  ///
  /// Lazily, because most walls never use it and a session per cell that is
  /// never fed is a queue nobody reads.
  DanmakuOverlaySession ensureDanmakuFor(int index) {
    _ensureNotDisposed();
    final cell = _cellAt(index);
    final existing = cell.danmaku;
    if (existing != null) {
      return existing;
    }
    final session = DanmakuOverlaySession();
    cell.danmaku = session;
    return session;
  }

  void _startTicking() {
    _tick = Timer.periodic(_tickInterval, (_) => unawaited(_checkCells()));
  }

  /// Watches every playing cell for a stall.
  ///
  /// The core's live watchdogs own the *main* player; a wall of N cells needs
  /// the same idea per cell, with its own restart budget, because one dead
  /// stream must not take the wall down with it.
  Future<void> _checkCells() async {
    if (_disposed) {
      return;
    }

    final now = _clock();
    for (final cell in _cells) {
      if (!cell.isPlaying) {
        continue;
      }
      final progress = _progress[cell.index];
      if (progress == null) {
        continue;
      }
      if (now.difference(progress.at) < _config.cellStallTimeout) {
        continue;
      }
      await _handleStall(cell);
    }

    await _applyBudget();
  }

  Future<void> _handleStall(MultiviewCell cell) async {
    _log.warning(
      'cell stalled',
      fields: <String, Object?>{
        'index': cell.index,
        'roomId': cell.source?.roomId,
        'restarts': cell.restarts,
        'maxRestarts': _config.cellMaxRestarts,
        'timeoutSeconds': _config.cellStallTimeout.inSeconds,
      },
    );

    cell.failure = MultiviewCellFailure(
      kind: MultiviewCellFailureKind.stallFailure,
      message: 'No progress for ${_config.cellStallTimeout.inSeconds}s',
      attempt: cell.restarts + 1,
    );

    if (cell.restarts >= _config.cellMaxRestarts) {
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'cell stalled past its restart budget',
        fields: <String, Object?>{
          'index': cell.index,
          'roomId': cell.source?.roomId,
          'restarts': cell.restarts,
          'hasPlaylist': _playlists.containsKey(cell.index),
        },
      );
      _emit();
      // Out of restarts: a playlist cell moves on, which is the difference
      // between a wall that watches and one that stares at a frozen frame.
      if (_playlists.containsKey(cell.index)) {
        await advanceCell(cell.index);
      }
      return;
    }

    cell.restarts++;
    cell.status = MultiviewCellStatus.recovering;
    _log.info(
      'restarting a stalled cell',
      fields: <String, Object?>{'index': cell.index, 'roomId': cell.source?.roomId, 'attempt': cell.restarts},
    );
    _emit();

    await _releaseCell(cell.index);
    try {
      await _openCell(cell);
    } catch (error) {
      // The cell reports the stall as its reason and the failed restart as the
      // detail: an operator wants to know that this camera froze, not only that
      // the last attempt to bring it back did not work.
      cell.failure = MultiviewCellFailure(
        kind: MultiviewCellFailureKind.stallFailure,
        message: 'Stalled; the restart attempt failed: $error',
        attempt: cell.restarts,
        cause: error,
      );
      cell.status = MultiviewCellStatus.failed;
      _log.error(
        'restart after a stall failed',
        error: error,
        fields: <String, Object?>{'index': cell.index, 'attempt': cell.restarts},
      );
      _emit();
    }
  }

  MultiviewCell _cellAt(int index) {
    if (index < 0 || index >= _cells.length) {
      throw RangeError.index(index, _cells, 'index');
    }
    return _cells[index];
  }

  MultiviewSnapshot _buildSnapshot() {
    return MultiviewSnapshot(
      cells: cells,
      layout: _config.layout,
      focusedIndex: _focusedIndex,
      audioIndex: _audioIndex,
      pressure: _pressure,
      budgetExceeded: _budgetExceeded,
    );
  }

  void _emit() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_buildSnapshot());
    }
  }

  /// Releases the wall: every cell's player goes back to the host.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _tick?.cancel();
    _tick = null;
    _patrol?.cancel();
    _patrol = null;

    _log.debug('releasing the wall', fields: <String, Object?>{'cells': _cells.length, 'playing': _playingCount});

    for (final index in _cells.map((cell) => cell.index).toList()) {
      await _releaseCell(index);
    }
    for (final cell in _cells) {
      await cell.danmaku?.dispose();
      cell.danmaku = null;
    }

    await DisposeUtils.close(_snapshotController);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('MultiviewController has been disposed.');
    }
  }
}
