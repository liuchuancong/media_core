import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/generation_id.dart';
import 'package:media_core/src/identity/operation_id.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/request_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/slot_id.dart';
import 'package:media_core/src/identity/source_id.dart';

part 'error_context.g.dart';

/// Structured runtime context associated with a player error.
///
/// [ErrorContext] contains diagnostic information about where and when
/// an error occurred.
///
/// It intentionally does not contain:
/// - error classification;
/// - retry policy;
/// - fallback policy;
/// - recovery decisions;
/// - user-facing message formatting.
///
/// Those responsibilities belong to other layers of the architecture.
abstract class ErrorContext implements Built<ErrorContext, ErrorContextBuilder> {
  /// Builds ErrorContext from a [updates] callback — the codegen entry.
  factory ErrorContext([void Function(ErrorContextBuilder)? updates]) = _$ErrorContext;

  /// Creates a context from the diagnostic fields known when the failure was recorded.
  factory ErrorContext.of({
    PlayerId? playerId,
    SessionId? sessionId,
    SlotId? slotId,
    SourceId? sourceId,
    RequestId? requestId,
    OperationId? operationId,
    GenerationId? generationId,
    String? operation,
    String? lineId,
    String? quality,
    String? uri,
    String? platform,
    String? backend,
    String? adapter,
    String? state,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return ErrorContext(
      (builder) => builder
        ..playerId = playerId
        ..sessionId = sessionId
        ..slotId = slotId
        ..sourceId = sourceId
        ..requestId = requestId
        ..operationId = operationId
        ..generationId = generationId
        ..operation = operation
        ..lineId = lineId
        ..quality = quality
        ..uri = uri
        ..platform = platform
        ..backend = backend
        ..adapter = adapter
        ..state = state
        ..metadata = metadata,
    );
  }

  ErrorContext._();

  /// A context records nothing until the reporter fills a field in.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ErrorContextBuilder builder) => builder..metadata = const <String, Object?>{};

  /// PlayerIdentity instance associated with the failure.
  PlayerId? get playerId;

  /// PlayerIdentity session associated with the failure.
  SessionId? get sessionId;

  /// PlayerIdentity slot associated with the failure.
  SlotId? get slotId;

  /// Media source associated with the failure.
  SourceId? get sourceId;

  /// Request associated with the failure.
  RequestId? get requestId;

  /// High-level operation associated with the failure.
  OperationId? get operationId;

  /// Generation associated with the failure.
  ///
  /// This is useful for detecting stale asynchronous work.
  GenerationId? get generationId;

  /// Human-readable operation name.
  String? get operation;

  /// Optional source line identifier.
  String? get lineId;

  /// Optional requested quality identifier.
  String? get quality;

  /// Media URI associated with the operation.
  ///
  /// This should be treated as diagnostic data and may contain sensitive
  /// or credential-bearing information. Callers should sanitize it before
  /// displaying or persisting it externally.
  String? get uri;

  /// Platform identifier.
  String? get platform;

  /// Backend identifier.
  String? get backend;

  /// Adapter identifier.
  String? get adapter;

  /// PlayerIdentity state at the time of the failure.
  String? get state;

  /// Additional structured diagnostic metadata.
  Map<String, Object?> get metadata;

  ///
  /// Whether the failure is attributed to a specific player instance.
  bool get hasPlayerId => playerId != null;

  ///
  /// Whether the failure is attributed to a specific playback session.
  bool get hasSessionId => sessionId != null;

  ///
  /// Whether the failure happened inside a pooled player slot.
  bool get hasSlotId => slotId != null;

  ///
  /// Whether the failure is attributed to a specific media source.
  bool get hasSourceId => sourceId != null;

  ///
  /// Whether the failure is tied to one network or backend request.
  bool get hasRequestId => requestId != null;

  ///
  /// Whether the failure is tied to one high-level operation.
  bool get hasOperationId => operationId != null;

  ///
  /// Whether the failure carries the generation it occurred in, which is what lets stale reports be recognised.
  bool get hasGenerationId => generationId != null;

  ///
  /// Whether a human-readable operation name is attached.
  bool get hasOperation => _hasText(operation);

  ///
  /// Whether the failing delivery line of the source is known.
  bool get hasLineId => _hasText(lineId);

  ///
  /// Whether the quality level requested for the failure is known.
  bool get hasQuality => _hasText(quality);

  ///
  /// Whether a media URI is attached; it may carry credentials and must be sanitized before display.
  bool get hasUri => _hasText(uri);

  ///
  /// Whether the platform the failure came from is recorded.
  bool get hasPlatform => _hasText(platform);

  ///
  /// Whether the backend that failed is recorded.
  bool get hasBackend => _hasText(backend);

  ///
  /// Whether the adapter that failed is recorded.
  bool get hasAdapter => _hasText(adapter);

  ///
  /// Whether the player state at failure time is recorded.
  bool get hasState => _hasText(state);

  ///
  /// Whether any additional diagnostic metadata is attached.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether this context contains any diagnostic information.
  bool get isEmpty {
    return !hasPlayerId &&
        !hasSessionId &&
        !hasSlotId &&
        !hasSourceId &&
        !hasRequestId &&
        !hasOperationId &&
        !hasGenerationId &&
        !hasOperation &&
        !hasLineId &&
        !hasQuality &&
        !hasUri &&
        !hasPlatform &&
        !hasBackend &&
        !hasAdapter &&
        !hasState &&
        !hasMetadata;
  }

  ///
  /// Whether this context carries at least one diagnostic field.
  bool get isNotEmpty => !isEmpty;

  /// Returns an immutable copy of the metadata map.
  Map<String, Object?> get metadataView {
    return Map<String, Object?>.unmodifiable(metadata);
  }

  /// Returns whether [key] exists in metadata.
  bool containsMetadata(String key) {
    return metadata.containsKey(key);
  }

  /// Returns a metadata value.
  Object? metadataValue(String key) {
    return metadata[key];
  }

  /// Returns a typed metadata value when the stored value has the
  /// requested type.
  T? metadataAs<T>(String key) {
    final value = metadata[key];

    if (value is T) {
      return value;
    }

    return null;
  }
}

// =============================================================================
// Helpers
// =============================================================================

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}
