import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_activity/media_core_media_activity.dart';
import 'package:media_core_media_activity_example/demo_session.dart';

// The fake platform lives with the plugin's own test suite; the workspace
// layout makes the relative path stable for this in-repo example.
import '../../test/src/fake_media_activity_platform.dart';

void main() {
  group('DemoPlaybackSession', () {
    test('reports an unusable device through the capability line', () async {
      final session = DemoPlaybackSession(
        platform: FakeMediaActivityPlatform(report: MediaActivityCapabilitiesReport.unsupported),
      );

      // The probe answer arrives asynchronously; give the microtask a turn.
      await Future<void>.delayed(Duration.zero);

      expect(session.usable, isFalse);
      expect(session.capabilityText, contains('不支持'));

      await session.start();
      expect(session.hasActiveActivity, isFalse, reason: 'feature-off must stay silent');

      await session.dispose();
    });

    test('start announces the track and seeds the lyric engine state', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);

      await session.start();

      expect(session.hasActiveActivity, isTrue);
      expect(session.isPlaying, isTrue);
      expect(platform.startedMetadata.single.title, '夜航星');
      expect(platform.nowPlayingUpdates.single.title, '夜航星');
      expect(platform.startedStates.single.currentLyric, '夜色把站台淹没');
      expect(platform.startedStates.single.lyricRevision, 1);

      await session.dispose();
    });

    test('nextLyric pushes the new line and a preview of the next', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      await session.nextLyric();

      final pushed = platform.updatedStates.single;
      expect(pushed.currentLyric, '车灯划开了沉默');
      expect(pushed.nextLyric, '你说星星在坠落');

      await session.dispose();
    });

    test('toggle flips the play state through playbackChanged', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      await session.toggle();

      expect(session.isPlaying, isFalse);
      expect(platform.updatedStates.single.isPlaying, isFalse);
      expect(platform.updatedStates.single.playbackRate, 0.0);

      await session.dispose();
    });

    test('skipForward lands as a seek event', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      await session.skipForward();

      expect(session.positionMs, 30_000);
      expect(platform.updatedStates.single.positionMs, 30_000);

      await session.dispose();
    });

    test('nextTrack replaces the session with the other demo track', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      await session.nextTrack();

      final started = platform.startedMetadata;
      expect(started, hasLength(2));
      expect(started.last.title, '南方车站');
      expect(started.last.sessionId, isNot(started.first.sessionId));
      expect(platform.log.indexOf('end:${started.first.sessionId}'), lessThan(platform.log.indexOf('start:${started.last.sessionId}')));

      await session.dispose();
    });

    test('stop ends the activity and clears Now Playing', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      await session.stop();

      expect(session.hasActiveActivity, isFalse);
      expect(platform.log, contains('clearNowPlaying'));

      await session.dispose();
    });

    test('lock-screen commands route back and flip the session', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      // The controller registered itself on the platform; commands arriving
      // there must reach the session, which is the host sink.
      platform.sink!.onPause('demo');
      expect(session.isPlaying, isFalse);
      expect(session.commands.last, '锁屏指令：暂停');

      platform.sink!.onPlay('demo');
      expect(session.isPlaying, isTrue);
      expect(session.commands.last, '锁屏指令：播放');

      platform.sink!.onSeek('demo', 90_000);
      expect(session.positionMs, 90_000);
      expect(platform.updatedStates.last.positionMs, 90_000);

      platform.sink!.onNextTrack('demo');
      expect(session.trackTitle, '南方车站');

      await session.dispose();
    });

    test('a dismissal notification stops the lyric engine', () async {
      final platform = FakeMediaActivityPlatform();
      final session = DemoPlaybackSession(platform: platform);
      await session.start();

      platform.sink!.onActivityDismissed('demo-track-1');

      expect(session.isPlaying, isFalse);
      expect(session.commands.last, contains('移除了 Live Activity'));

      await session.dispose();
    });
  });
}
