import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

/// A driver with a platform handler behind it, installed as this process's surfaces.
({MediaSessionDriver driver, MediaSessionHandler handler}) _installed() {
  final handler = MediaSessionHandler(
    onPlay: () async {},
    onPause: () async {},
    onSeek: (_) async {},
    onStop: () async {},
  );
  final driver = MediaSessionDriver(handler: handler);

  MediaSessionBootstrap.install(driver);
  addTearDown(MediaSessionBootstrap.disable);

  return (driver: driver, handler: handler);
}

void main() {
  tearDown(() async {
    if (MediaSessionBootstrap.enabled) {
      await MediaSessionBootstrap.disable();
    }
  });

  group('MediaSessionSurfaces', () {
    test('a host with no surfaces enabled is refused, not left a null to ignore', () async {
      expect(MediaSessionBootstrap.enabled, isFalse);

      final activation = await MediaSessionSurfaces.activate(sessionId: 'wall/cell-1', title: '房间1');

      expect(activation.held, isFalse);
      expect(
        activation.reason,
        MediaSessionRefusal.notEnabled,
        reason: 'the null from `MediaSessionBootstrap.current` is the exact thing a host overlooks, '
            'and overlooking it is how a player reports background playback the device never provided',
      );
      expect(MediaSessionSurfaces.activeSessionId, isNull);
      expect(MediaSessionSurfaces.driver, isNull);

      // The two void calls have nothing to act on, and must not throw about it.
      await MediaSessionSurfaces.updateMetadata(sessionId: 'wall/cell-1', title: '房间1 · 00:12');
      await MediaSessionSurfaces.deactivate('wall/cell-1');
    });

    test('the facade holds the named session and names whoever it took the bar from', () async {
      final started = _installed();

      final first = await MediaSessionSurfaces.activate(sessionId: 'wall/cell-1', title: '房间1');

      expect(first.held, isTrue);
      expect(MediaSessionSurfaces.activeSessionId, 'wall/cell-1');
      expect(started.handler.mediaItem.value?.title, '房间1');
      expect(
        identical(MediaSessionSurfaces.driver, started.driver),
        isTrue,
        reason: 'the same one driver the kernel uses — two of them would fight over one notification',
      );

      final second = await MediaSessionSurfaces.activate(sessionId: 'wall/cell-2', title: '房间2');

      expect(second.previousOwnerSessionId, 'wall/cell-1', reason: 'the loser cannot see its own loss from its side');
      expect(MediaSessionSurfaces.activeSessionId, 'wall/cell-2');

      await MediaSessionSurfaces.deactivate('wall/cell-1');
      expect(
        MediaSessionSurfaces.activeSessionId,
        'wall/cell-2',
        reason: 'giving up a surface you no longer hold gives up nothing',
      );

      await MediaSessionSurfaces.deactivate('wall/cell-2');
      await pumpEventQueue();

      expect(MediaSessionSurfaces.activeSessionId, isNull);
      expect(started.handler.mediaItem.value, isNull, reason: 'the bar goes with the last owner, as it must');
    });

    test('a stale session cannot rewrite the bar through the facade either', () async {
      final started = _installed();
      await MediaSessionSurfaces.activate(sessionId: 'wall/cell-2', title: '房间2');
      await pumpEventQueue();

      await MediaSessionSurfaces.updateMetadata(sessionId: 'wall/cell-1', title: '旧房间');
      await pumpEventQueue();

      expect(
        started.handler.mediaItem.value?.title,
        '房间2',
        reason: 'the guard belongs to the surface, not to the door used to reach it',
      );

      await MediaSessionSurfaces.updateMetadata(sessionId: 'wall/cell-2', title: '房间2 · 高清');
      await pumpEventQueue();

      expect(started.handler.mediaItem.value?.title, '房间2 · 高清');
    });

    test('an activation before the platform handshake still says it came too early', () async {
      // A driver installed but never initialized: the surfaces exist, the platform
      // handshake has not run. `notEnabled` and `notInitialized` are different
      // answers and the host waits for one of them.
      final driver = MediaSessionDriver();
      MediaSessionBootstrap.install(driver);

      final activation = await MediaSessionSurfaces.activate(sessionId: 'wall/cell-1', title: '房间1');

      expect(activation.held, isFalse);
      expect(activation.reason, MediaSessionRefusal.notInitialized);

      await MediaSessionBootstrap.disable();
    });
  });
}
