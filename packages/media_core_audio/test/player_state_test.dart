import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_audio/media_core_audio.dart';

final class _LyricSource extends MusicSource {
  @override
  String get id => 'test';

  @override
  String get name => 'Test';

  @override
  Future<TrackSource> resolveTrackSource(MusicTrack track, {MusicQuality? quality}) async {
    return TrackSource(uri: Uri.parse('https://example.com/${track.id}.mp3'));
  }

  @override
  Future<MusicLyricPayload?> resolveLyric(MusicTrack track) async {
    return const MusicLyricPayload(lyric: '[00:01.00]one\n[00:02.00]two');
  }
}

void main() {
  test('lyric offset is published and applied to the loaded lyric', () async {
    final player = AudioPlaybackController(
      PlayerKernel(),
      registry: MusicSourceRegistry(<MusicSource>[_LyricSource()]),
    );
    final states = <AudioPlaybackState>[];
    final subscription = player.stateStream.listen(states.add);

    try {
      await player.setQueue(<MusicTrack>[
        const MusicTrack(id: 'song', sourceId: 'test', title: 'Song'),
      ], autoPlay: false);

      player.setLyricOffset(const Duration(milliseconds: 500));

      final document = await player.loadCurrentLyric();

      expect(player.state.lyricOffset, const Duration(milliseconds: 500));
      expect(states.any((state) => state.lyricOffset == const Duration(milliseconds: 500)), isTrue);
      expect(document.offset, const Duration(milliseconds: 500));
      expect(document.lineAt(const Duration(milliseconds: 1400)), isNull);
      expect(document.lineAt(const Duration(milliseconds: 1600))?.text, 'one');
    } finally {
      await subscription.cancel();
      await player.dispose();
    }
  });

  test('sleep timer pauses playback and clears itself', () async {
    final player = AudioPlaybackController(PlayerKernel());

    try {
      player.setSleepTimer(const Duration(milliseconds: 30));

      expect(player.state.sleepTimerEndsAt, isNotNull);
      expect(player.sleepTimerRemaining, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(player.state.sleepTimerEndsAt, isNull);
      expect(player.state.playing, isFalse);
    } finally {
      await player.dispose();
    }
  });

  test('pause-after-current and the timed sleep timer replace each other', () async {
    final player = AudioPlaybackController(PlayerKernel());

    try {
      player.setSleepTimer(const Duration(minutes: 1));
      expect(player.state.sleepTimerEndsAt, isNotNull);

      player.setPauseAfterCurrentTrack(enabled: true);
      expect(player.state.pauseAfterCurrentTrack, isTrue);
      expect(player.state.sleepTimerEndsAt, isNull);

      player.setSleepTimer(const Duration(minutes: 1));
      expect(player.state.pauseAfterCurrentTrack, isFalse);
      expect(player.state.sleepTimerEndsAt, isNotNull);

      player.setSleepTimer(null);
      expect(player.state.sleepTimerEndsAt, isNull);
      expect(player.state.pauseAfterCurrentTrack, isFalse);
    } finally {
      await player.dispose();
    }
  });

  test('host lyric override wins over the source and moves the revision', () async {
    const track = MusicTrack(id: 'song', sourceId: 'test', title: 'Song');
    final player = AudioPlaybackController(
      PlayerKernel(),
      registry: MusicSourceRegistry(<MusicSource>[_LyricSource()]),
    );

    try {
      await player.setQueue(const <MusicTrack>[track], autoPlay: false);
      expect((await player.loadCurrentLyric()).lines.first.text, 'one');
      final revision = player.state.lyricRevision;

      player.setLyricOverride(track, const LrcParser().parse('[00:01.00]override'));
      expect(player.state.lyricRevision, greaterThan(revision));
      expect(player.lyricOverrideFor(track), isNotNull);
      expect((await player.loadCurrentLyric(force: true)).lines.first.text, 'override');

      player.setLyricOverride(track, null);
      expect(player.lyricOverrideFor(track), isNull);
      expect((await player.loadCurrentLyric(force: true)).lines.first.text, 'one');
    } finally {
      await player.dispose();
    }
  });
}
