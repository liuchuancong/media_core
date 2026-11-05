import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_activity/media_core_media_activity.dart';

import 'src/fake_media_activity_platform.dart';

void main() {
  const metadata = MediaActivityMetadata(sessionId: 's1', title: 'Song');
  const state = MediaActivityContentState(
    currentLyric: 'line 1',
    isPlaying: true,
    positionMs: 1000,
  );

  group('MediaActivityController.start', () {
    test('refuses without touching the channel on an unsupported device', () async {
      final platform = FakeMediaActivityPlatform(report: MediaActivityCapabilitiesReport.unsupported);
      final controller = MediaActivityController(platform: platform);

      expect(await controller.start(metadata: metadata, state: state), isFalse);
      expect(platform.log, ['capabilities']);
      expect(controller.activeMetadata, isNull);
    });

    test('caches the capability report across calls', () async {
      final platform = FakeMediaActivityPlatform(report: MediaActivityCapabilitiesReport.unsupported);
      final controller = MediaActivityController(platform: platform);

      await controller.start(metadata: metadata, state: state);
      await controller.start(metadata: metadata, state: state);
      await controller.capabilities();

      expect(
        platform.log.where((c) => c == 'capabilities'),
        hasLength(1),
        reason: 'the answer cannot change mid-session; never ask twice',
      );
    });

    test('starts and stamps the first lyric revision', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);

      expect(await controller.start(metadata: metadata, state: state), isTrue);
      expect(platform.startedMetadata.single, metadata);
      expect(platform.startedStates.single.lyricRevision, 1);
      expect(controller.activeMetadata, metadata);
    });

    test('refuses a duplicate session id as a host bug', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      final again = await controller.start(metadata: metadata, state: state);

      expect(again, isFalse);
      expect(platform.startedMetadata, hasLength(1));
      expect(
        platform.log.where((c) => c.startsWith('start:')),
        hasLength(1),
        reason: 'the duplicate must never reach the native limit',
      );
    });

    test('replaces the previous session before starting the next', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      const next = MediaActivityMetadata(sessionId: 's2', title: 'Next');
      await controller.start(metadata: next, state: state);

      expect(platform.log.indexOf('end:s1'), lessThan(platform.log.indexOf('start:s2')));
      expect(controller.activeMetadata, next);
    });

    test('keeps the ledger clean when the native side refuses', () async {
      final platform = FakeMediaActivityPlatform()
        ..startResult = const MediaActivityCallResult.failed('activity_limit_reached');
      final controller = MediaActivityController(platform: platform);

      expect(await controller.start(metadata: metadata, state: state), isFalse);
      expect(controller.activeMetadata, isNull);

      // A later start is a clean create, not an update into a ghost.
      platform.startResult = const MediaActivityCallResult.ok();
      expect(await controller.start(metadata: metadata, state: state), isTrue);
      expect(platform.startedMetadata, hasLength(2));
    });
  });

  group('MediaActivityController.update', () {
    test('refuses when nothing is active', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);

      expect(await controller.update(state), isFalse);
      expect(platform.updatedStates, isEmpty);
    });

    test('dedupes an identical push without a channel round trip', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      final seeded = controller.currentState!;
      expect(await controller.update(seeded), isFalse);
      expect(platform.updatedStates, isEmpty);
    });

    test('pushes changes with an increasing lyric revision', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      final changed = controller.currentState!.copyWith(currentLyric: 'line 2');
      expect(await controller.update(changed), isTrue);

      final pushed = platform.updatedStates.single;
      expect(pushed.currentLyric, 'line 2');
      expect(pushed.lyricRevision, 2, reason: 'seed stamped 1, the change stamps 2');
      expect(controller.currentState, pushed);
    });

    test('keeps the last good ledger when the native side refuses', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      platform.updateResult = const MediaActivityCallResult.failed('activity_not_found');
      final changed = controller.currentState!.copyWith(currentLyric: 'line 2');

      expect(await controller.update(changed), isFalse);
      expect(controller.currentState!.currentLyric, 'line 1');
    });
  });

  group('MediaActivityController.end', () {
    test('ends the activity and drops the ledger', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      await controller.end();

      expect(platform.log, contains('end:s1'));
      expect(platform.log, isNot(contains('clearNowPlaying')));
      expect(controller.activeMetadata, isNull);
      expect(controller.currentState, isNull);
    });

    test('clears Now Playing too when asked (stop semantics)', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      await controller.end(clearNowPlaying: true);

      expect(platform.log.indexOf('end:s1'), lessThan(platform.log.indexOf('clearNowPlaying')));
    });

    test('endAll tears everything down', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      await controller.endAll();

      expect(platform.log, contains('endAll'));
      expect(platform.log, contains('clearNowPlaying'));
      expect(controller.activeMetadata, isNull);
    });

    test('dispose tears down and turns later calls into no-ops', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      await controller.dispose();

      expect(controller.activeMetadata, isNull);
      expect(await controller.start(metadata: metadata, state: state), isFalse);
      expect(await controller.update(state), isFalse);
      expect(await controller.isActive(), isFalse);
      expect(
        platform.startedMetadata,
        hasLength(1),
        reason: 'a late event after dispose must never reach the platform',
      );
    });
  });

  group('MediaActivityController.isActive', () {
    test('reports the native status while alive', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      await controller.start(metadata: metadata, state: state);

      expect(await controller.isActive(), isTrue);
      expect(platform.log.last, 'status:s1');
    });

    test('reports the dismissal once and forgets the ghost', () async {
      final platform = FakeMediaActivityPlatform()
        ..status = const MediaActivityStatus(isActive: false, isDismissed: true);
      final controller = MediaActivityController(platform: platform);
      final sink = RecordingCommandSink();
      await controller.start(metadata: metadata, state: state);
      controller.commandSink = sink;

      expect(await controller.isActive(), isFalse);
      expect(sink.log, ['dismissed:s1']);
      expect(controller.activeMetadata, isNull);

      // The next check must not replay the dismissal.
      await controller.isActive();
      expect(sink.log, hasLength(1));
    });
  });

  group('MediaActivityController command routing', () {
    test('registers itself as the platform command sink', () {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);

      expect(platform.sink, same(controller));
    });

    test('forwards every command to the host sink', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      final sink = RecordingCommandSink();
      controller.commandSink = sink;

      platform.sink!.onPlay('p1');
      platform.sink!.onPause('p1');
      platform.sink!.onTogglePlayPause('p1');
      platform.sink!.onNextTrack('p1');
      platform.sink!.onPreviousTrack('p1');
      platform.sink!.onSeek('p1', 5000);
      platform.sink!.onActivityDismissed('s9');

      expect(sink.log, [
        'play:p1',
        'pause:p1',
        'toggle:p1',
        'next:p1',
        'previous:p1',
        'seek:p1@5000',
        'dismissed:s9',
      ]);
    });

    test('survives commands with no host sink attached', () {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);

      // commandSink is null; every callback must no-op, not throw.
      platform.sink!.onPlay('');
      platform.sink!.onActivityDismissed('gone');

      expect(controller.activeMetadata, isNull);
    });
  });

  group('MediaActivityController.updateNowPlaying', () {
    test('passes the payload through untouched', () async {
      final platform = FakeMediaActivityPlatform();
      final controller = MediaActivityController(platform: platform);
      const update = NowPlayingUpdate(title: 'Live', isLive: true);

      await controller.updateNowPlaying(update);

      expect(platform.nowPlayingUpdates.single, same(update));
    });
  });
}
