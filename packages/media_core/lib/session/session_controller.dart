import 'dart:async';
import 'session_state.dart';
import 'player_session.dart';
import 'session_generation.dart';
import '../identity/generation_id.dart';

/// Controls a player session lifecycle.
///
/// [SessionController] coordinates operations on a
/// [PlayerSession].
///
/// Responsibilities:
///
/// - session state transitions
/// - generation management
/// - lifecycle operations
///
/// It does not:
///
/// - create player instances
/// - access media backend directly
///
/// Those belong to:
///
/// - Factory
/// - Adapter
final class SessionController {
  /// Creates a session controller.
  SessionController(this.session);

  /// Managed session.
  final PlayerSession session;

  /// Current session state.
  SessionState get state {
    return session.state;
  }

  /// Current generation.
  SessionGeneration get generation {
    return session.generation;
  }

  /// Opens session.
  ///
  /// This only updates session lifecycle.
  /// Actual media opening belongs to adapter.
  Future<void> open() async {
    session.updateState(const SessionState.opening());

    await Future<void>.delayed(Duration.zero);

    session.updateState(const SessionState.ready());
  }

  /// Starts playback state.
  Future<void> play() async {
    if (!session.state.playable) {
      return;
    }

    session.updateState(const SessionState.playing());
  }

  /// Pauses playback state.
  Future<void> pause() async {
    if (!session.state.playable) {
      return;
    }

    session.updateState(const SessionState.paused());
  }

  /// Stops session.
  Future<void> stop() async {
    session.updateState(const SessionState.stopped());
  }

  /// Marks session as buffering.
  void buffering() {
    session.updateState(const SessionState.buffering());
  }

  /// Marks session as completed.
  void complete() {
    session.updateState(const SessionState.completed());
  }

  /// Reports session error.
  void error(String message) {
    session.updateState(const SessionState.error());
  }

  /// Creates a new playback generation.
  GenerationId recreateGeneration() {
    return session.nextGeneration().id;
  }

  /// Checks generation validity.
  bool isCurrentGeneration(GenerationId id) {
    return session.isCurrentGeneration(id);
  }

  /// Releases session.
  Future<void> dispose() async {
    await session.dispose();
  }
}
