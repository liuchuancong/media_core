import 'media_type.dart';
import 'media_capabilities.dart';
import '../identity/player_id.dart';
import '../identity/source_id.dart';
import '../identity/request_id.dart';
import '../identity/session_id.dart';
import '../identity/generation_id.dart';
import 'package:equatable/equatable.dart';

/// Describes immutable information about a player instance.
///
/// [PlayerInfo] contains identity, source, media, and descriptive
/// information that is useful for inspecting a player without exposing
/// mutable runtime state.
final class PlayerInfo extends Equatable {
  /// Creates immutable player information.
  const PlayerInfo({
    required this.playerId,
    this.sessionId,
    this.requestId,
    this.generationId,
    this.sourceId,
    this.mediaType,
    this.mediaCapabilities,
    this.name,
    this.title,
    this.description,
    this.uri,
    this.createdAt,
    this.updatedAt,
    this.metadata = const <String, Object?>{},
  });

  /// Unique identifier of the player.
  final PlayerId playerId;

  /// Session associated with the player.
  final SessionId? sessionId;

  /// Request associated with the current player operation.
  final RequestId? requestId;

  /// Generation associated with the current player lifecycle.
  ///
  /// Generation identifiers allow stale asynchronous results to be
  /// distinguished from the current player generation.
  final GenerationId? generationId;

  /// Source associated with the player.
  final SourceId? sourceId;

  /// Media type currently associated with the player.
  final MediaType? mediaType;

  /// Capabilities of the media currently associated with the player.
  final MediaCapabilities? mediaCapabilities;

  /// Optional player name.
  final String? name;

  /// Optional media title.
  final String? title;

  /// Optional media description.
  final String? description;

  /// Optional source URI.
  final Uri? uri;

  /// Time when this information was created.
  final DateTime? createdAt;

  /// Time when this information was last updated.
  final DateTime? updatedAt;

  /// Additional descriptive metadata.
  final Map<String, Object?> metadata;

  /// Returns whether a session is associated with the player.
  bool get hasSession => sessionId != null;

  /// Returns whether a request is associated with the player.
  bool get hasRequest => requestId != null;

  /// Returns whether a generation is associated with the player.
  bool get hasGeneration => generationId != null;

  /// Returns whether a source is associated with the player.
  bool get hasSource => sourceId != null;

  /// Returns whether a media type is available.
  bool get hasMediaType => mediaType != null;

  /// Returns whether media capabilities are available.
  bool get hasMediaCapabilities => mediaCapabilities != null;

  /// Returns whether a non-empty player name is available.
  bool get hasName => name != null && name!.trim().isNotEmpty;

  /// Returns whether a non-empty title is available.
  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  /// Returns whether a description is available.
  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  /// Returns whether a source URI is available.
  bool get hasUri => uri != null;

  /// Returns whether creation time is available.
  bool get hasCreatedAt => createdAt != null;

  /// Returns whether update time is available.
  bool get hasUpdatedAt => updatedAt != null;

  /// Returns whether metadata is available.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Returns whether the player has audio.
  bool get hasAudio {
    if (mediaType != null) {
      return mediaType!.hasAudio;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.hasAudio;
    }

    return false;
  }

  /// Returns whether the player has video.
  bool get hasVideo {
    if (mediaType != null) {
      return mediaType!.hasVideo;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.hasVideo;
    }

    return false;
  }

  /// Returns whether the player represents audio-only media.
  bool get isAudioOnly {
    if (mediaType != null) {
      return mediaType!.isAudioOnly;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.isAudioOnly;
    }

    return hasAudio && !hasVideo;
  }

  /// Returns whether the player represents video-only media.
  bool get isVideoOnly {
    if (mediaType != null) {
      return mediaType!.isVideoOnly;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.isVideoOnly;
    }

    return hasVideo && !hasAudio;
  }

  /// Returns whether the player represents combined audio and video media.
  bool get isAudioVideo {
    if (mediaType != null) {
      return mediaType!.isAudioVideo;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.isAudioVideo;
    }

    return hasAudio && hasVideo;
  }

  /// Returns whether the player requires a video renderer.
  bool get requiresVideoRenderer {
    if (mediaType != null) {
      return mediaType!.requiresVideoRenderer;
    }

    if (mediaCapabilities != null) {
      return mediaCapabilities!.requiresVideoRenderer;
    }

    return hasVideo;
  }

  /// Returns whether any media capability is known.
  bool get hasAnyMedia {
    return hasAudio || hasVideo || (mediaCapabilities?.hasSubtitles ?? false);
  }

  /// Returns a metadata value by key.
  Object? metadataValue(String key) {
    return metadata[key];
  }

