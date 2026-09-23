import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/adapter/player_adapter_capabilities.dart';
import 'package:media_core/live/live_playback_models.dart';
import 'package:media_core/live/live_watchdogs.dart';

/// Minutes are seconds here: the deadlines are compressed so the tests run
/// in milliseconds, the relationships between them are unchanged.
const Duration _deadline = Duration(milliseconds: 60);

const PlayerAdapterCapabilities _frameProgressAdapter = PlayerAdapterCapabilities(
  supportsLive: true,
  supportsVideoFrameProgress: true,
  supportsVideoSizeChanged: true,
);

LiveWatchdogs _watchdogs(List<LiveStallKind> stalls) {
  final watchdogs = LiveWatchdogs(
    sourceReadyTimeout: _deadline,
    bufferingStallTimeout: _deadline,
    videoFrameStallTimeout: _deadline,
    unexpectedPauseGrace: Duration.zero,
    unexpectedPauseFailureGrace: Duration.zero,
  );
  watchdogs.onStall = stalls.add;
  return watchdogs;
}

/// Waits longer than the compressed deadline.
Future<void> _afterDeadline() => Future<void>.delayed(_deadline * 3);

/// What `LivePlaybackController.close()` does to the bundle.
void _retire(LiveWatchdogs watchdogs) {
  watchdogs.cancelAll();
  watchdogs.updateCapabilities(null);
}

void main() {
  group('source ready watchdog', () {
    test('fires when an opened source never reports playing', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.armSourceReady();

      await _afterDeadline();

      expect(stalls, <LiveStallKind>[LiveStallKind.sourceReadyTimeout]);
      watchdogs.dispose();
    });

    test('still fires for the second session of a reused bundle', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      // First session plays and is retired.
      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);
      _retire(watchdogs);

      // Second session opens and never starts playing.
      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.armSourceReady();

      await _afterDeadline();

      expect(stalls, <LiveStallKind>[LiveStallKind.sourceReadyTimeout]);
      watchdogs.dispose();
    });
  });

  group('video frame watchdog', () {
    test('arms while playing and stays fed by frame heartbeats', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);

      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(_deadline ~/ 2);
        watchdogs.onFrameProgress();
      }

      expect(stalls, isEmpty);
      watchdogs.dispose();
    });

    test('reports a stall when no frame arrives', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);

      await _afterDeadline();

      expect(stalls, <LiveStallKind>[LiveStallKind.videoFrameStallTimeout]);
      watchdogs.dispose();
    });

    test('does not arm before a source has started playing', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      // A retired session leaves no observations behind, so binding the
      // next adapter cannot arm the deadline on the previous session's
      // playing state.
      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);
      _retire(watchdogs);

      watchdogs.updateCapabilities(_frameProgressAdapter);

      await _afterDeadline();

      expect(stalls, isEmpty);
      watchdogs.dispose();
    });

    test('is disabled for adapters without the frame-progress capability', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.updateCapabilities(const PlayerAdapterCapabilities(supportsLive: true));
      watchdogs.onPlayingChanged(true, fromUserIntent: false);

      await _afterDeadline();

      expect(stalls, isEmpty);
      watchdogs.dispose();
    });
  });

  group('audio-only sessions', () {
    test('never report a frame stall, even on a capable adapter', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.setVideoExpected(false);
      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);

      await _afterDeadline();

      expect(stalls, isEmpty);
      watchdogs.dispose();
    });

    test('arm again when video is expected once more', () async {
      final stalls = <LiveStallKind>[];
      final watchdogs = _watchdogs(stalls);

      watchdogs.setVideoExpected(false);
      watchdogs.updateCapabilities(_frameProgressAdapter);
      watchdogs.onPlayingChanged(true, fromUserIntent: false);

      await _afterDeadline();
      expect(stalls, isEmpty);

      // Restoring video re-arms the deadline for the running session.
      watchdogs.setVideoExpected(true);

      await _afterDeadline();

      expect(stalls, <LiveStallKind>[LiveStallKind.videoFrameStallTimeout]);
      watchdogs.dispose();
    });
  });
}
