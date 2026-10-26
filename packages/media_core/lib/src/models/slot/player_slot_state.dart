import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/slot_id.dart';
import 'package:media_core/src/models/slot/player_slot_status.dart';

part 'player_slot_state.g.dart';

/// Represents runtime state of a player slot.
///
/// [PlayerSlotState] is an immutable snapshot used
/// for reactive state updates.
///
/// It does not:
///
/// - control playback
/// - manage player lifecycle
/// - allocate resources
///
/// Those belong to:
///
/// - PlayerSlotManager
/// - PlayerPool
/// - PlayerSession
abstract class PlayerSlotState implements Built<PlayerSlotState, PlayerSlotStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory PlayerSlotState([void Function(PlayerSlotStateBuilder)? updates]) = _$PlayerSlotState;

  /// Creates slot state.
  factory PlayerSlotState.of({
    required SlotId slotId,
    PlayerSlotStatus status = PlayerSlotStatus.empty,
    PlayerId? playerId,
    SessionId? sessionId,
  }) {
    return PlayerSlotState(
      (builder) => builder
        ..slotId = slotId
        ..status = status
        ..playerId = playerId
        ..sessionId = sessionId,
    );
  }

  PlayerSlotState._();

  /// Creates empty slot state.
  factory PlayerSlotState.empty(SlotId slotId) {
    return PlayerSlotState.of(slotId: slotId);
  }

  /// A slot with nothing said about it holds no player and no session,
  /// and is empty rather than in any later phase.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerSlotStateBuilder builder) => builder..status = PlayerSlotStatus.empty;

  /// Slot identity.
  SlotId get slotId;

  /// Current slot status.
  PlayerSlotStatus get status;

  /// Assigned player.
  PlayerId? get playerId;

  /// Assigned session.
  SessionId? get sessionId;

  /// Whether slot is empty.
  bool get isEmpty {
    return status == PlayerSlotStatus.empty;
  }

  /// Whether slot has assignment.
  bool get isAssigned {
    return status == PlayerSlotStatus.assigned;
  }

  /// Whether slot is active.
  bool get isActive {
    return status == PlayerSlotStatus.active;
  }

  /// Whether slot is releasing.
  bool get isReleasing {
    return status == PlayerSlotStatus.releasing;
  }

  /// Whether this state belongs to slot.
  bool matchesSlot(SlotId id) {
    return slotId == id;
  }

  /// Whether this state contains player.
  bool matchesPlayer(PlayerId id) {
    return playerId == id;
  }

  /// Whether this state contains session.
  bool matchesSession(SessionId id) {
    return sessionId == id;
  }
}