  /// Returns a typed metadata value.
  T? metadataAs<T>(String key) {
    final value = metadata[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  /// Returns whether metadata contains [key].
  bool containsMetadata(String key) {
    return metadata.containsKey(key);
  }

  /// Creates a copy with updated values.
  ///
  /// Null values retain their existing values.
  PlayerInfo copyWith({
    PlayerId? playerId,
    SessionId? sessionId,
    RequestId? requestId,
    GenerationId? generationId,
    SourceId? sourceId,
    MediaType? mediaType,
    MediaCapabilities? mediaCapabilities,
    String? name,
    String? title,
    String? description,
    Uri? uri,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return PlayerInfo(
      playerId: playerId ?? this.playerId,
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      generationId: generationId ?? this.generationId,
      sourceId: sourceId ?? this.sourceId,
      mediaType: mediaType ?? this.mediaType,
      mediaCapabilities: mediaCapabilities ?? this.mediaCapabilities,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      uri: uri ?? this.uri,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Creates a copy associated with [value] as the session.
  PlayerInfo withSession(SessionId value) {
    return copyWith(sessionId: value);
  }

  /// Creates a copy associated with [value] as the request.
  PlayerInfo withRequest(RequestId value) {
    return copyWith(requestId: value);
  }

  /// Creates a copy associated with [value] as the generation.
  PlayerInfo withGeneration(GenerationId value) {
    return copyWith(generationId: value);
  }

  /// Creates a copy associated with [value] as the source.
  PlayerInfo withSource(SourceId value) {
    return copyWith(sourceId: value);
  }

  /// Creates a copy with a different media type.
  PlayerInfo withMediaType(MediaType value) {
    return copyWith(mediaType: value);
  }

  /// Creates a copy with different media capabilities.
  PlayerInfo withMediaCapabilities(MediaCapabilities value) {
    return copyWith(mediaCapabilities: value);
  }

  /// Creates a copy with a different name.
  PlayerInfo withName(String value) {
    return copyWith(name: value);
  }

  /// Creates a copy with a different title.
  PlayerInfo withTitle(String value) {
    return copyWith(title: value);
  }

  /// Creates a copy with a different description.
  PlayerInfo withDescription(String value) {
    return copyWith(description: value);
  }

  /// Creates a copy with a different source URI.
  PlayerInfo withUri(Uri value) {
    return copyWith(uri: value);
  }

  /// Creates a copy with a different creation time.
  PlayerInfo withCreatedAt(DateTime value) {
    return copyWith(createdAt: value);
  }

  /// Creates a copy with a different update time.
  PlayerInfo withUpdatedAt(DateTime value) {
    return copyWith(updatedAt: value);
  }

  /// Creates a copy with one metadata entry added or replaced.
  PlayerInfo withMetadata(String key, Object? value) {
    return copyWith(metadata: <String, Object?>{...metadata, key: value});
  }

  /// Creates a copy with multiple metadata entries added or replaced.
  PlayerInfo withMetadataMap(Map<String, Object?> values) {
    if (values.isEmpty) {
      return this;
    }

    return copyWith(metadata: <String, Object?>{...metadata, ...values});
  }

  /// Creates a copy without the session association.
  PlayerInfo withoutSession() {
    return PlayerInfo(
      playerId: playerId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without the request association.
  PlayerInfo withoutRequest() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without the generation association.
  PlayerInfo withoutGeneration() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without the source association.
  PlayerInfo withoutSource() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without the media type.
  PlayerInfo withoutMediaType() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without media capabilities.
  PlayerInfo withoutMediaCapabilities() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      name: name,
      title: title,
      description: description,
      uri: uri,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without the source URI.
  PlayerInfo withoutUri() {
    return PlayerInfo(
      playerId: playerId,
      sessionId: sessionId,
      requestId: requestId,
      generationId: generationId,
      sourceId: sourceId,
      mediaType: mediaType,
      mediaCapabilities: mediaCapabilities,
      name: name,
      title: title,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without one metadata entry.
  PlayerInfo withoutMetadata(String key) {
    if (!metadata.containsKey(key)) {
      return this;
    }

    final updated = <String, Object?>{...metadata}..remove(key);

    return copyWith(metadata: updated);
  }

  /// Creates a copy without any metadata.
  PlayerInfo clearMetadata() {
    if (metadata.isEmpty) {
      return this;
    }

    return copyWith(metadata: const <String, Object?>{});
  }

  /// Returns whether two instances refer to the same player.
  bool isSamePlayer(PlayerInfo other) {
    return playerId == other.playerId;
  }

  /// Returns whether two instances refer to the same session.
  bool isSameSession(PlayerInfo other) {
    return sessionId != null && other.sessionId != null && sessionId == other.sessionId;
  }

  /// Returns whether two instances refer to the same source.
  bool isSameSource(PlayerInfo other) {
    return sourceId != null && other.sourceId != null && sourceId == other.sourceId;
  }

  /// Returns whether two instances refer to the same generation.
  bool isSameGeneration(PlayerInfo other) {
    return generationId != null && other.generationId != null && generationId == other.generationId;
  }

  @override
  List<Object?> get props => <Object?>[
    playerId,
    sessionId,
    requestId,
    generationId,
    sourceId,
    mediaType,
    mediaCapabilities,
    name,
    title,
    description,
    uri,
    createdAt,
    updatedAt,
    metadata,
  ];

  @override
  String toString() {
    return 'PlayerInfo('
        'playerId: $playerId, '
        'sessionId: $sessionId, '
        'requestId: $requestId, '
        'generationId: $generationId, '
        'sourceId: $sourceId, '
        'mediaType: $mediaType, '
        'mediaCapabilities: $mediaCapabilities, '
        'name: $name, '
        'title: $title, '
        'description: $description, '
        'uri: $uri, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'metadata: $metadata'
        ')';
  }
}
