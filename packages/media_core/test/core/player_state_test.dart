import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/core/player_state.dart';

void main() {
  group('PlayerState', () {
    test('default state is idle', () {
      const state = PlayerState();
      expect(state.isIdle, isTrue);
      expect(state.lifecycle, PlayerLifecycleState.idle);
      expect(state.playback, PlayerPlaybackState.idle);
      expect(state.hasSource, isFalse);
    });

    test('state helpers reflect playback enum', () {
      expect(PlayerState.idle.playingState().playing, isTrue);
      expect(PlayerState.idle.pausedState().paused, isTrue);
      expect(PlayerState.idle.bufferingState().buffering, isTrue);
      expect(PlayerState.idle.seekingState().seeking, isTrue);
      expect(PlayerState.idle.completedState().completed, isTrue);
      expect(PlayerState.idle.stoppedState().stopped, isTrue);
    });

    test('error state marks hasError and blocks control', () {
      final state = PlayerState.idle.readyState().errorState();
      expect(state.hasError, isTrue);
      expect(state.canControl, isFalse);
      expect(state.ready, isFalse);
      expect(state.isClean, isFalse);
    });

    test('disposed is terminal and clears outputs', () {
      final state = PlayerState.idle.withAudioEnabled(true).playingState().disposedState();
      expect(state.disposed, isTrue);
      expect(state.isTerminal, isTrue);
      expect(state.hasSource, isFalse);
      expect(state.audioEnabled, isFalse);
    });

    group('transitions', () {
      test('initializing to ready', () {
        final state = PlayerState.idle.initializingState();
        expect(state.lifecycle, PlayerLifecycleState.initializing);

        final ready = state.readyState();
        expect(ready.initialized, isTrue);
        expect(ready.isIdle, isFalse);
      });

      test('ready to opening to playing', () {
        final opening = PlayerState.idle.initializingState().readyState().openingState();
        expect(opening.opening, isTrue);
        expect(opening.isTransitioning, isTrue);

        final playing = opening.withSource(true).playingState();
        expect(playing.playing, isTrue);
        expect(playing.hasSource, isTrue);
        expect(playing.isPlaybackActive, isTrue);
      });

      test('withSource false resets playback to idle', () {
        final state = PlayerState.idle.playingState().withSource(false);
        expect(state.hasSource, isFalse);
        expect(state.playback, PlayerPlaybackState.idle);
      });

      test('clearError restores idle playback', () {
        final state = PlayerState.idle.readyState().errorState().clearError();
        expect(state.hasError, isFalse);
        expect(state.playback, PlayerPlaybackState.idle);
      });

      test('reset keeps lifecycle but clears playback', () {
        final state = PlayerState.idle.playingState().reset();
        expect(state.lifecycle, PlayerLifecycleState.ready);
        expect(state.playback, PlayerPlaybackState.idle);
      });
    });

    group('capability gates', () {
      test('canPlay requires source and readiness', () {
        expect(PlayerState.idle.canPlay, isFalse);

        final ready = PlayerState.idle.initializingState().readyState();
        expect(ready.canPlay, isFalse, reason: 'no source yet');

        final withSource = ready.withSource(true);
        expect(withSource.canPlay, isTrue);

        expect(withSource.playingState().canPlay, isFalse);
        expect(withSource.bufferingState().canPlay, isFalse);
      });

      test('canPause only while playing', () {
        final withSource = PlayerState.idle.readyState().withSource(true);
        expect(withSource.canPause, isFalse);
        expect(withSource.playingState().canPause, isTrue);
      });

      test('canStop during active playback transitions', () {
        expect(PlayerState.idle.canStop, isFalse);
        expect(PlayerState.idle.readyState().withSource(true).playingState().canStop, isTrue);
        expect(PlayerState.idle.readyState().openingState().canStop, isTrue);
      });
    });

    group('output modes', () {
      test('audio only / video only / both', () {
        final audioOnly = PlayerState.idle.withAudioEnabled(true);
        expect(audioOnly.isAudioOnly, isTrue);

        final videoOnly = PlayerState.idle.withVideoEnabled(true);
        expect(videoOnly.isVideoOnly, isTrue);

        final both = audioOnly.withVideoEnabled(true);
        expect(both.isAudioVideo, isTrue);
      });

      test('muted toggling', () {
        expect(PlayerState.idle.withMuted(true).muted, isTrue);
      });
    });

    test('serialization round trip', () {
      final state = PlayerState.idle.playingState().withSource(true).withMuted(true);
      final json = state.toJson();
      final restored = PlayerState.fromJson(json);
      expect(restored, state);
    });
  });
}
