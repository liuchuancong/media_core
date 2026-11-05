import 'dart:async';

import 'package:equatable/equatable.dart' show Equatable;
import 'package:media_core/media_core.dart'
    show
        LogCategory,
        LogModule,
        MediaCoreLog,
        MediaCoreMemory,
        MemoryAccount,
        MemoryEstimates,
        MemoryModule,
        PlaybackPoolOrchestrator,
        PoolPlayerHandle,
        memoryContributorKey;

import 'package:media_core_list_playback/src/playback_list_config.dart';
import 'package:media_core_list_playback/src/playback_list_item.dart';
import 'package:media_core_list_playback/src/playback_list_player.dart';
import 'package:media_core_list_playback/src/playback_progress_store.dart';

/// Decision trail for list playback.
///
/// Two behaviours are invisible when they work and confusing when they do not:
/// whether an item resumed from a remembered position or started over, and
/// whether the item was opened through the pool or by the list's own player.
/// Both are recorded on every open.
final LogModule _log = MediaCoreLog.of(LogCategory.playback);

/// Ledger of the list's items and remembered positions.
///
/// Both are metadata: the list drives a player it does not own, so what it can
/// account for is the list itself plus the progress entries it keeps for resume.
final MemoryAccount _memory = MediaCoreMemory.of(MemoryModule.playback);

/// Immutable snapshot of a playback list.
final class PlaybackListState extends Equatable {
  /// Creates a snapshot describing the open [index] of [count], the current
  /// [item], any [resumedFrom] position, whether a source is [opening], and the
  /// last [error].
  const PlaybackListState({
    this.index = 0,
    this.count = 0,
    this.item,
    this.resumedFrom,
    this.opening = false,
    this.error,
  });

  /// Index of the item currently open.
  final int index;

  /// Number of items in the list.
  final int count;

  /// Item currently open, or `null` when the list is empty.
  final PlaybackListItem? item;

  /// Position playback resumed from, when the item did not start at zero.
  ///
  /// Reported so a host can say "resumed" instead of silently jumping, which
  /// otherwise looks like a glitch to a viewer who expected the beginning.
  final Duration? resumedFrom;

  /// Whether a source is being opened.
  final bool opening;

  /// Last failure, if any.
  final Object? error;

  /// Whether the list holds no items.
  bool get isEmpty => count == 0;

  /// Whether swiping up would move to another item.
  bool get hasNext => index + 1 < count;

  /// Whether swiping down would move to another item.
  bool get hasPrevious => index > 0;

