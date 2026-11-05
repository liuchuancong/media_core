import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_activity/media_core_media_activity.dart';

import 'src/fake_media_activity_platform.dart';

void main() {
  const session = MediaActivityMetadata(sessionId: 's1', title: 'Song', artist: 'Artist');
  const playing = MediaActivityContentState(
    currentLyric: 'line 1',
    isPlaying: true,
    positionMs: 1000,
  );

  group('MediaActivityCoordinator.onTrackChanged', () {
    test('starts the activity and seeds Now Playing', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );

      await coordinator.onTrackChanged(session, playing);

      expect(platform.log, contains('start:s1'));
      expect(platform.startedMetadata.single, session);
      expect(platform.startedStates.single.lyricRevision, 1);

      final nowPlaying = platform.nowPlayingUpdates.single;
      expect(nowPlaying.title, 'Song');
      expect(nowPlaying.artist, 'Artist');
      expect(nowPlaying.positionMs, 1000);
    });

    test('replaces a different session with stop semantics', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      const next = MediaActivityMetadata(sessionId: 's2', title: 'Next');
      await coordinator.onTrackChanged(next, playing);

      final startOfS2 = platform.log.indexOf('start:s2');
      expect(platform.log.indexOf('end:s1'), lessThan(startOfS2));
      expect(
        platform.log.indexOf('clearNowPlaying'),
        lessThan(startOfS2),
        reason: 'track switch is a stop for Now Playing, then the new start',
      );
    });

    test('the same live session only refreshes content (recovery)', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);
      platform.log.clear();

      final refreshed = playing.copyWith(positionMs: 5000);
      await coordinator.onTrackChanged(session, refreshed);

      expect(
        platform.log.where((c) => c.startsWith('start:')),
        isEmpty,
        reason: 'an alive same-session activity must not be recreated',
      );
      expect(platform.updatedStates.single.positionMs, 5000);
    });
  });

  group('MediaActivityCoordinator.onLyricChanged', () {
    test('pushes the new lines while playing', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onLyricChanged(currentLyric: 'line 2', nextLyric: 'line 3');

      final pushed = platform.updatedStates.single;
      expect(pushed.currentLyric, 'line 2');
      expect(pushed.nextLyric, 'line 3');
      expect(pushed.positionMs, 1000, reason: 'lyric events carry no position change');
    });

    test('keeps the last lyric while paused', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing.copyWith(isPlaying: false));
      platform.log.clear();

      await coordinator.onLyricChanged(currentLyric: 'line 2');

      expect(platform.updatedStates, isEmpty);
    });

    test('skips identical lines (replayed events cost nothing)', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);
      platform.log.clear();

      await coordinator.onLyricChanged(currentLyric: 'line 1');

      expect(platform.updatedStates, isEmpty);
    });
  });

  group('MediaActivityCoordinator.onPlaybackChanged / onSeekCompleted', () {
    test('pushes play-state and rate changes', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onPlaybackChanged(isPlaying: false, positionMs: 2500);

      final pushed = platform.updatedStates.single;
      expect(pushed.isPlaying, isFalse);
      expect(pushed.positionMs, 2500);
      expect(pushed.playbackRate, 1.0, reason: 'rate unchanged keeps the previous value');
    });

    test('pushes a seek as its own event', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onSeekCompleted(positionMs: 42_000);

      expect(platform.updatedStates.single.positionMs, 42_000);
    });

    test('ignores a seek onto the current position', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);
      platform.log.clear();

      await coordinator.onSeekCompleted(positionMs: 1000);

      expect(platform.updatedStates, isEmpty);
    });

    test('ignores events before any track started', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );

      await coordinator.onLyricChanged(currentLyric: 'line 1');
      await coordinator.onPlaybackChanged(isPlaying: false, positionMs: 0);
      await coordinator.onSeekCompleted(positionMs: 5);

      expect(platform.log, isEmpty);
    });
  });

  group('MediaActivityCoordinator merged artwork/metadata', () {
    test('artwork lands in Now Playing now, in the activity after a flush', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onArtworkChanged('artwork_2');

      expect(platform.nowPlayingUpdates.last.artworkKey, 'artwork_2');
      expect(platform.startedStates, hasLength(1), reason: 'no recreate yet');

      await coordinator.flushMerged();

      expect(platform.log.where((c) => c == 'end:s1'), hasLength(1));
      expect(platform.log.where((c) => c == 'start:s1'), hasLength(2));
      expect(platform.startedMetadata.last.artworkKey, 'artwork_2');
    });

    test('metadata text lands in Now Playing now, in the activity after a flush', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onMetadataChanged(title: 'Song (Live)', artist: 'Artist feat. X');

      expect(platform.nowPlayingUpdates.last.title, 'Song (Live)');
      expect(platform.nowPlayingUpdates.last.artist, 'Artist feat. X');

      await coordinator.flushMerged();

      expect(platform.startedMetadata.last.title, 'Song (Live)');
      expect(platform.startedMetadata.last.artist, 'Artist feat. X');
    });

    test('flushMerged without a pending change is a no-op', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);
      platform.log.clear();

      await coordinator.flushMerged();

      expect(platform.log, isEmpty);
    });

    test('flushMerged with nothing running is a no-op', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );

      // No track ever started: nothing pending, nothing alive.
      await coordinator.flushMerged();

      expect(platform.log, isEmpty);
    });

    test('identical artwork or metadata changes change nothing', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      const withArtwork = MediaActivityMetadata(
        sessionId: 's1',
        title: 'Song',
        artist: 'Artist',
        artworkKey: 'artwork_1',
      );
      await coordinator.onTrackChanged(withArtwork, playing);
      platform.log.clear();
      platform.nowPlayingUpdates.clear();

      await coordinator.onArtworkChanged('artwork_1');
      await coordinator.onMetadataChanged(title: 'Song');

      expect(platform.nowPlayingUpdates, isEmpty);
      expect(platform.log, isEmpty);
    });
  });

  group('MediaActivityCoordinator.onSessionEnded', () {
    test('ends the activity and clears Now Playing', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);

      await coordinator.onSessionEnded();

      expect(platform.log, contains('end:s1'));
      expect(platform.log, contains('clearNowPlaying'));
    });

    test('events after the session ended stay quiet', () async {
      final platform = FakeMediaActivityPlatform();
      final coordinator = MediaActivityCoordinator(
        controller: MediaActivityController(platform: platform),
      );
      await coordinator.onTrackChanged(session, playing);
      await coordinator.onSessionEnded();
      platform.log.clear();

      await coordinator.onLyricChanged(currentLyric: 'line 2');
      await coordinator.onPlaybackChanged(isPlaying: false, positionMs: 0);
      await coordinator.onSeekCompleted(positionMs: 1);
      await coordinator.flushMerged();

      expect(platform.log, isEmpty);
    });
  });
}
