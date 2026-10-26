import 'package:built_value/built_value.dart';
import 'package:clock/clock.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/slot_id.dart';
import 'package:media_core/src/models/slot/player_slot_owner.dart';

part 'player_slot_assignment.g.dart';

/// Represents a player slot assignment.
///
/// A [PlayerSlotAssignment] describes the relationship
/// between a slot and its current consumer.
///
/// Responsibilities:
///
/// - record assignment information
/// - track ownership
///
/// It does not:
///
/// - create player
/// - create session
/// - control playback
///
/// Those belong to:
///
/// - PlayerFactory
/// - SessionManager
/// - PlayerSlotManager
abstract class PlayerSlotAssignment implements Built<PlayerSlotAssignment, PlayerSlotAssignmentBuilder> {
  /// Builds an assignment from a [updates] callback — the codegen entry.
  factory PlayerSlotAssignment([void Function(PlayerSlotAssignmentBuilder)? updates]) = _$PlayerSlotAssignment;

  /// Creates assignment.
  factory PlayerSlotAssignment.of({
    required SlotId slotId,
    required PlayerSlotOwner owner,
    required PlayerId playerId,
    required SessionId sessionId,
    required DateTime createdAt,
  }) {
    return PlayerSlotAssignment(
      (builder) => builder
        ..slotId = slotId
        ..owner = owner.toBuilder()
        ..playerId = playerId
        ..sessionId = sessionId
        ..createdAt = createdAt,
    );
  }

  PlayerSlotAssignment._();

  /// Creates assignment stamped with the current time.
  factory PlayerSlotAssignment.create({
    required SlotId slotId,
    required PlayerSlotOwner owner,
    required PlayerId playerId,
    required SessionId sessionId,
  }) {
    return PlayerSlotAssignment.of(
      slotId: slotId,
      owner: owner,
      playerId: playerId,
      sessionId: sessionId,
      createdAt: clock.now(),
    );
  }

  /// Slot identity.
  SlotId get slotId;

  /// Assignment owner.
  PlayerSlotOwner get owner;

  /// Assigned player.
  PlayerId get playerId;

  /// Assigned session.
  SessionId get sessionId;

  /// Assignment creation time.
  DateTime get createdAt;

  /// Whether assignment belongs to page.
  bool get isPage {
    return owner.isPage;
  }

  /// Whether assignment belongs to preload.
  bool get isPreload {
    return owner.isPreload;
  }

  /// Whether assignment belongs to PIP.
  bool get isPip {
    return owner.isPip;
  }

  /// Checks whether assignment matches slot.
  bool matchesSlot(SlotId id) {
    return slotId == id;
  }

  /// Checks whether assignment owns player.
  bool matchesPlayer(PlayerId id) {
    return playerId == id;
  }

  /// Checks whether assignment owns session.
  bool matchesSession(SessionId id) {
    return sessionId == id;
  }
}
