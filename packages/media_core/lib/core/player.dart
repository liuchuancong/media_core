import 'package:clock/clock.dart';
import '../identity/player_id.dart';
import '../identity/request_id.dart';
import '../identity/session_id.dart';
import '../identity/generation_id.dart';
import 'package:equatable/equatable.dart';


/// Represents the stable identity of a player instance.
///
/// [Player] is intentionally lightweight. It identifies a player and its
/// current associations, but does not own backend resources or runtime
/// playback state.
final class Player extends Equatable {
  /// Creates a player from an existing [PlayerId].
  factory Player({
    required PlayerId id,
    SessionId? sessionId,
    RequestId? requestId,
    GenerationId? generationId,
    DateTime? createdAt,
  }) {
    return Player._(
      id: id,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      createdAt: createdAt,
    );
  }

  /// Creates a new player with a generated unique identifier.
  ///
  /// The generated identifier is stable for the lifetime of the returned
  /// player object.
  factory Player.create({
    SessionId? sessionId,
    RequestId? requestId,
    GenerationId? generationId,
    DateTime? createdAt,
  }) {
    return Player._(
      id: PlayerId.generate(),
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      createdAt: createdAt ?? clock.now(),
    );
  }

  const Player._({
    required this.id,
    this.sessionId,
    this.requestId,
    this.generationId,
    this.createdAt,
  });

  /// Stable identifier of this player instance.
  final PlayerId id;

  /// Identifier of the currently associated session.
  final SessionId? sessionId;

  /// Identifier of the request currently associated with the player.
  final RequestId? requestId;

  /// Identifier of the current player generation.
  final GenerationId? generationId;

  /// Time at which the player identity was created.
  final DateTime? createdAt;

  /// Returns whether a session is associated with this player.
  bool get hasSession => sessionId != null;

  /// Returns whether a request is associated with this player.
  bool get hasRequest => requestId != null;

  /// Returns whether a generation is associated with this player.
  bool get hasGeneration => generationId != null;

  /// Returns whether a creation timestamp is available.
  bool get hasCreatedAt => createdAt != null;

  /// Returns whether this player has no runtime associations.
  bool get hasNoAssociations {
    return sessionId == null &&
        requestId == null &&
        generationId == null;
  }

  /// Creates a copy with selectively replaced values.
  ///
  /// Null values retain their existing values. Use the explicit
  /// `withoutX` methods when an association needs to be removed.
  Player copyWith({
    PlayerId? id,
    SessionId? sessionId,
    RequestId? requestId,
    GenerationId? generationId,
    DateTime? createdAt,
  }) {
    return Player._(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      generationId: generationId ?? this.generationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy associated with [sessionId].
  Player withSession(SessionId sessionId) {
    return copyWith(sessionId: sessionId);
  }

  /// Returns a copy associated with [requestId].
  Player withRequest(RequestId requestId) {
    return copyWith(requestId: requestId);
  }

  /// Returns a copy associated with [generationId].
  Player withGeneration(GenerationId generationId) {
    return copyWith(generationId: generationId);
  }

  /// Returns a copy without a session association.
  Player withoutSession() {
    return Player._(
      id: id,
      requestId: requestId,
      generationId: generationId,
      createdAt: createdAt,
    );
  }

  /// Returns a copy without a request association.
  Player withoutRequest() {
    return Player._(
      id: id,
      sessionId: sessionId,
      generationId: generationId,
      createdAt: createdAt,
    );
  }

  /// Returns a copy without a generation association.
  Player withoutGeneration() {
    return Player._(
      id: id,
      sessionId: sessionId,
      requestId: requestId,
      createdAt: createdAt,
    );
  }

  /// Returns a copy without any runtime associations.
  Player clearAssociations() {
    return Player._(
      id: id,
      createdAt: createdAt,
    );
  }

  /// Returns whether this object represents the same player as [other].
  ///
  /// Player identity is determined exclusively by [id].
  bool isSamePlayer(Player other) {
    return id == other.id;
  }

  /// Returns whether this object represents a different player from [other].
  bool isDifferentPlayer(Player other) {
    return id != other.id;
  }

  /// Returns whether both players belong to the same session.
  bool isSameSession(Player other) {
    return sessionId != null &&
        other.sessionId != null &&
        sessionId == other.sessionId;
  }

  /// Returns whether both players belong to the same request.
  bool isSameRequest(Player other) {
    return requestId != null &&
        other.requestId != null &&
        requestId == other.requestId;
  }

  /// Returns whether both players belong to the same generation.
  bool isSameGeneration(Player other) {
    return generationId != null &&
        other.generationId != null &&
        generationId == other.generationId;
  }

  /// Returns whether the player has the same runtime associations as [other].
  bool hasSameAssociations(Player other) {
    return sessionId == other.sessionId &&
        requestId == other.requestId &&
        generationId == other.generationId;
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
  List<Object?> get props => <Object?>[
        id,
        sessionId,
        requestId,
        generationId,
        createdAt,
      ];

  @override
  String toString() {
    return 'Player('
        'id: $id, '
        'sessionId: $sessionId, '
        'requestId: $requestId, '
        'generationId: $generationId, '
        'createdAt: $createdAt'
        ')';
  }
}