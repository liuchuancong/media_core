import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/src/core/state/player_core_state.dart';
import 'package:media_core/src/core/state/player_status.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/models/core/library.dart';

PlayerSnapshot snapshotFor(PlayerCoreState state) {
  return PlayerSnapshot.of(playerId: PlayerId('p1'), state: state);
}

void main() {
  group('PlayerSnapshot', () {
    test('minimal snapshot has player id and idle status', () {
      final snapshot = PlayerSnapshot.of(playerId: PlayerId('p1'));

      expect(snapshot.hasSession, isFalse);
      expect(snapshot.hasSource, isFalse);
      expect(snapshot.hasMetrics, isFalse);
      expect(snapshot.playerStatus, PlayerStatus.idle);
    });

    test('playerStatus follows playback state', () {
      expect(snapshotFor(PlayerCoreState.idle.playingState()).playerStatus, PlayerStatus.playing);
      expect(snapshotFor(PlayerCoreState.idle.pausedState()).playerStatus, PlayerStatus.paused);
      expect(snapshotFor(PlayerCoreState.idle.bufferingState()).playerStatus, PlayerStatus.buffering);
      expect(snapshotFor(PlayerCoreState.idle.seekingState()).playerStatus, PlayerStatus.seeking);
      expect(snapshotFor(PlayerCoreState.idle.completedState()).playerStatus, PlayerStatus.completed);
      expect(snapshotFor(PlayerCoreState.idle.stoppedState()).playerStatus, PlayerStatus.stopped);
    });

    test('terminal states dominate playerStatus', () {
      expect(snapshotFor(PlayerCoreState.idle.disposedState()).playerStatus, PlayerStatus.disposed);
      expect(snapshotFor(PlayerCoreState.idle.disposingState()).playerStatus, PlayerStatus.disposing);
      expect(snapshotFor(PlayerCoreState.idle.readyState().errorState()).playerStatus, PlayerStatus.error);
    });

    test('ready state without source maps to ready', () {
      expect(snapshotFor(PlayerCoreState.idle.readyState()).playerStatus, PlayerStatus.ready);
    });

    test('delegates state helpers', () {
      final snapshot = snapshotFor(PlayerCoreState.idle.playingState());
      expect(snapshot.isPlaying, isTrue);

      final withSession = PlayerSnapshot.of(playerId: PlayerId('p1'), sessionId: SessionId('s1'));
      expect(withSession.hasSession, isTrue);
    });

    test('equality is value based', () {
      final a = PlayerSnapshot.of(playerId: PlayerId('p1'));
      final b = PlayerSnapshot.of(playerId: PlayerId('p1'));
      expect(a, b);

      final c = PlayerSnapshot.of(playerId: PlayerId('p2'));
      expect(a, isNot(c));
    });
  });
}
