import 'session_state.dart';
import 'session_context.dart';
import 'session_snapshot.dart';
import 'session_generation.dart';
import 'package:rxdart/rxdart.dart';
import '../identity/generation_id.dart';

/// Represents one playback lifecycle session.
///
/// A [PlayerSession] owns one logical playback lifecycle.
///
/// Responsibilities:
///
/// - maintain session state
/// - manage generation changes
/// - expose session snapshots
///
/// It does not:
///
/// - create adapters
/// - execute backend commands
///
/// Those belong to:
///
/// - PlayerFactory
/// - PlayerAdapter
/// - PlaybackController
final class PlayerSession {
  /// Creates a player session.
  PlayerSession({required SessionContext context})
    : _context = context,
      _generation = SessionGeneration.initial(),
      _state = const SessionState.idle() {
    _snapshotController.add(_createSnapshot());
  }

  /// Current session context.
  SessionContext get context {
    return _context;
  }

  /// Current generation.
  SessionGeneration get generation {
    return _generation;
  }

  /// Current session state.
  SessionState get state {
    return _state;
  }

  /// Snapshot stream.
  Stream<SessionSnapshot> get snapshots {
    return _snapshotController.stream;
  }

  /// Latest snapshot.
  SessionSnapshot get snapshot {
    return _createSnapshot();
  }

  SessionContext _context;

  SessionGeneration _generation;

  SessionState _state;

  final BehaviorSubject<SessionSnapshot> _snapshotController = BehaviorSubject<SessionSnapshot>();

  /// Updates session state.
  void updateState(SessionState state) {
    _state = state;

    _emitSnapshot();
  }

  /// Moves to next generation.
  SessionGeneration nextGeneration() {
    _generation = _generation.next();

    _emitSnapshot();

    return _generation;
  }

  /// Replaces session context.
  void updateContext(SessionContext context) {
    _context = context;

    _emitSnapshot();
  }

  /// Checks whether generation is current.
  bool isCurrentGeneration(GenerationId id) {
    return _generation.id == id;
  }

  /// Creates snapshot.
  SessionSnapshot _createSnapshot() {
    return SessionSnapshot(
      playerId: _context.playerId,

      sessionId: _context.sessionId,

      generationId: _generation.id,

      sourceId: _context.sourceId,

      state: _state,

      timestamp: DateTime.now(),
    );
  }

  /// Emits snapshot.
  void _emitSnapshot() {
    _snapshotController.add(_createSnapshot());
  }

  /// Disposes session.
  Future<void> dispose() async {
    _state = const SessionState.disposed();

    _emitSnapshot();

    await _snapshotController.close();
  }
}
