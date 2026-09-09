/// Defines playback recovery policies.
///
/// [RecoveryPolicy] controls how the player
/// reacts after playback failures.
///
/// Responsibilities:
///
/// - retry configuration
/// - retry delay strategy
/// - automatic recovery rules
/// - fallback permission
///
/// It does not:
///
/// - execute retry operations
/// - schedule timers
/// - switch backend
///
/// Those belong to:
///
/// - RecoveryManager
/// - RetryScheduler
/// - FallbackManager
final class RecoveryPolicy {
  /// Creates recovery policy.
  const RecoveryPolicy({
    this.enabled = true,

    this.maxRetryCount = 3,

    this.retryDelay = const Duration(seconds: 2),

    this.exponentialBackoff = true,

    this.maxRetryDelay = const Duration(seconds: 30),

    this.retryOnNetworkError = true,

    this.retryOnDecoderError = true,

    this.allowBackendFallback = true,

    this.allowSourceFallback = true,
  });

  /// Whether recovery is enabled.
  final bool enabled;

  /// Maximum automatic retry count.
  final int maxRetryCount;

  /// Initial retry delay.
  final Duration retryDelay;

  /// Whether retry delay increases
  /// after every failure.
  final bool exponentialBackoff;

  /// Maximum retry delay.
  final Duration maxRetryDelay;

  /// Whether network failures can retry.
  final bool retryOnNetworkError;

  /// Whether decoder failures can retry.
  final bool retryOnDecoderError;

  /// Whether backend fallback is allowed.
  final bool allowBackendFallback;

  /// Whether alternate source fallback
  /// is allowed.
  final bool allowSourceFallback;

  /// Whether another retry is possible.
  bool canRetry(int retryCount) {
    if (!enabled) {
      return false;
    }

    return retryCount < maxRetryCount;
  }

  /// Calculates retry delay.
  Duration getRetryDelay(int retryCount) {
    if (!exponentialBackoff) {
      return retryDelay;
    }

    final multiplier = 1 << retryCount;

    final delay = Duration(milliseconds: retryDelay.inMilliseconds * multiplier);

    if (delay > maxRetryDelay) {
      return maxRetryDelay;
    }

    return delay;
  }

  /// Whether fallback is allowed.
  bool canFallback() {
    return enabled && allowBackendFallback;
  }

  /// Creates modified policy.
  RecoveryPolicy copyWith({
    bool? enabled,

    int? maxRetryCount,

    Duration? retryDelay,

    bool? exponentialBackoff,

    Duration? maxRetryDelay,

    bool? retryOnNetworkError,

    bool? retryOnDecoderError,

    bool? allowBackendFallback,

    bool? allowSourceFallback,
  }) {
    return RecoveryPolicy(
      enabled: enabled ?? this.enabled,

      maxRetryCount: maxRetryCount ?? this.maxRetryCount,

      retryDelay: retryDelay ?? this.retryDelay,

      exponentialBackoff: exponentialBackoff ?? this.exponentialBackoff,

      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,

      retryOnNetworkError: retryOnNetworkError ?? this.retryOnNetworkError,

      retryOnDecoderError: retryOnDecoderError ?? this.retryOnDecoderError,

      allowBackendFallback: allowBackendFallback ?? this.allowBackendFallback,

      allowSourceFallback: allowSourceFallback ?? this.allowSourceFallback,
    );
  }

  @override
  String toString() {
    return 'RecoveryPolicy('
        'enabled=$enabled, '
        'retry=$maxRetryCount, '
        'fallback=$allowBackendFallback'
        ')';
  }
}
