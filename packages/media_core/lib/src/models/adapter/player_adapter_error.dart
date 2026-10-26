import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/adapter/player_adapter_error_type.dart';

part 'player_adapter_error.g.dart';

/// Error produced by a player adapter.
///
/// [PlayerAdapterError] represents backend-specific
/// playback failures in a normalized format.
///
/// Responsibilities:
///
/// - describe adapter failures
/// - classify recoverability
/// - provide debugging context
///
/// It does not:
///
/// - perform recovery
/// - retry operations
/// - write logs
///
/// Those belong to:
///
/// - RecoveryManager
/// - DiagnosticsManager
abstract class PlayerAdapterError implements Built<PlayerAdapterError, PlayerAdapterErrorBuilder> {
  /// Builds PlayerAdapterError from a [updates] callback — the codegen entry.
  factory PlayerAdapterError([void Function(PlayerAdapterErrorBuilder)? updates]) = _$PlayerAdapterError;

  /// Creates adapter error.
  factory PlayerAdapterError.of({
    required PlayerAdapterErrorType type,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
    bool recoverable = false,
    String? backend,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return PlayerAdapterError(
      (builder) => builder
        ..type = type
        ..message = message
        ..cause = cause
        ..stackTrace = stackTrace
        ..recoverable = recoverable
        ..backend = backend
        ..metadata = metadata,
    );
  }

  /// Creates an unknown error.
  factory PlayerAdapterError.unknown(Object error) {
    return PlayerAdapterError.of(
      type: PlayerAdapterErrorType.unknown,
      message: error.toString(),
      cause: error,
    );
  }

  PlayerAdapterError._();

  /// A backend error is not automatically worth recovering and carries no
  /// metadata until the backend says otherwise.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerAdapterErrorBuilder builder) => builder
    ..recoverable = false
    ..metadata = const <String, Object?>{};

  /// Error category.
  PlayerAdapterErrorType get type;

  /// Human readable message.
  String get message;

  /// Original backend error.
  Object? get cause;

  /// Stack trace.
  StackTrace? get stackTrace;

  /// Whether error can recover automatically.
  bool get recoverable;

  /// Backend identifier.
  String? get backend;

  /// Additional metadata.
  Map<String, Object?> get metadata;
}

/// Extensions for adapter errors.
extension PlayerAdapterErrorExtension on PlayerAdapterError {
  /// Whether this error is related to network.
  bool get isNetwork {
    return type == PlayerAdapterErrorType.network;
  }

  /// Whether this error may require backend switch.
  bool get requiresFallback {
    return switch (type) {
      PlayerAdapterErrorType.unsupportedFormat ||
      PlayerAdapterErrorType.decoder ||
      PlayerAdapterErrorType.hardwareDecoder ||
      PlayerAdapterErrorType.backend => true,
      _ => false,
    };
  }

  /// Whether retry may succeed.
  bool get retryable {
    return recoverable || isNetwork;
  }
}
