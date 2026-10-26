import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/slot/player_slot_owner_type.dart';

part 'player_slot_owner.g.dart';

/// Identifies the owner of a player slot.
///
/// A slot owner represents the module or component
/// currently using a slot.
///
/// It does not:
///
/// - manage slot lifecycle
/// - allocate players
/// - control playback
///
/// Those belong to:
///
/// - PlayerSlotManager
/// - PlayerPool
abstract class PlayerSlotOwner implements Built<PlayerSlotOwner, PlayerSlotOwnerBuilder> {
  /// Builds an owner from a [updates] callback — the codegen entry.
  factory PlayerSlotOwner([void Function(PlayerSlotOwnerBuilder)? updates]) = _$PlayerSlotOwner;

  /// Creates a slot owner.
  factory PlayerSlotOwner.of({required PlayerSlotOwnerType type, String? id}) {
    return PlayerSlotOwner(
      (builder) => builder
        ..type = type
        ..id = id,
    );
  }

  PlayerSlotOwner._();

  /// Creates page owner.
  factory PlayerSlotOwner.page(String id) {
    return PlayerSlotOwner.of(type: PlayerSlotOwnerType.page, id: id);
  }

  /// Creates preload owner.
  factory PlayerSlotOwner.preload(String id) {
    return PlayerSlotOwner.of(type: PlayerSlotOwnerType.preload, id: id);
  }

  /// Creates PIP owner.
  factory PlayerSlotOwner.pip() {
    return PlayerSlotOwner.of(type: PlayerSlotOwnerType.pip);
  }

  /// Creates system owner.
  factory PlayerSlotOwner.system() {
    return PlayerSlotOwner.of(type: PlayerSlotOwnerType.system);
  }

  /// Owner type.
  PlayerSlotOwnerType get type;

  /// Optional owner identifier.
  ///
  /// Examples:
  ///
  /// - page id
  /// - widget id
  /// - preload task id
  String? get id;

  /// Whether owner is page.
  bool get isPage {
    return type == PlayerSlotOwnerType.page;
  }

  /// Whether owner is preload.
  bool get isPreload {
    return type == PlayerSlotOwnerType.preload;
  }

  /// Whether owner is PIP.
  bool get isPip {
    return type == PlayerSlotOwnerType.pip;
  }
}
