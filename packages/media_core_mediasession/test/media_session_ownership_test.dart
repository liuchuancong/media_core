import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core/testing/fake_player_adapter.dart';
import 'package:media_core/testing/test_player_factory.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

/// A driver with a platform handshake already done, and one player to publish.
Future<({MediaSessionDriver driver, MediaSessionHandler handler, FakePlayerAdapter adapter, PlayerHandle handle})>
_rig({String title = 'Song', String sourceId = 'song'}) async {
  final adapter = FakePlayerAdapter();
  final handle = PlayerHandle(
    player: TestPlayerFactory.player(1),
    adapter: adapter,
    registration: PlayerAdapterRegistration(
      id: 'fake',
      factory: TestPlayerFactory.fakeAdapterFactory(),
      capabilities: const FakePlayerAdapterBehavior().capabilities,
    ),
    adapterContext: TestPlayerFactory.context(),
    eventBus: PlayerEventBus(),
    options: const KernelOptions(),
  );
  final handler = MediaSessionHandler(
    onPlay: () async {},
    onPause: () async {},
    onSeek: (_) async {},
    onStop: () async {},
  );
  final driver = MediaSessionDriver(handler: handler);
  addTearDown(driver.dispose);

  await handle.initialize();
  await handle.open(
    PlayerSource(
      id: SourceId(sourceId),
      uri: Uri.parse('https://example.com/$sourceId.m4a'),
      protocol: SourceProtocol.https,
      format: SourceFormat.mp4,
      title: title,
    ),
  );

  return (driver: driver, handler: handler, adapter: adapter, handle: handle);
}

