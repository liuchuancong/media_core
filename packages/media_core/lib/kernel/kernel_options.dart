import '../core/player_constants.dart';
import '../recovery/recovery_budget.dart';
import '../recovery/recovery_policy.dart';

/// Global options for the player kernel.
///
/// [KernelOptions] tunes cross-cutting behaviour of the
/// orchestration layer. Per-player overrides come from
/// [PlayerConfig] passed to `PlayerKernel.create`.
///
/// Responsibilities:
///
/// - describe kernel-wide defaults
/// - tune recovery and fallback behaviour
/// - supply the recovery budget and ladder policy every player starts from
///
/// It does not:
///
/// - store per-player state
/// - make policy decisions for a single player
/// - decide when a specific player recovers (the ladder does)
final class KernelOptions {
  /// Creates kernel options.
  const KernelOptions({
    this.enableRecovery = true,
    this.enableFallback = true,
    this.enablePool = true,
    this.enableEventBus = true,
    this.maxRecoveryAttempts = PlayerConstants.maxRecoveryAttempts,
    this.maxFallbackAttempts = PlayerConstants.maxFallbackAttempts,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.retryMaxDelay = const Duration(seconds: 8),
    this.recoveryBudget = RecoveryBudget.defaults,
    this.recoveryPolicy = const DefaultRecoveryLadderPolicy(),
  });

  /// Whether automatic error recovery is enabled.
  final bool enableRecovery;

  /// Whether automatic backend fallback is enabled.
  final bool enableFallback;

  /// Whether created players join the player pool.
  final bool enablePool;

  /// Whether kernel events are published to the event bus.
  final bool enableEventBus;

  /// Default maximum recovery attempts per error.
  ///
  /// A [PlayerConfig] with its own value wins.
  final int maxRecoveryAttempts;

  /// Default maximum fallback attempts per error.
  ///
  /// A [PlayerConfig] with its own value wins.
  final int maxFallbackAttempts;

  /// Base delay for the first recovery retry.
  ///
  /// Subsequent retries back off linearly up to [retryMaxDelay].
  final Duration retryBaseDelay;

  /// Upper bound for a single recovery retry delay.
  final Duration retryMaxDelay;

  /// Base attempt budget for every player's recovery ladder.
  ///
  /// Per-player [PlayerConfig] values narrow this budget; they never
  /// widen it. See [PlayerHandle.recoveryBudget] for the resolved value.
  final RecoveryBudget recoveryBudget;

  /// Policy the recovery ladder consults for the entry decision.
  ///
  /// Defaults to the error-policy-backed policy, which classifies the
  /// failure through the error module and maps its recommendation onto an
  /// escalation. Override it to change recovery behaviour kernel-wide
  /// without editing the ladder.
  final RecoveryLadderPolicy recoveryPolicy;

  /// Creates a copy with modifications.
  KernelOptions copyWith({
    bool? enableRecovery,
    bool? enableFallback,
    bool? enablePool,
    bool? enableEventBus,
    int? maxRecoveryAttempts,
    int? maxFallbackAttempts,
    Duration? retryBaseDelay,
    Duration? retryMaxDelay,
    RecoveryBudget? recoveryBudget,
    RecoveryLadderPolicy? recoveryPolicy,
  }) {
    return KernelOptions(
      enableRecovery: enableRecovery ?? this.enableRecovery,
      enableFallback: enableFallback ?? this.enableFallback,
      enablePool: enablePool ?? this.enablePool,
      enableEventBus: enableEventBus ?? this.enableEventBus,
      maxRecoveryAttempts: maxRecoveryAttempts ?? this.maxRecoveryAttempts,
      maxFallbackAttempts: maxFallbackAttempts ?? this.maxFallbackAttempts,
      retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      recoveryBudget: recoveryBudget ?? this.recoveryBudget,
      recoveryPolicy: recoveryPolicy ?? this.recoveryPolicy,
    );
  }
}