  /// Returns a copy with the given fields replaced.
  ///
  /// Null arguments keep the current value; [clearResumedFrom] and [clearError]
  /// force those fields back to `null` so a copy can drop them.
  PlaybackListState copyWith({
    int? index,
    int? count,
    PlaybackListItem? item,
    Duration? resumedFrom,
    bool? opening,
    Object? error,
    bool clearResumedFrom = false,
    bool clearError = false,
  }) {
    return PlaybackListState(
      index: index ?? this.index,
      count: count ?? this.count,
      item: item ?? this.item,
      resumedFrom: clearResumedFrom ? null : (resumedFrom ?? this.resumedFrom),
      opening: opening ?? this.opening,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [index, count, item, resumedFrom, opening, error];

  @override
  String toString() => 'PlaybackListState(${index + 1}/$count${item == null ? '' : ', ${item!.id}'})';
}

/// Plays an ordered list in one window.
///
/// Responsibilities:
///
/// - open an item, resume it where it was left, remember where it is left
/// - move to the next or previous item
/// - report which item is open and whether either direction is possible
///
/// It does not:
///
/// - render the list or its gestures (the host does)
/// - own the player (it drives a [PlaybackListPlayer])
/// - decide a list's contents
///
/// ## Why the position is saved on the way out
///
/// Progress is only useful if it is written before the current item stops being
/// current, and the moment of a switch is the last moment the old item's
/// position is still readable. [next], [previous] and [jumpTo] therefore save
/// before they open, and [savePosition] exists for the host to call when the
/// viewer leaves the list entirely (back button, app exit).
///
/// ## Why resume is bounded by a completion threshold
///
/// An item abandoned in its final seconds resumes from the start: the viewer
/// almost certainly finished it, and restoring the last five seconds reads as a
/// broken player rather than a feature.
final class PlaybackListController {
  /// Creates a controller over [items].
  ///
  /// It plays through either a dedicated [player] or a [pool] plus
  /// [poolPlayerFactory] (the assert enforces one of the two). Progress is kept
  /// in [store], defaulting to an in-memory store bounded by [config].
  PlaybackListController({
    PlaybackListPlayer? player,
    List<PlaybackListItem> items = const <PlaybackListItem>[],
    PlaybackProgressStore? store,
    this.config = PlaybackListConfig.defaults,
    this.pool,
    this.poolPlayerFactory,
  }) : assert(
         player != null || (pool != null && poolPlayerFactory != null),
         'A list needs either its own player or a pool plus a way to drive its handles',
       ),
       _player = player,
       _items = List<PlaybackListItem>.unmodifiable(items),
       _store = store ?? InMemoryPlaybackProgressStore(config: config) {
    // Swallowed here, not left dangling: nobody awaits this future unless an
    // open comes through the pool, and a pool that refuses the initial
    // hand-off must not surface as an unhandled async error before that.
    _poolItemsSync = _syncPoolItems().catchError((Object error) {
      _log.warning('initial pool sync failed', error: error);
    });
  }

  /// This instance's key in the shared account: a module can have several
  /// live instances, and a report sums their contributions rather than
  /// keeping whichever reported last.
  late final String _memoryKey = memoryContributorKey(this);

  /// Pool that warms neighbouring items, or `null` when the list drives a
  /// single player itself.
  ///
  /// With a pool the item a swipe reaches is already open, so the swipe is a
  /// source swap instead of a cold start — which is the entire reason a list
  /// stutters without one. See [PlaybackListConfig.recommendedPoolConfig].
  final PlaybackPoolOrchestrator? pool;

  /// Turns a pooled player handle into the player this list drives.
  ///
  /// Required with [pool]: the controller reads position and seeks through it,
  /// and a kernel host passes `KernelPlaybackListPlayer.new`.
  final PlaybackListPlayer Function(PoolPlayerHandle handle)? poolPlayerFactory;

  PlaybackListPlayer? _player;

  /// In-flight hand-off of the item list to the pool.
  ///
  /// The pool serializes its own operations, so a list set before an item is
  /// opened is applied first; the controller still awaits it so a caller can
  /// never observe a pool that does not know about the item it was asked to
  /// play.
  Future<void>? _poolItemsSync;

  /// The player the list is currently driving.
  PlaybackListPlayer get player {
    final current = _player;
    if (current == null) {
      throw StateError('PlaybackListController has no player bound yet.');
    }
    return current;
  }

  final PlaybackProgressStore _store;

  /// Tunables.
  final PlaybackListConfig config;

  List<PlaybackListItem> _items;
  int _index = 0;
  int? _lastOpenedIndex;
  PlaybackListState _state = const PlaybackListState();
  bool _disposed = false;

  /// The item the running open chain must land on, or null when nothing newer
  /// is waiting.
  int? _openTarget;

  /// Set while an open chain is running.
  ///
  /// A viewer who taps next three times, or drags across a dozen rows, must not
  /// pay a dozen opens: a request that arrives mid-flight retargets the chain
  /// instead of queueing behind it.
  Completer<void>? _openChain;

  final StreamController<PlaybackListState> _stateController = StreamController<PlaybackListState>.broadcast();

  /// Items in order.
  List<PlaybackListItem> get items => _items;

  /// Current snapshot.
  PlaybackListState get state => _state;

  /// Snapshot changes.
  Stream<PlaybackListState> get onStateChanged => _stateController.stream;

  /// Whether the controller has been disposed.
  bool get isDisposed => _disposed;

  /// Hands the current items to the pool, if there is one.
  Future<void> _syncPoolItems() async {
    final activePool = pool;
    if (activePool == null) {
      return;
    }
    await activePool.setItems(_items.map((item) => item.source).toList(growable: false));
  }

  /// Replaces the list contents, keeping the current item open when it is
  /// still present.
  ///
  /// A list that changes under the viewer (a room going offline, a channel
  /// list refreshed) must not silently switch what is playing, so the current
  /// item is kept by id when it survives the change and playback is left alone.
  void updateItems(List<PlaybackListItem> items) {
    _ensureNotDisposed();
    final previous = _items;
    _items = List<PlaybackListItem>.unmodifiable(items);
    // A same-list refresh (every source compares equal, in order) would only
    // buy a redundant reconcile on the pool's serial queue: `setItems` keeps
    // the ratios and assignments of unchanged indexes, so there is nothing
    // for the hand-off to correct. The pool's `_sources` are also replaced
    // synchronously before its reconcile runs, so a skipped sync can never
    // leave it holding a stale list.
    if (!_sameSources(previous, _items)) {
      _poolItemsSync = _syncPoolItems().catchError((Object error) {
        _log.warning('pool sync after updateItems failed', error: error);
      });
    }

    final currentId = _state.item?.id;
    if (currentId != null) {
      final index = _items.indexWhere((item) => item.id == currentId);
      if (index >= 0) {
        _index = index;
        if (_openChain != null) {
          // An open leg is in flight toward the old coordinates. It will bail
          // on the re-pointed cursor (the pool path also re-checks the row it
          // is about to bind), and the chain then re-aims at this new
          // coordinate. Re-pointing the marker would make that re-aim look
          // already-settled and swallow it - the marker only means "a leg
          // opened this row" once a leg actually did. The stale coordinate is
          // dropped instead; the pool's own reconcile (from the hand-off
          // above) demotes whatever the superseded leg left open.
          _lastOpenedIndex = null;
        } else {
          // No leg is running: the old coordinate now names a different item,
          // the re-pointed one names the item still on screen.
          _lastOpenedIndex = index;
        }
        // `copyWith` preserves `opening: true` from an in-flight leg that may
        // never settle against the new coordinates; the row shown is the
        // current one and it is not opening.
        _emit(_state.copyWith(index: index, count: _items.length, opening: false));
        return;
      }
    }

    // The current item did not survive: the old stand-down coordinate names a
    // stranger in the new list.
    _lastOpenedIndex = null;

    // Keep the cursor inside the new list so navigation continues from the
    // row the state below names, rather than from an index that no longer
    // exists.
    _index = _index.clamp(0, _items.isEmpty ? 0 : _items.length - 1);

    _emit(
      PlaybackListState(index: _index, count: _items.length, item: _items.isEmpty ? null : _items[_index]),
    );
  }

  /// Whether [next] carries the same sources, in the same order, as [current].
  ///
  /// Sources compare by value, ids are irrelevant here: the pool is keyed on
  /// sources alone.
  bool _sameSources(List<PlaybackListItem> current, List<PlaybackListItem> next) {
    if (identical(current, next)) {
      return true;
    }
    if (current.length != next.length) {
      return false;
    }
    for (var i = 0; i < current.length; i++) {
      if (current[i].source != next[i].source) {
        return false;
      }
    }
    return true;
  }

  /// Opens the item at [index], resuming it when progress was remembered.
  Future<void> open({int index = 0}) async {
    _ensureNotDisposed();
    if (_items.isEmpty) {
      _emit(const PlaybackListState());
      return;
    }
    if (index < 0 || index >= _items.length) {
      throw RangeError.index(index, _items, 'index');
    }

    _index = index;

    // A chain is already running: retarget it and wait on the same settling
    // rather than starting a second open of its own.
    final running = _openChain;
    if (running != null) {
      _openTarget = index;
      return await running.future;
    }

    _openTarget = index;
    final settled = Completer<void>();
    _openChain = settled;
    try {
      while (!_disposed) {
        final target = _openTarget;
        if (target == null) {
          break;
        }
        _openTarget = null;

        // A fling back to the row the in-flight leg already settled must not
        // re-open it: that is a full restart (and a second resume seek) for a
        // row that is already playing. A failure path never sets the marker,
        // so retrying a failed row still works.
        if (target == _lastOpenedIndex && _index == target) {
          continue;
        }

        await _openAt(target);
      }
    } finally {
      _openChain = null;
      if (!settled.isCompleted) {
        settled.complete();
      }
    }
  }

  /// Brings [index] onto the player: the single place that opens, resumes and
  /// reports. [open] decides which index is worth opening at all.
  Future<void> _openAt(int index) async {
    if (_disposed) {
      return;
    }

    // The index was validated against an older items list; a shrink that
    // landed while the open chain was queued makes it stale, and indexing
    // first would turn that into a RangeError nobody signed up for.
    if (index >= _items.length) {
      // Hand the chain back to the live cursor rather than ending it on a row
      // that no longer exists: `updateItems` may have re-pointed the viewer
      // while this leg sat queued.
      _rearmSupersededLeg(index);
      return;
    }

    final item = _items[index];
    _log.debug(
      'opening a list item',
      fields: <String, Object?>{'index': index, 'count': _items.length, 'itemId': item.id, 'throughPool': pool != null},
    );
    _emit(
      _state.copyWith(
        index: index,
        count: _items.length,
        item: item,
        opening: true,
        clearError: true,
        clearResumedFrom: true,
      ),
    );

    final previousIndex = _lastOpenedIndex;
    try {
      // The viewer may have moved on while this call was queued behind the
      // pool hand-off: opening a row nobody is looking at costs a decode.
      if (_superseded(index, item)) {
        _rearmSupersededLeg(index);
        return;
      }
      await _openItem(item, index);

      // Checked here, not later: a superseded (or post-dispose) leg must not
      // stand down the previous row, mark this one opened, or seek it - all
      // of which act on a row nobody is looking at any more.
      if (_superseded(index, item)) {
        _rearmSupersededLeg(index);
        return;
      }

      if (previousIndex != null && previousIndex != index) {
        // The outgoing item is no longer visible; the pool keeps it warm or
        // releases it according to its own configuration.
        await pool?.onVisibilityChanged(previousIndex, 0);
      }
      _lastOpenedIndex = index;
      _log.info(
        'list item opened',
        fields: <String, Object?>{
          'from': previousIndex,
          'to': index,
          'itemId': item.id,
          'throughPool': pool != null,
        },
      );

      final resumedFrom = await _resume(item);
      if (_superseded(index, item)) {
        // A newer request owns the state now; clearing `opening` here would
        // flash the row the viewer just moved onto as if it had finished.
        _rearmSupersededLeg(index);
        return;
      }
      _emit(_state.copyWith(opening: false, resumedFrom: resumedFrom));
    } on Object catch (error) {
      _log.error(
        'could not open the list item',
        error: error,
        fields: <String, Object?>{'index': index, 'itemId': item.id},
      );
      if (_superseded(index, item)) {
        _rearmSupersededLeg(index);
        return;
      }
      _emit(_state.copyWith(opening: false, error: error));
    }
  }

  /// Whether the running open leg has been overtaken and must not touch the
  /// player or the state any more.
  ///
  /// A leg is overtaken when a newer request moved the cursor, or when
  /// `updateItems` shifted or dropped rows so [index] no longer names [item].
  /// Both are checked against the live values, not the ones captured at leg
  /// start.
  bool _superseded(int index, PlaybackListItem item) {
    if (_disposed || _index != index) {
      return true;
    }
    return _indexNoLongerNamesItem(index, item);
  }

  /// Whether [index] no longer names [item] in the current list.
  ///
  /// `updateItems` can shift or drop rows while an open leg waits on the
  /// pool; after the shift the leg's index points at a stranger, and
  /// standing down, seeking or reporting through it would act on an item the
  /// viewer never asked for. `PlaybackListItem` compares by id, which is the
  /// item's identity.
  bool _indexNoLongerNamesItem(int index, PlaybackListItem item) {
    return index >= _items.length || _items[index].id != item.id;
  }

  /// Re-aims an idle chain at the live cursor after a leg stood down because
  /// `updateItems` moved it without a queued request naming a new one.
  ///
  /// A newer request that overtook the leg already set `_openTarget`, so this
  /// leaves it alone; only an idle chain is re-armed. Pool-only: without a
  /// pool the leg opened the captured item by identity, so the open it
  /// finished is already the right one and re-arming would only restart it.
  void _rearmSupersededLeg(int index) {
    if (_disposed || pool == null || _index == index || _openTarget != null) {
      return;
    }
    _openTarget = _index;
  }

  /// Moves to the next item. A no-op at the end of the list.
  ///
  /// Guarded on the live cursor, not the last emitted state: an open chain in
  /// flight can leave the emitted index behind the live one, and computing
  /// from the stale one walks past the list's end.
  Future<void> next() {
    _ensureNotDisposed();
    if (_index + 1 >= _items.length) {
      return Future<void>.value();
    }
    return _switchTo(_index + 1);
  }

  /// Moves to the previous item. A no-op at the start of the list.
  Future<void> previous() {
    _ensureNotDisposed();
    if (_index <= 0) {
      return Future<void>.value();
    }
    return _switchTo(_index - 1);
  }

  /// Moves to [index].
  Future<void> jumpTo(int index) {
    _ensureNotDisposed();
    if (index == _index) {
      return Future<void>.value();
    }
    return _switchTo(index);
  }

  /// Remembers the current position without changing items.
  ///
  /// Call when the viewer leaves the list, so returning later resumes here.
  Future<void> savePosition() async {
    _ensureNotDisposed();
    final captured = _capturedProgress();
    if (captured == null) {
      return;
    }
    final (id, position) = captured;
    await _store.save(id, position);
    _log.info('position saved', fields: <String, Object?>{'itemId': id, 'positionMs': position.inMilliseconds});
  }

  /// The (item id, position) pair a progress write must record, read
  /// synchronously.
  ///
  /// The pairing, not the emitted state: mid-switch the state already names
  /// the incoming item while the bound player still sits on the outgoing
  /// one, and saving under the wrong id overwrites real remembered progress.
  /// Reading synchronously also lets a caller capture first and write later,
  /// so the store round-trip can run beside a switch instead of in front of
  /// it - once `open` rebinds the player, the old position is unreadable.
  (String, Duration)? _capturedProgress() {
    final item = _boundItem;
    if (item == null || !config.resumeEnabled) {
      return null;
    }
    final current = _player;
    if (current == null) {
      return null;
    }
    return (item.id, current.position);
  }

  /// Forgets every remembered position.
  Future<void> clearProgress() {
    _ensureNotDisposed();
    return _store.clearAll();
  }

  /// Releases the controller.
  ///
  /// The player is not disposed: the list drives a player it does not own, and
  /// a host that shares one player between a list and a page must not lose it
  /// when the list is torn down.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    // The flag goes up before the final save: an open leg that is mid-flight
    // bails at its next check instead of rebinding the player while the last
    // position is being read, and a switch that arrives from here on is
    // refused by the ordinary disposed checks instead of racing the teardown.
    // The capture is inlined rather than going through [savePosition], whose
    // guard refuses a disposed controller.
    _disposed = true;
    try {
      final captured = _capturedProgress();
      if (captured != null) {
        final (id, position) = captured;
        await _store.save(id, position);
        _log.info('position saved', fields: <String, Object?>{'itemId': id, 'positionMs': position.inMilliseconds});
      }
    } on Object catch (error) {
      _log.warning('could not save position during dispose', error: error);
    }

    // Nobody will settle the chain now: release the callers awaiting it.
    _openTarget = null;
    final chain = _openChain;
    if (chain != null && !chain.isCompleted) {
      chain.complete();
    }

    _memory.withdraw(_memoryKey);
    await _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Opens [item] either through the pool or the list's own player.
  ///
  /// With a pool the controller does not open the source itself: the pool
  /// decides which of its players takes it, plays the active one and keeps the
  /// neighbours open, and the controller binds to whatever handle came out
  /// active so position and seek keep working.
  Future<void> _openItem(PlaybackListItem item, int index) async {
    final activePool = pool;
    if (activePool == null) {
      await player.open(item.source);
      // The open above is a long await: dispose or an `updateItems` re-point
      // can land inside it, and binding afterwards would attribute the player
      // to an item nobody is waiting for any more. `_openAt` bails on the
      // same check right after, so nothing is lost by not binding.
      if (_superseded(index, item)) {
        return;
      }
      _boundItem = item;
      return;
    }

    final handle = await _openThroughPool(item, index, activePool);
    _player = poolPlayerFactory!(handle);
    // Paired with the player bind: `savePosition` must attribute what it
    // reads to the item the bound player is actually playing, not to
    // whatever the emitted state last named.
    _boundItem = item;
  }

  /// The item the currently bound player belongs to; lags the emitted state
  /// by exactly the duration of an open, which is the pairing the progress
  /// store needs.
  PlaybackListItem? _boundItem;

  Future<PoolPlayerHandle> _openThroughPool(
    PlaybackListItem item,
    int index,
    PlaybackPoolOrchestrator activePool,
  ) async {
    // The pool must know the item before it can be asked to play it.
    await _poolItemsSync;
    // Each await below is a point where `updateItems` can replace the list:
    // after a refresh or a reorder, [index] can name a different row than the
    // one this leg was asked to open. Opening (and then binding) by a stale
    // index would put another item's player under this item's name and later
    // seek it with this item's remembered position - the stale-coordinate
    // family the pool itself guards against when it re-checks `openedSource`.
    // The first check stops a wasted open of the stranger's row; the second
    // closes the window the visibility await reopens.
    if (_indexNoLongerNamesItem(index, item)) {
      throw StateError('The list changed while item ${item.id} was opening at index $index.');
    }
    await activePool.onVisibilityChanged(index, 1);
    if (_indexNoLongerNamesItem(index, item)) {
      throw StateError('The list changed while item ${item.id} was opening at index $index.');
    }
    final handle = activePool.handleFor(index);
    if (handle == null) {
      _log.error(
        'the pool did not take the item',
        fields: <String, Object?>{'index': index, 'itemId': item.id, 'uri': item.source.uri},
      );
      throw StateError('The playback pool did not take item $index (${item.id}).');
    }
    return handle;
  }

  /// Saves the outgoing item, then opens the target.
  Future<void> _switchTo(int index) async {
    // The pair is captured synchronously - the bound player still sits on the
    // outgoing item here, and `open` below rebinds it. The store write is then
    // left running beside the open instead of in front of it: a persistent
    // store's round-trip must not delay the item the viewer swiped to. The
    // write is for the outgoing id, which nothing in the open path reads, and
    // a failing save must not stop the switch from happening.
    final captured = _capturedProgress();
    if (captured != null) {
      final (id, position) = captured;
      unawaited(
        _store.save(id, position).catchError((Object error) {
          _log.warning('could not save outgoing position before switch', error: error);
        }),
      );
    }
    await open(index: index);
  }

  /// Seeks to the remembered position, returning it when it did.
  ///
  /// A remembered position inside the final [PlaybackListConfig.completionThreshold]
  /// is treated as "watched to the end": the entry is forgotten and playback
  /// starts over, because restoring the last few seconds reads as a broken
  /// player rather than as a feature.
  Future<Duration?> _resume(PlaybackListItem item) async {
    if (!config.resumeEnabled) {
      return null;
    }

    final saved = await _store.positionOf(item.id);
    if (saved == null || saved <= Duration.zero) {
      return null;
    }

    if (isNearCompletion(saved, player.duration)) {
      // Restoring the final seconds reads as a broken player, so the entry is
      // dropped and the item starts over.
      _log.debug(
        'remembered position counts as finished; starting from the beginning',
        fields: <String, Object?>{
          'itemId': item.id,
          'savedMs': saved.inMilliseconds,
          'durationMs': player.duration.inMilliseconds,
        },
      );
      await _store.clear(item.id);
      return null;
    }

    _log.debug(
      'resuming from the remembered position',
      fields: <String, Object?>{'itemId': item.id, 'positionMs': saved.inMilliseconds},
    );
    await player.seek(saved);
    return saved;
  }

  /// Whether [position] is close enough to the end of [duration] to count as
  /// finished. See [PlaybackListConfig.completionThreshold].
  ///
  /// An unknown duration (zero, which is what a live stream reports) never
  /// counts as finished: there is no end to be near.
  bool isNearCompletion(Duration position, Duration duration) {
    if (duration <= Duration.zero) {
      return false;
    }
    return duration - position <= config.completionThreshold;
  }

  /// Reports the retained items and remembered positions.
  void _reportMemory() {
    _memory.report(
      _memoryKey,
      items: _items.length,
      bytes: _items.length * MemoryEstimates.playbackItem,
      note: '${_items.length} item(s), position $_index',
    );
  }

  void _emit(PlaybackListState next) {
    _reportMemory();
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PlaybackListController has been disposed.');
    }
  }
}