void main() {
  group('MediaSessionDriver transport phase', () {
    test('the phase the platform sees is the phase the transport is in', () async {
      final started = await _rig();
      final published = <PlaybackState>[];
      final subscription = started.handler.playbackState.listen(published.add);
      addTearDown(subscription.cancel);

      started.driver.setActive(started.handle);
      await pumpEventQueue();

      expect(published.last.processingState, AudioProcessingState.idle, reason: 'opened, never played');

      started.adapter.emitPlaying();
      await pumpEventQueue();
      expect(published.last.processingState, AudioProcessingState.ready);
      expect(published.last.playing, isTrue);

      started.adapter.emitBuffering(buffering: true);
      await pumpEventQueue();
      expect(
        published.last.processingState,
        AudioProcessingState.buffering,
        reason:
            'a stalled stream used to be published as ready, which is the one state the control bar must not lie about',
      );
      expect(published.last.playing, isTrue, reason: 'a stall short of data does not stop the transport');

      started.adapter.emitBuffering(buffering: false);
      started.adapter.emitPaused();
      await pumpEventQueue();
      expect(published.last.processingState, AudioProcessingState.ready);
      expect(published.last.playing, isFalse);

      started.adapter.emitStopped();
      await pumpEventQueue();
      expect(published.last.processingState, AudioProcessingState.idle);
    });

    test('a playhead at the end of the media is completed, not paused', () async {
      final started = await _rig();
      final published = <PlaybackState>[];
      final subscription = started.handler.playbackState.listen(published.add);
      addTearDown(subscription.cancel);

      started.driver.setActive(started.handle);
      started.adapter.emitPlaying();
      await pumpEventQueue();

      started.handle.playbackController.updateDuration(const Duration(minutes: 1));
      started.adapter.emitPosition(const Duration(minutes: 1));
      started.adapter.emitPaused();
      await pumpEventQueue();

      expect(published.last.processingState, AudioProcessingState.completed);
    });

    test('a phase change is never held back by the position window', () async {
      final started = await _rig();
      final published = <PlaybackState>[];
      final subscription = started.handler.playbackState.listen(published.add);
      addTearDown(subscription.cancel);

      started.driver.setActive(started.handle);
      started.adapter.emitPlaying();
      await pumpEventQueue();
      published.clear();

      // Same position, same duration, same speed: only the condition changed.
      started.adapter.emitBuffering(buffering: true);
      await pumpEventQueue();

      expect(published, hasLength(1), reason: 'the one thing the viewer is waiting for cannot be throttled');
      expect(published.last.processingState, AudioProcessingState.buffering);
    });
  });

  group('MediaSessionDriver surface ownership', () {
    test('activating before the platform handshake says so', () async {
      final driver = MediaSessionDriver();
      addTearDown(driver.dispose);

      final activation = await driver.activate(sessionId: 'cell-1', title: '房间1');

      expect(activation.held, isFalse);
      expect(activation.reason, MediaSessionRefusal.notInitialized);
      expect(driver.activeSessionId, isNull, reason: 'a refused activation must not have taken anything');
    });

    test('a disposed driver says it is gone, not that it never started', () async {
      final started = await _rig();
      await started.driver.dispose();

      final activation = await started.driver.activate(sessionId: 'cell-1', title: '房间1');

      expect(activation.held, isFalse);
      expect(
        activation.reason,
        MediaSessionRefusal.disposed,
        reason: 'a call that outlived its driver is the opposite bug from one that came early',
      );
      expect(started.driver.activeSessionId, isNull);
    });

    test('a second session takes the surface, and the first is named', () async {
      final started = await _rig();
      started.driver.setActive(started.handle);
      await pumpEventQueue();

      expect(started.driver.activeSessionId, 'player/${started.handle.id.value}');

      final activation = await started.driver.activate(sessionId: 'cell-2', title: '房间2');

      expect(activation.held, isTrue);
      expect(activation.previousOwnerSessionId, 'player/${started.handle.id.value}');
      expect(started.driver.activeSessionId, 'cell-2');
      expect(started.handler.mediaItem.value?.title, '房间2');
    });

    test('a session that lost the surface cannot rewrite it', () async {
      final started = await _rig();
      started.driver.setActive(started.handle);
      await started.driver.activate(sessionId: 'cell-2', title: '房间2');
      await pumpEventQueue();

      // The old player's late metadata callback — the multiview switch case.
      await started.driver.updateMetadata(sessionId: 'player/${started.handle.id.value}', title: '旧房间');
      await pumpEventQueue();

      expect(started.handler.mediaItem.value?.title, '房间2', reason: 'the control bar belongs to whoever holds it now');

      await started.driver.updateMetadata(sessionId: 'cell-2', title: '房间2 · 高清');
      await pumpEventQueue();

      expect(started.handler.mediaItem.value?.title, '房间2 · 高清');
    });

    test('a session that lost the surface cannot clear it either', () async {
      final started = await _rig();
      started.driver.setActive(started.handle);
      await started.driver.activate(sessionId: 'cell-2', title: '房间2');
      await pumpEventQueue();

      await started.driver.deactivate('player/${started.handle.id.value}');
      await pumpEventQueue();

      expect(started.driver.activeSessionId, 'cell-2');
      expect(started.handler.mediaItem.value, isNotNull, reason: 'the new session is still being shown');
    });

    test('the owner gives the surface back and the notification goes with it', () async {
      final started = await _rig();
      await started.driver.activate(sessionId: 'cell-1', title: '房间1');
      started.adapter.emitPlaying();
      await pumpEventQueue();

      await started.driver.deactivate('cell-1');
      await pumpEventQueue();

      expect(started.driver.activeSessionId, isNull);
      expect(started.handler.mediaItem.value, isNull);
      expect(started.handler.playbackState.value.processingState, AudioProcessingState.idle);
      expect(
        started.handle.playback.isPlaying,
        isTrue,
        reason: 'giving up a surface is not the viewer pressing stop: the player keeps playing',
      );
    });

    test('the kernel releasing the active player releases the surface', () async {
      final started = await _rig();
      started.driver.setActive(started.handle);
      await pumpEventQueue();

      started.driver.setActive(null);
      await pumpEventQueue();

      expect(started.driver.activeSessionId, isNull);
      expect(started.handler.mediaItem.value, isNull);
    });

    test('disposing the driver takes the media session with it', () async {
      final started = await _rig();
      final handler = started.handler;
      started.driver.setActive(started.handle);
      await pumpEventQueue();

      await started.driver.dispose();

      expect(handler.mediaItem.value, isNull, reason: 'a session nobody owns must not stay on the lock screen');
      expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    });

    test('one activation per session, and the item keeps the source it came from', () async {
      final started = await _rig(title: '主播8891 的房间');
      started.driver.setActive(started.handle);
      await started.driver.activate(sessionId: 'cell-2', title: '房间2');
      await pumpEventQueue();

      final item = started.handler.mediaItem.value!;

      expect(item.title, '房间2');
      expect(item.id, 'song', reason: 'the item is still the source the player opened, named by the session');
    });
  });
}
