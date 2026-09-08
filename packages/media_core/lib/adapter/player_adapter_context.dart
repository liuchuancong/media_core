import '../core/player_config.dart';
import '../identity/player_id.dart';
import 'player_adapter_config.dart';
import '../identity/session_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_adapter_context.freezed.dart';

/// Context provided when initializing a player adapter.
///
/// [PlayerAdapterContext] contains environment
/// information required by a playback backend.
///
/// Responsibilities:
///
/// - provide initialization dependencies
/// - provide player/session identity
/// - provide adapter options
///
/// It does not:
///
/// - manage playback state
/// - create adapters
/// - collect metrics
///
/// Those belong to:
///
/// - PlayerAdapterState
/// - PlayerAdapterFactory
/// - PlayerAdapterMetrics
@freezed
abstract class PlayerAdapterContext with _$PlayerAdapterContext {
  /// Creates adapter context.
  const factory PlayerAdapterContext({
    /// Player identifier.
    required PlayerId playerId,

    /// Playback session identifier.
    required SessionId sessionId,

    /// Adapter configuration.
    @Default(PlayerAdapterConfig()) PlayerAdapterConfig config,

    /// Player configuration.
    PlayerConfig? playerConfig,

    /// Backend specific options.
    @Default({}) Map<String, Object?> options,

    /// Debug mode.
    @Default(false) bool debug,
  }) = _PlayerAdapterContext;

  /// Creates minimal context.
  factory PlayerAdapterContext.basic({required PlayerId playerId, required SessionId sessionId}) {
    return PlayerAdapterContext(playerId: playerId, sessionId: sessionId);
  }
}

/// Extensions for adapter context.
extension PlayerAdapterContextExtension on PlayerAdapterContext {
  /// Whether custom options exist.
  bool get hasOptions {
    return options.isNotEmpty;
  }

  /// Gets backend option.
  T? option<T>(String key) {
    final value = options[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  /// Creates context with option.
  PlayerAdapterContext putOption(String key, Object? value) {
    return copyWith(options: {...options, key: value});
  }
}
