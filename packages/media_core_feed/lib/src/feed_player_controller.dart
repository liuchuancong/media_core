import 'dart:async';

import 'package:media_core/media_core.dart';

/// How a feed item is currently being played.
enum FeedItemState {
  /// The item is not attached to a player.
  idle,

  /// The item's source is opening.
  opening,

  /// The item's source is open and playing.
  playing,

  /// The item's source is open but paused (swiped away but kept warm,
  /// or paused by the user on the visible page).
  paused,

  /// Playing this item failed and nothing in the framework answered it.
  error,
}

/// Vertical feed (TikTok/Douyin-style) playback orchestration.
///
/// One [PlayerHandle] serves the whole feed. Swiping re-opens the same
/// handle on the next item's source, which reuses the attached engine and
/// avoids the adapter create/dispose churn a per-page player would cause.
///
/// ```text
/// load(items)
///   └▶ showIndex(i)   ──▶ handle.open(items[i]) ─▶ play ─▶ verify
/// showIndex(i + 1)    ──▶ same handle, next source
/// ```
///
/// Off-screen items are not kept warm by default: preloading a stream the
/// user may never stop on costs bandwidth on live feeds. [preload] records
/// the next item with the kernel's [PlayerKernel.preloadManager] so a
/// host that wants to warm it up can; pass `preloadAhead: false` to skip.
///
/// Errors on the visible item surface once on [onItemError]; the caller
/// decides whether to skip the item, show a retry button or remove it.
/// Recovery of a *playing* item (stalls, engine hiccups) is the live
/// module's job — attach a [LivePlaybackController]-style sweep on top if
/// the feed serves live streams.
final class FeedPlayerController {
  FeedPlayerController(this.kernel, {this.preloadAhead = true, this.pool});

  /// The kernel providing the player and the preload bookkeeping.
  final PlayerKernel kernel;

  /// Whether the next item is queued for preload when an item becomes
  /// visible.
  ///
  /// Ignored when [pool] is installed: the pool decides what stays open, and
  /// it keeps neighbours genuinely warm (open, paused) rather than queuing an
  /// intent the host would have to act on.
  final bool preloadAhead;

  /// Pool that owns the players, or `null` to keep one shared handle.
  ///
  /// Without a pool this controller re-points a single handle at each item it
  /// shows: correct, but every swipe starts a cold open because nothing is
  /// warm. With a pool, the item a swipe reaches is already open and the swipe
  /// becomes a source swap — see [FeedConfig.recommendedPoolConfig] for the
  /// values a feed wants.
  final PlaybackPoolOrchestrator? pool;

  /// In-flight hand-off of the item list to the pool.
  Future<void>? _poolItemsSync;

  final List<PlayerSource> _items = <PlayerSource>[];

  PlayerHandle? _handle;
  PoolPlayerHandle? _pooledPlayer;

  int _index = -1;

  bool _disposed = false;

  FeedItemState _itemState = FeedItemState.idle;

  final StreamController<int> _indexController = StreamController<int>.broadcast();
  final StreamController<FeedItemState> _stateController = StreamController<FeedItemState>.broadcast();
  final StreamController<PlayerFailure> _errorController = StreamController<PlayerFailure>.broadcast();

  /// All items of the feed.
  List<PlayerSource> get items => List<PlayerSource>.unmodifiable(_items);

  /// Index of the item currently attached to the player, `-1` before [load].
  int get currentIndex => _index;

  /// The item currently attached, if any.
  PlayerSource? get currentItem => _index >= 0 && _index < _items.length ? _items[_index] : null;

  /// State of the visible item.
  FeedItemState get itemState => _itemState;

  /// The attached kernel player, when one exists.
  ///
  /// Null while the feed is driven through a pool whose host is not the kernel
  /// — such a host pools its own players. See [pooledPlayer] for the handle
  /// that is always present in that case.
  PlayerHandle? get handle => _handle;

  /// The pooled player currently showing the visible item, when a pool is
  /// installed.
  PoolPlayerHandle? get pooledPlayer => _pooledPlayer;

  /// Emits the visible index on every [showIndex].
  Stream<int> get onIndexChanged => _indexController.stream;

  /// Emits the visible item's state.
  Stream<FeedItemState> get onItemStateChanged => _stateController.stream;

  /// Terminal failure of the visible item. One event per failed item.
  Stream<PlayerFailure> get onItemError => _errorController.stream;

  /// Loads the feed and attaches [initialIndex].
  Future<void> load(List<PlayerSource> items, {int initialIndex = 0}) {
    if (_disposed) {
      return Future<void>.value();
    }

    _items
      ..clear()
      ..addAll(items);

    final activePool = pool;
    _poolItemsSync = activePool == null
        ? null
        : activePool.setItems(List<PlayerSource>.unmodifiable(_items));

    return showIndex(initialIndex.clamp(0, items.isEmpty ? 0 : items.length - 1));
  }

