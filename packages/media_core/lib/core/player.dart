import 'package:clock/clock.dart';
import '../identity/player_id.dart';
import 'package:equatable/equatable.dart';

/// Represents the stable identity of a player.
///
/// [Player] contains only information that belongs to the lifetime of the
/// player identity itself. Runtime associations such as session, request,
/// and generation are intentionally kept outside this object.
///
/// Player equality is determined exclusively by [id].
final class Player extends Equatable {
  /// Creates a player from an existing [PlayerId].
  const Player({required this.id, this.createdAt});

  /// Creates a new player with a generated unique identifier.
  factory Player.create({DateTime? createdAt}) {
    return Player(id: PlayerId.generate(), createdAt: createdAt ?? clock.now());
  }

  /// Stable identifier of this player instance.
  final PlayerId id;

  /// Time at which this player identity was created.
  ///
  /// This value is informational and does not participate in identity
  /// equality.
  final DateTime? createdAt;

  /// Whether a creation timestamp is available.
  bool get hasCreatedAt => createdAt != null;

  /// Returns whether [other] represents the same player identity.
  ///
  /// Player identity is determined exclusively by [id].
  bool isSamePlayer(Player other) {
    return id == other.id;
  }

  /// Returns whether [other] represents a different player identity.
  bool isDifferentPlayer(Player other) {
    return id != other.id;
  }

  /// Returns whether this player was created before [other].
  ///
  /// Returns `false` when either player does not have a creation timestamp.
  bool isOlderThan(Player other) {
    final current = createdAt;
    final target = other.createdAt;

    if (current == null || target == null) {
      return false;
    }

    return current.isBefore(target);
  }

  /// Returns whether this player was created after [other].
  ///
  /// Returns `false` when either player does not have a creation timestamp.
  bool isNewerThan(Player other) {
    final current = createdAt;
    final target = other.createdAt;

    if (current == null || target == null) {
      return false;
    }

    return current.isAfter(target);
  }

  @override
  List<Object?> get props => <Object?>[id];

  @override
  String toString() {
    return 'Player('
        'id: $id, '
        'createdAt: $createdAt'
        ')';
  }
}
