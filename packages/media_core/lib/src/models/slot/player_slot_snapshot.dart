import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/slot_id.dart';
import 'package:media_core/src/models/slot/player_slot_status.dart';

part 'player_slot_snapshot.g.dart';

/// Immutable snapshot of a player slot.
///
/// A [PlayerSlotSnapshot] represents a captured
/// point-in-time view of a slot.
///
/// It is used for:
///
/// - diagnostics
/// - debugging
/// - testing
/// - state inspection
///
/// It does not:
///
/// - control slot lifecycle
/// - mutate player assignment
/// - manage playback
abstract class PlayerSlotSnapshot implements Built<PlayerSlotSnapshot, PlayerSlotSnapshotBuilder> {
  /// Builds a snapshot from a [updates] callback — the codegen entry.
  factory PlayerSlotSnapshot([void Function(PlayerSlotSnapshotBuilder)? updates]) = _$PlayerSlotSnapshot;

  /// Creates slot snapshot.
  factory PlayerSlotSnapshot.of({
    required SlotId slotId,
    required PlayerSlotStatus status,
    required DateTime createdAt,
    PlayerId? playerId,
    SessionId? sessionId,
  }) {
    return PlayerSlotSnapshot(
      (builder) => builder
        ..slotId = slotId
        ..status = status
        ..createdAt = createdAt
        ..playerId = playerId
        ..sessionId = sessionId,
    );
  }

  PlayerSlotSnapshot._();

  /// Creates snapshot from runtime slot.
  factory PlayerSlotSnapshot.fromState(
    SlotId slotId,
    PlayerSlotStatus status, {
    PlayerId? playerId,
    SessionId? sessionId,
  }) {
    return PlayerSlotSnapshot.of(
      slotId: slotId,
      status: status,
      playerId: playerId,
      sessionId: sessionId,
      createdAt: clock.now(),
    );
  }

  /// Slot identity.
  SlotId get slotId;

  /// Slot status at snapshot time.
  PlayerSlotStatus get status;

  /// Assigned player.
  PlayerId? get playerId;

  /// Assigned session.
  SessionId? get sessionId;

  /// Snapshot creation time.
  DateTime get createdAt;

  /// Whether slot was empty.
  bool get isEmpty {
    return status == PlayerSlotStatus.empty;
  }

  /// Whether slot had player assignment.
  bool get isAssigned {
    return status == PlayerSlotStatus.assigned;
  }

  /// Whether slot was active.
  bool get isActive {
    return status == PlayerSlotStatus.active;
  }
}