  /// Attaches item [index]: re-opens the shared handle on its source.
  ///
  /// Safe to call for every page the pager scrolls through — the item
  /// already visible is a no-op.
  Future<void> showIndex(int index) async {
    if (_disposed || index < 0 || index >= _items.length || index == _index) {
      return;
    }

    final previousIndex = _index;
    _index = index;
    _emitIndex(index);

    final activePool = pool;
    if (activePool != null) {
      await _showIndexThroughPool(activePool, index, previousIndex);
      return;
    }

    if (_handle == null || _handle!.disposed) {
      _handle = await kernel.create();
    }

    final handle = _handle!;
    final source = _items[index];

    _setItemState(FeedItemState.opening);

    try {
      await handle.open(source, autoPlay: true);

      if (_disposed || _index != index) {
        // The user kept swiping while this page was opening.
        return;
      }

      _setItemState(FeedItemState.playing);

      if (preloadAhead && index + 1 < _items.length) {
        kernel.preload(_items[index + 1]);
      }
    } catch (error) {
      MediaCoreLog.error(
        LogCategory.recovery,
        'feed item failed: ${source.uri}',
        error: error,
        fields: <String, Object?>{'index': index},
      );

      if (_index == index && !_disposed) {
        _setItemState(FeedItemState.error);

        _errorController.add(
          PlayerFailure(
            code: PlayerErrorCode.noPlayableStream,
            message: 'Feed item $index failed to play: $error',
            cause: error,
          ),
        );
      }
    }
  }

  /// Shows [index] through the pool.
  ///
  /// The pool opens the source, plays the active item and keeps the neighbours
  /// open; this controller only takes the resulting handle so volume, playback
  /// state and its own bookkeeping keep working.
  Future<void> _showIndexThroughPool(
    PlaybackPoolOrchestrator activePool,
    int index,
    int previousIndex,
  ) async {
    final source = _items[index];
    _setItemState(FeedItemState.opening);

    try {
      await _poolItemsSync;
      await activePool.onVisibilityChanged(index, 1);
      if (previousIndex >= 0 && previousIndex != index) {
        await activePool.onVisibilityChanged(previousIndex, 0);
      }

      if (_disposed || _index != index) {
        // The user kept swiping while this page was opening.
        return;
      }

      final pooled = activePool.handleFor(index);
      if (pooled == null) {
        throw StateError('The playback pool did not produce a player for feed item $index.');
      }

      _pooledPlayer = pooled;
      _handle = pooled is KernelPoolPlayerHandle ? pooled.handle : null;
      _setItemState(FeedItemState.playing);
    } catch (error) {
      MediaCoreLog.error(
        LogCategory.recovery,
        'feed item failed: ${source.uri}',
        error: error,
        fields: <String, Object?>{'index': index, 'pooled': true},
      );

      if (_index == index && !_disposed) {
        _setItemState(FeedItemState.error);
        _errorController.add(
          PlayerFailure(
            code: PlayerErrorCode.noPlayableStream,
            message: 'Feed item $index failed to play: $error',
            cause: error,
          ),
        );
      }
    }
  }

  /// Swipes to the next item.
  Future<void> next() => showIndex(_index + 1);

  /// Swipes to the previous item.
  Future<void> previous() => showIndex(_index - 1);

  /// Pauses the visible item.
  Future<void> pause() async {
    _setItemState(FeedItemState.paused);

    await (_handle?.pause() ?? _pooledPlayer?.pause());
  }

  /// Resumes the visible item.
  Future<void> play() async {
    await (_handle?.play() ?? _pooledPlayer?.play());

    if (!_disposed) {
      _setItemState(FeedItemState.playing);
    }
  }

  /// Volume of the visible item's player.
  Future<void> setVolume(double volume) =>
      _handle?.setVolume(volume) ?? _pooledPlayer?.setVolume(volume) ?? Future<void>.value();

  /// Mutes the visible item's player.
  Future<void> setMute(bool muted) =>
      _handle?.setMute(muted) ?? _pooledPlayer?.setMute(muted) ?? Future<void>.value();

  /// Playback state stream of the visible item's player.
  Stream<PlaybackState> get onPlaybackStateChanged =>
      _handle?.playbackStream ?? _pooledPlayer?.playbackStream ?? const Stream<PlaybackState>.empty();

  /// Releases the shared player and the feed.
  ///
  /// With a pool the players belong to the pool and are left alone: disposing a
  /// page must not tear down decoders another page is about to use.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    final handle = _handle;
    _handle = null;
    _pooledPlayer = null;

    // With a pool the handle is the pool's to take back: releasing it here
    // would return a player that another page is about to be shown on.
    if (handle != null && pool == null) {
      try {
        await kernel.release(handle.id);
      } catch (_) {
        // Best-effort release.
      }
    }

    await _indexController.close();
    await _stateController.close();
    await _errorController.close();
  }

  void _emitIndex(int index) {
    if (!_indexController.isClosed) {
      _indexController.add(index);
    }
  }

  void _setItemState(FeedItemState next) {
    if (_itemState == next) {
      return;
    }

    _itemState = next;

    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
