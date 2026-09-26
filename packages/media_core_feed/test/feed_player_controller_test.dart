import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_feed/media_core_feed.dart';

final class _PoolHandle implements PoolPlayerHandle {
  _PoolHandle(this.id);

  @override
  final String id;

  String? openedSource;
  bool isPlaying = false;
  int openCount = 0;
  double volume = 1;

  @override
  bool isDisposed = false;

  @override
  Future<void> open(PlayerSource source, {bool autoPlay = false}) async {
    openedSource = source.id.value;
    openCount++;
    isPlaying = autoPlay;
  }

  @override
  Future<void> play() async => isPlaying = true;

  @override
  Future<void> pause() async => isPlaying = false;

  @override
  Future<void> recycle() async {}

  @override
  Future<void> setVolume(double value) async => volume = value;

  @override
  Future<void> setMute(bool muted) async {}

  @override
  Stream<PlaybackState> get playbackStream => const Stream<PlaybackState>.empty();
}

final class _PoolHost implements PoolPlayerHost {
  final List<_PoolHandle> handles = <_PoolHandle>[];

  @override
  Future<PoolPlayerHandle> acquire() async {
    final handle = _PoolHandle('feed-pool${handles.length}');
    handles.add(handle);
    return handle;
  }

  @override
  Future<void> release(PoolPlayerHandle handle) async {}

  @override
  Future<void> disposeHandle(PoolPlayerHandle handle) async {}
}

PlayerSource _source(String id) => PlayerSource(
  id: SourceId(id),
  uri: Uri.parse('https://example.com/$id.m3u8'),
  protocol: SourceProtocol.https,
  format: SourceFormat.mpegTs,
);

List<PlayerSource> _items(int count) => List<PlayerSource>.generate(count, (index) => _source('item$index'));

void main() {
  late _PoolHost host;
  late PlaybackPoolOrchestrator pool;
  late FeedPlayerController controller;

  setUp(() {
    host = _PoolHost();
    pool = PlaybackPoolOrchestrator(host: host, config: FeedConfig.recommendedPoolConfig);
    // A kernel with no backends: the pooled path never asks it for a player,
    // which is exactly what these tests are checking.
    controller = FeedPlayerController(PlayerKernel(), pool: pool);
  });

  tearDown(() async {
    await controller.dispose();
    await pool.dispose();
  });

  group('FeedPlayerController with a pool', () {
    test('the pool opens the visible item and warms the next one', () async {
      await controller.load(_items(4));

      expect(host.handles.first.openedSource, 'item0');
      expect(host.handles.first.isPlaying, isTrue);
      expect(host.handles.length, 2, reason: 'the next item is held open, not merely queued');
      expect(host.handles[1].openedSource, 'item1');
      expect(host.handles[1].isPlaying, isFalse);
      expect(controller.itemState, FeedItemState.playing);
    });

    test('a swipe takes the warm player instead of opening a cold one', () async {
      await controller.load(_items(4));
      final warmOpens = host.handles[1].openCount;

      await controller.next();

      expect(controller.currentIndex, 1);
      expect(host.handles[1].openCount, warmOpens, reason: 'the warm player is reused');
      expect(host.handles[1].isPlaying, isTrue);
    });

    test('swiping back also lands on a warm player', () async {
      await controller.load(_items(4), initialIndex: 2);
      final before = host.acquireCount2();

      await controller.previous();

      expect(controller.currentIndex, 1);
      expect(host.acquireCount2(), lessThanOrEqualTo(before + 1));
    });

    test('the feed exposes the pooled player for the visible item', () async {
      await controller.load(_items(4));

      expect(controller.pooledPlayer?.id, host.handles.first.id);
      expect(controller.handle, isNull, reason: 'this host does not pool kernel handles');
    });

    test('volume reaches the pooled player', () async {
      await controller.load(_items(4));

      await controller.setVolume(0.3);

      expect(host.handles.first.volume, 0.3);
    });

    test('disposing the feed leaves the pool its players', () async {
      await controller.load(_items(4));
      final pooledHandle = controller.pooledPlayer;

      await controller.dispose();

      expect(pooledHandle!.isDisposed, isFalse, reason: 'the pool still owns that player');
    });

    test('an empty feed plans nothing', () async {
      await controller.load(const <PlayerSource>[]);

      expect(controller.currentIndex, -1);
      expect(host.handles, isEmpty);
    });
  });

  group('FeedConfig', () {
    test('recommends a bounded, reusing pool', () {
      expect(FeedConfig.recommendedPoolConfig.reuseIdlePlayers, isTrue);
      expect(FeedConfig.recommendedPoolConfig.maxActivePlayers, 1);
      expect(FeedConfig.recommendedPoolConfig.preloadCount, 1);
      expect(FeedConfig.recommendedPoolConfig.warmSize, 3);
    });
  });
}

extension on _PoolHost {
  int acquireCount2() => handles.length;
}
