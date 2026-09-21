import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/core/player_snapshot.dart';
import 'package:media_core/core/player_state.dart';
import 'package:media_core/core/player_status.dart';
import 'package:media_core/identity/player_id.dart';
import 'package:media_core/identity/session_id.dart';

PlayerSnapshot snapshotFor(PlayerState state) {
  return PlayerSnapshot(playerId: PlayerId('p1'), state: state);
}

void main() {
  group('PlayerSnapshot', () {
    test('minimal snapshot has player id and idle status', () {
      final snapshot = PlayerSnapshot(playerId: PlayerId('p1'));

      expect(snapshot.hasSession, isFalse);
      expect(snapshot.hasSource, isFalse);
      expect(snapshot.hasMetrics, isFalse);
      expect(snapshot.playerStatus, PlayerStatus.idle);
    });

    test('playerStatus follows playback state', () {
      expect(snapshotFor(PlayerState.idle.playingState()).playerStatus, PlayerStatus.playing);
      expect(snapshotFor(PlayerState.idle.pausedState()).playerStatus, PlayerStatus.paused);
      expect(snapshotFor(PlayerState.idle.bufferingState()).playerStatus, PlayerStatus.buffering);
      expect(snapshotFor(PlayerState.idle.seekingState()).playerStatus, PlayerStatus.seeking);
      expect(snapshotFor(PlayerState.idle.completedState()).playerStatus, PlayerStatus.completed);
      expect(snapshotFor(PlayerState.idle.stoppedState()).playerStatus, PlayerStatus.stopped);
    });

    test('terminal states dominate playerStatus', () {
      expect(snapshotFor(PlayerState.idle.disposedState()).playerStatus, PlayerStatus.disposed);
      expect(snapshotFor(PlayerState.idle.disposingState()).playerStatus, PlayerStatus.disposing);
      expect(
        snapshotFor(PlayerState.idle.readyState().errorState()).playerStatus,
        PlayerStatus.error,
      );
    });

    test('ready state without source maps to ready', () {
      expect(snapshotFor(PlayerState.idle.readyState()).playerStatus, PlayerStatus.ready);
    });

    test('delegates state helpers', () {
      final snapshot = snapshotFor(PlayerState.idle.playingState());
      expect(snapshot.isPlaying, isTrue);

      final withSession = PlayerSnapshot(
        playerId: PlayerId('p1'),
        sessionId: SessionId('s1'),
      );
      expect(withSession.hasSession, isTrue);
    });

    test('equality is value based', () {
      final a = PlayerSnapshot(playerId: PlayerId('p1'));
      final b = PlayerSnapshot(playerId: PlayerId('p1'));
      expect(a, b);

      final c = PlayerSnapshot(playerId: PlayerId('p2'));
      expect(a, isNot(c));
    });
  });
}
