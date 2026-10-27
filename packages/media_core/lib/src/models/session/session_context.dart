import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/generation_id.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/models/source/player_source.dart';
import 'package:media_core/src/platform/capability/platform_capabilities.dart';
import 'package:media_core/src/policy/session/player_policy.dart';

part 'session_context.g.dart';

/// Runtime context of a player session.
///
/// [SessionContext] contains immutable dependencies
/// required during one playback session.
///
/// Responsibilities:
///
/// - provide session identity
/// - provide source information
/// - provide runtime policies
/// - provide platform capabilities
///
/// It does not:
///
/// - execute playback
/// - manage lifecycle
///
/// Those belong to:
///
/// - PlayerSession
/// - SessionController
abstract class SessionContext implements Built<SessionContext, SessionContextBuilder> {
  /// Builds SessionContext from a [updates] callback — the codegen entry.
  factory SessionContext([void Function(SessionContextBuilder)? updates]) = _$SessionContext;

  /// Creates a session context.
  factory SessionContext.of({
    required PlayerId playerId,
    required SessionId sessionId,
    required GenerationId generationId,
    required SourceId sourceId,
    required PlayerSource source,
    PlayerPolicy policy = const PlayerPolicy(),
    PlatformCapabilities platform = const PlatformCapabilities(),
  }) {
    return SessionContext(
      (builder) => builder
        ..playerId = playerId
        ..sessionId = sessionId
        ..generationId = generationId
        ..sourceId = sourceId
        ..source = source.toBuilder()
        ..policy = policy
        ..platform = platform,
    );
  }

  SessionContext._();

  /// A session runs under the default policy and the capabilities the platform
  /// reports when nobody overrides either.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SessionContextBuilder builder) => builder
    ..policy = const PlayerPolicy()
    ..platform = const PlatformCapabilities();

  /// PlayerIdentity identity.
  PlayerId get playerId;

  /// Session identity.
  SessionId get sessionId;

  /// Current session generation.
  GenerationId get generationId;

  /// Source identity.
  SourceId get sourceId;

  /// Current media source.
  PlayerSource get source;

  /// PlayerIdentity policies.
  PlayerPolicy get policy;

  /// Platform capabilities.
  PlatformCapabilities get platform;

  /// Whether context belongs to another generation.
  bool isGeneration(GenerationId id) {
    return generationId == id;
  }
}
