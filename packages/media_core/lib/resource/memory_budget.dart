/// Defines memory resource limits.
///
/// [MemoryBudget] describes the memory consumption
/// limits used by the media core resource layer.
///
/// The budget provides threshold-based decisions
/// for memory pressure management.
///
/// Responsibilities:
///
/// - define maximum tracked memory
/// - define warning threshold
/// - define critical threshold
/// - determine whether memory usage is exceeded
/// - calculate remaining memory capacity
///
/// It does not:
///
/// - allocate memory
/// - release memory
/// - force garbage collection
/// - inspect native memory directly
/// - destroy player resources
///
/// Those responsibilities belong to:
///
/// - MemoryManager
/// - ResourceManager
/// - Platform memory layer
///
/// Memory flow:
///
/// ```text
///
/// Runtime Memory Usage
///          |
///          v
///    MemoryManager
///          |
///          v
///     MemoryBudget
///          |
///          +--> warning
///          +--> critical
///          +--> exceeded
///          |
///          v
///   ResourcePressure
///
/// ```
///
/// Threshold semantics:
///
/// ```text
///
/// 0
/// |
/// |  Normal
/// |
/// +---------------- warning threshold
/// |
/// |  Warning
/// |
/// +---------------- critical threshold
/// |
/// |  Critical
/// |
/// +---------------- maximum memory
/// |
/// |  Exceeded
/// v
///
/// ```
final class MemoryBudget {
  /// Creates a memory budget.
  ///
  /// [maxMemoryBytes] defines the maximum tracked
  /// memory usage.
  ///
  /// [warningThreshold] defines the percentage of
  /// the maximum budget at which warning pressure
  /// begins.
  ///
  /// [criticalThreshold] defines the percentage of
  /// the maximum budget at which critical pressure
  /// begins.
  const MemoryBudget({
    this.enabled = true,
    this.maxMemoryBytes = 512 * 1024 * 1024,
    this.warningThreshold = 0.70,
    this.criticalThreshold = 0.85,
  }) : assert(maxMemoryBytes > 0),
       assert(warningThreshold >= 0.0),
       assert(warningThreshold <= 1.0),
       assert(criticalThreshold >= 0.0),
       assert(criticalThreshold <= 1.0),
       assert(warningThreshold <= criticalThreshold);

  /// Whether memory budget enforcement is enabled.
  ///
  /// When disabled, memory usage is still tracked
  /// by [MemoryManager], but budget checks do not
  /// report pressure.
  final bool enabled;

  /// Maximum tracked memory usage.
  ///
  /// Unit:
  ///
  /// bytes
  ///
  /// The default value is 512 MiB.
  final int maxMemoryBytes;

  /// Memory usage ratio at which warning pressure
  /// begins.
  ///
  /// The value is expressed as a ratio between
  /// `0.0` and `1.0`.
  ///
  /// For example:
  ///
  /// `0.70` means 70 percent of the maximum
  /// memory budget.
  final double warningThreshold;

  /// Memory usage ratio at which critical pressure
  /// begins.
  ///
  /// The value is expressed as a ratio between
  /// `0.0` and `1.0`.
  ///
  /// For example:
  ///
  /// `0.85` means 85 percent of the maximum
  /// memory budget.
  final double criticalThreshold;

  /// Absolute memory amount at which warning
  /// pressure begins.
  int get warningBytes {
    return (maxMemoryBytes * warningThreshold).round();
  }

  /// Absolute memory amount at which critical
  /// pressure begins.
  int get criticalBytes {
    return (maxMemoryBytes * criticalThreshold).round();
  }

  /// Checks whether memory usage has reached
  /// the warning threshold.
  ///
  /// Warning is reported before critical pressure.
  bool isWarning(int memoryBytes) {
    if (!enabled) {
      return false;
    }

    return memoryBytes >= warningBytes && memoryBytes < criticalBytes;
  }

  /// Checks whether memory usage has reached
  /// the critical threshold.
  bool isCritical(int memoryBytes) {
    if (!enabled) {
      return false;
    }

    return memoryBytes >= criticalBytes && memoryBytes < maxMemoryBytes;
  }

  /// Checks whether memory usage has exceeded
  /// the maximum memory budget.
  bool isExceeded(int memoryBytes) {
    if (!enabled) {
      return false;
    }

    return memoryBytes >= maxMemoryBytes;
  }

  /// Checks whether any memory limitation
  /// threshold has been reached.
  bool hasPressure(int memoryBytes) {
    if (!enabled) {
      return false;
    }

    return memoryBytes >= warningBytes;
  }

  /// Returns remaining memory capacity.
  ///
  /// The returned value is never negative.
  int remainingBytes(int memoryBytes) {
    final remaining = maxMemoryBytes - memoryBytes;

    return remaining > 0 ? remaining : 0;
  }

  /// Returns the current memory usage ratio.
  ///
  /// The result is not greater than `1.0`.
  double usageRatio(int memoryBytes) {
    if (maxMemoryBytes <= 0) {
      return 1.0;
    }

    final ratio = memoryBytes / maxMemoryBytes;

    if (ratio <= 0.0) {
      return 0.0;
    }

    if (ratio >= 1.0) {
      return 1.0;
    }

    return ratio;
  }

  /// Returns whether a given memory amount can
  /// be accommodated within the budget.
  bool canAllocate(int additionalBytes, int currentBytes) {
    if (!enabled) {
      return true;
    }

    if (additionalBytes <= 0) {
      return true;
    }

    return currentBytes + additionalBytes <= maxMemoryBytes;
  }

  /// Creates a modified memory budget.
  MemoryBudget copyWith({bool? enabled, int? maxMemoryBytes, double? warningThreshold, double? criticalThreshold}) {
    return MemoryBudget(
      enabled: enabled ?? this.enabled,
      maxMemoryBytes: maxMemoryBytes ?? this.maxMemoryBytes,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
    );
  }

  @override
  String toString() {
    return 'MemoryBudget('
        'enabled=$enabled, '
        'max=${maxMemoryBytes ~/ 1024 ~/ 1024}MB, '
        'warning=${(warningThreshold * 100).round()}%, '
        'critical=${(criticalThreshold * 100).round()}%'
        ')';
  }
}
