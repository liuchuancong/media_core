import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_activity/media_core_media_activity.dart';

void main() {
  const policy = MediaActivitySyncPolicy();

  group('MediaActivitySyncPolicy', () {
    test('skips everything while no activity is active', () {
      for (final reason in MediaActivityUpdateReason.values) {
        expect(
          policy.decide(reason, activityActive: false),
          MediaActivitySyncDecision.skip,
          reason: '$reason must not produce a phantom update on a dead activity',
        );
      }
    });

    test('pushes terminal and viewer-visible events immediately', () {
      const immediate = [
        MediaActivityUpdateReason.trackChanged,
        MediaActivityUpdateReason.lyricChanged,
        MediaActivityUpdateReason.playbackChanged,
        MediaActivityUpdateReason.seekCompleted,
        MediaActivityUpdateReason.recovery,
      ];

      for (final reason in immediate) {
        expect(
          policy.decide(reason, activityActive: true),
          MediaActivitySyncDecision.immediate,
          reason: '$reason is an event the viewer is waiting on',
        );
      }
    });

    test('folds cosmetic changes into the next push', () {
      const merged = [
        MediaActivityUpdateReason.artworkChanged,
        MediaActivityUpdateReason.metadataChanged,
      ];

      for (final reason in merged) {
        expect(
          policy.decide(reason, activityActive: true),
          MediaActivitySyncDecision.merged,
          reason: '$reason is cosmetic and must not spend its own recreate',
        );
      }
    });

    test('is a pure object: same inputs, same decisions', () {
      final first = policy.decide(MediaActivityUpdateReason.lyricChanged, activityActive: true);
      final second = policy.decide(MediaActivityUpdateReason.lyricChanged, activityActive: true);

      expect(first, second);
    });
  });

  group('NoopMediaActivityPlatform', () {
    const platform = NoopMediaActivityPlatform();

    test('reports unsupported capabilities', () async {
      expect(await platform.capabilities(), MediaActivityCapabilitiesReport.unsupported);
      expect(await platform.capabilities().then((c) => c.usable), isFalse);
    });

    test('refuses every lifecycle call with a stable code', () async {
      const metadata = MediaActivityMetadata(sessionId: 's1', title: 'Song');
      const state = MediaActivityContentState(
        currentLyric: 'line',
        isPlaying: true,
        positionMs: 0,
      );

      final start = await platform.startActivity(metadata: metadata, initialState: state);
      expect(start.ok, isFalse);
      expect(start.errorCode, 'activity_not_supported');

      final update = await platform.updateActivity(sessionId: 's1', state: state);
      expect(update.ok, isFalse);

      final end = await platform.endActivity(sessionId: 's1');
      expect(end.ok, isFalse);

      final status = await platform.activityStatus(sessionId: 's1');
      expect(status.isActive, isFalse);
      expect(status.isDismissed, isFalse);
    });

    test('accepts the rest as silent no-ops', () async {
      await platform.endAllActivities();
      await platform.clearNowPlaying();
      await platform.updateNowPlaying(const NowPlayingUpdate(title: 'Song'));
      await platform.configureRemoteCommands(
        playPauseEnabled: true,
        nextTrackEnabled: false,
        previousTrackEnabled: false,
        seekEnabled: false,
      );
      platform.setCommandSink(null);

      // Nothing threw; that is the contract (spec §13.3).
      expect(true, isTrue);
    });
  });

  group('PlatformMediaActivity.resolve', () {
    test('falls back to the no-op off iOS', () {
      // The test runtime is the host OS (Windows); the resolver must not
      // throw anywhere and must hand back the degradation path.
      final platform = PlatformMediaActivity.resolve();

      expect(platform, isA<NoopMediaActivityPlatform>());
    });
  });
}
