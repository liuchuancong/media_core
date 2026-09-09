import 'memory_budget.dart';
import 'resource_pressure.dart';

/// Manages runtime memory resource usage.
///
/// [MemoryManager] tracks memory consumption inside
/// the media core resource layer and evaluates
/// memory pressure according to [MemoryBudget].
///
/// Responsibilities:
///
/// - track allocated memory
/// - evaluate memory pressure
/// - calculate available memory
/// - provide memory usage information
///
/// It does not:
///
/// - allocate native memory
/// - release player resources
/// - force garbage collection
/// - destroy decoders
/// - control playback lifecycle
///
/// Those responsibilities belong to:
///
/// - PlayerPool
/// - DecoderManager
/// - ResourceManager
/// - Platform memory layer
///
/// Memory flow:
///
/// ```text
/// Runtime Components
///        |
///        v
/// MemoryManager
///        |
///        +--> MemoryBudget
///        |
///        v
/// ResourcePressure
/// ```
final class MemoryManager {
  /// Creates memory manager.
  MemoryManager({required this.budget});

  /// Memory limitation policy.
  final MemoryBudget budget;

  /// Current tracked memory usage.
  int _memoryBytes = 0;

  /// Current memory usage.
  int get memoryBytes {
    return _memoryBytes;
  }

  /// Returns whether memory pressure exists.
  bool get hasPressure {
    return pressure != ResourcePressure.none;
  }

  /// Current memory pressure level.
  ResourcePressure get pressure {
    if (!budget.enabled) {
      return ResourcePressure.none;
    }

    if (budget.isExceeded(_memoryBytes)) {
      return ResourcePressure.emergency;
    }

    if (budget.isCritical(_memoryBytes)) {
      return ResourcePressure.critical;
    }

    if (budget.isWarning(_memoryBytes)) {
      return ResourcePressure.warning;
    }

    return ResourcePressure.none;
  }

  /// Updates current memory usage.
  ///
  /// This method only updates tracked state.
  ///
  /// It does not allocate or release memory.
  void updateUsage(int bytes) {
    _memoryBytes = bytes < 0 ? 0 : bytes;
  }

  /// Adds memory usage.
  ///
  /// Used when a component reports
  /// additional resource consumption.
  void addUsage(int bytes) {
    if (bytes <= 0) {
      return;
    }

    _memoryBytes += bytes;
  }

  /// Removes memory usage.
  ///
  /// This only changes accounting.
  ///
  /// Actual memory release is handled
  /// by resource owners.
  void removeUsage(int bytes) {
    if (bytes <= 0) {
      return;
    }

    _memoryBytes -= bytes;

    if (_memoryBytes < 0) {
      _memoryBytes = 0;
    }
  }

  /// Returns remaining memory capacity.
  int get remainingBytes {
    return budget.remainingBytes(_memoryBytes);
  }

  /// Whether memory cleanup should start.
  bool get shouldCleanup {
    return pressure == ResourcePressure.critical || pressure == ResourcePressure.emergency;
  }

  /// Whether emergency cleanup is required.
  bool get requiresEmergencyCleanup {
    return pressure == ResourcePressure.emergency;
  }

  /// Creates memory usage snapshot.
  MemoryUsageSnapshot snapshot() {
    return MemoryUsageSnapshot(memoryBytes: _memoryBytes, pressure: pressure);
  }

  /// Resets memory accounting.
  ///
  /// Used when the manager is disposed.
  void clear() {
    _memoryBytes = 0;
  }

  @override
  String toString() {
    return 'MemoryManager('
        'memory=${_memoryBytes ~/ 1024 ~/ 1024}MB, '
        'pressure=$pressure'
        ')';
  }
}

/// Represents memory usage snapshot.
///
/// This is an immutable view of memory state.
///
/// It does not perform any resource operation.
final class MemoryUsageSnapshot {
  /// Creates memory snapshot.
  const MemoryUsageSnapshot({required this.memoryBytes, required this.pressure});

  /// Current memory usage.
  final int memoryBytes;

  /// Current pressure level.
  final ResourcePressure pressure;

  /// Whether memory pressure exists.
  bool get hasPressure {
    return pressure != ResourcePressure.none;
  }

  @override
  String toString() {
    return 'MemoryUsageSnapshot('
        'memory=${memoryBytes ~/ 1024 ~/ 1024}MB, '
        'pressure=$pressure'
        ')';
  }
}
