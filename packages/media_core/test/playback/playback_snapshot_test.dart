import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';

/// A snapshot of [command], with everything else at rest.
PlaybackSnapshot _of(PlaybackCommand command, {bool buffering = false}) {
  return PlaybackSnapshot(
    command: command,
    position: Duration.zero,
    duration: const Duration(seconds: 10),
    volume: 1,
    rate: 1,
    initialized: true,
    updatedAt: null,
    buffering: buffering,
  );
}

void main() {
  group('PlaybackSnapshot transport predicates', () {
    test('a command answers exactly one of the transport questions', () {
      // The four states a transport rests in. The others are updates that leave
      // the command alone, and they answer none of these questions.
      const cases = <String, PlaybackCommand>{
        'idle': PlaybackCommandIdle(),
        'playing': PlaybackCommandPlay(),
        'paused': PlaybackCommandPause(),
        'stopped': PlaybackCommandStop(),
      };

      cases.forEach((name, command) {
        final snapshot = _of(command);
        final answered = <String>[
          if (snapshot.isPlaying) 'playing',
          if (snapshot.isPaused) 'paused',
          if (snapshot.isStopped) 'stopped',
          if (snapshot.isIdle) 'idle',
        ];

        expect(
          answered,
          hasLength(1),
          reason: 'the $name command must answer one transport question, not ${answered.length}: $answered',
        );
      });

      for (final command in const <PlaybackCommand>[
        PlaybackCommandLoading(),
        PlaybackCommandSeek(Duration(seconds: 3)),
        PlaybackCommandPosition(Duration(seconds: 3)),
        PlaybackCommandVolume(0.5),
      ]) {
        final snapshot = _of(command);

        expect(
          snapshot.isPlaying || snapshot.isPaused || snapshot.isStopped || snapshot.isIdle,
          isFalse,
          reason: '${command.runtimeType} moves a value, it does not change the transport',
        );
      }
    });

    test('a paused transport does not claim it is playing', () {
      // The predicates used to read the command's *type name* for a substring, and
      // every command in the family is named `PlaybackCommand…` — so "contains
      // Play" was true for idle, pause, stop and seek as well, and a snapshot of a
      // stopped player read as playing.
      final paused = _of(const PlaybackCommandPause());

      expect(paused.isPlaying, isFalse);
      expect(paused.isPaused, isTrue);
      expect(paused.isStopped, isFalse);
      expect(paused.isIdle, isFalse);

      expect(_of(const PlaybackCommandIdle()).isPlaying, isFalse);
      expect(_of(const PlaybackCommandStop()).isPlaying, isFalse);
      expect(_of(const PlaybackCommandPlay()).isPlaying, isTrue);
    });

    test('buffering is a condition the snapshot carries, not a command', () {
      // `PlaybackCommand.buffering(value: false)` updates the transport's flag and
      // leaves the play/pause command alone, so a buffering readout has to come
      // from the flag. Reading it off the command answered "never" for a state
      // that is buffering while playing.
      const bufferingWhilePlaying = PlayerTransportState(
        command: PlaybackCommandPlay(),
        position: Duration.zero,
        duration: Duration(seconds: 10),
        volume: 1,
        rate: 1,
        initialized: true,
        updatedAt: null,
        buffering: true,
      );

      final snapshot = PlaybackSnapshot.fromState(bufferingWhilePlaying);

      expect(snapshot.isBuffering, isTrue);
      expect(snapshot.isPlaying, isTrue, reason: 'a stall short of data is still a playing transport');
      expect(snapshot.buffering, isTrue);

      expect(_of(const PlaybackCommandPlay()).isBuffering, isFalse);
    });

    test('the readout carries both, and the values are part of the value', () {
      final left = _of(const PlaybackCommandPlay(), buffering: true);
      final right = _of(const PlaybackCommandPlay());

      expect(left.toMap()['buffering'], isTrue);
      expect(right.toMap()['buffering'], isFalse);
      expect(left, isNot(right), reason: 'buffering is a fact about the transport, so it cannot be equal noise');
      expect(left.hashCode, isNot(right.hashCode));
    });

    test('fromState reads every field it claims to mirror', () {
      final state = PlayerTransportState(
        command: const PlaybackCommandPause(),
        position: const Duration(seconds: 4),
        duration: const Duration(seconds: 40),
        volume: 0.5,
        rate: 1.5,
        initialized: true,
        updatedAt: DateTime.utc(2026, 10, 14),
        buffering: true,
      );

      final snapshot = PlaybackSnapshot.fromState(state);

      expect(snapshot.command, const PlaybackCommandPause());
      expect(snapshot.position, state.position);
      expect(snapshot.duration, state.duration);
      expect(snapshot.volume, state.volume);
      expect(snapshot.rate, state.rate);
      expect(snapshot.initialized, state.initialized);
      expect(snapshot.updatedAt, state.updatedAt);
      expect(snapshot.buffering, state.buffering);
      expect(snapshot, PlaybackSnapshot.fromState(state), reason: 'the same state reads the same');
    });
  });
}
