import 'package:equatable/equatable.dart';

/// Represents one point-in-time memory usage snapshot.
///
/// A [MemorySnapshot] contains the memory information exposed by the
/// diagnostics layer at a specific point in time.
///
/// Responsibilities:
///
/// - record the snapshot timestamp
/// - store used memory
/// - store available memory
/// - store external memory usage when available
/// - provide basic memory usage calculations
///
/// It does not:
///
/// - query platform memory APIs
/// - periodically collect snapshots
/// - retain a history of snapshots
/// - decide whether memory usage is problematic
///
/// Those responsibilities belong to:
///
/// - MemoryMonitor
/// - DiagnosticsManager
final class MemorySnapshot extends Equatable {
  /// Creates a memory snapshot.
  const MemorySnapshot({
    required this.timestamp,
    required this.usedBytes,
    required this.availableBytes,
    this.externalBytes = 0,
  });

  /// Time at which this snapshot was created.
  final DateTime timestamp;

  /// Amount of memory currently in use, in bytes.
  final int usedBytes;

  /// Amount of memory currently available, in bytes.
  final int availableBytes;

  /// Amount of externally allocated memory, in bytes.
  ///
  /// The meaning of external memory depends on the platform and the
  /// underlying memory provider.
  final int externalBytes;

  /// Total memory represented by [usedBytes] and [availableBytes].
  int get totalBytes {
    return usedBytes + availableBytes;
  }

  /// Ratio of used memory to total represented memory.
  ///
  /// Returns `null` when the total memory is not positive.
  double? get usageRatio {
    final total = totalBytes;

    if (total <= 0) {
      return null;
    }

    return usedBytes / total;
  }

  /// Creates a copy with selected values replaced.
  MemorySnapshot copyWith({DateTime? timestamp, int? usedBytes, int? availableBytes, int? externalBytes}) {
    return MemorySnapshot(
      timestamp: timestamp ?? this.timestamp,
      usedBytes: usedBytes ?? this.usedBytes,
      availableBytes: availableBytes ?? this.availableBytes,
      externalBytes: externalBytes ?? this.externalBytes,
    );
  }

  /// Converts this snapshot into a serializable map.
  Map<String, Object?> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'usedBytes': usedBytes,
      'availableBytes': availableBytes,
      'externalBytes': externalBytes,
    };
  }

  @override
  List<Object?> get props => [timestamp, usedBytes, availableBytes, externalBytes];

  @override
  String toString() {
    return 'MemorySnapshot('
        'timestamp: $timestamp, '
        'usedBytes: $usedBytes, '
        'availableBytes: $availableBytes, '
        'externalBytes: $externalBytes'
        ')';
  }
}
