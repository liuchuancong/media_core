import 'memory_snapshot.dart';
import 'package:clock/clock.dart';

/// Provides memory diagnostics for the media core.
///
/// A [MemoryMonitor] stores the latest memory snapshot and can either receive
/// measurements from an external platform-specific provider or record values
/// supplied directly by the caller.
///
/// Responsibilities:
///
/// - store the latest memory snapshot
/// - accept externally collected memory measurements
/// - record explicitly supplied memory measurements
/// - expose the latest memory state
///
/// It does not:
///
/// - query operating-system memory APIs
/// - decide which platform API should be used
/// - periodically schedule memory collection
/// - retain a history of memory snapshots
/// - determine whether memory usage is excessive
///
/// Those responsibilities belong to:
///
/// - platform-specific memory providers
/// - DiagnosticsManager
/// - the caller consuming diagnostic information
typedef MemorySnapshotProvider = MemorySnapshot Function();

/// Monitors memory usage information.
///
/// [MemoryMonitor] intentionally does not depend on a platform memory API.
/// Platform integrations can provide a [MemorySnapshotProvider], while tests
/// and higher-level components can directly record measurements.
final class MemoryMonitor {
  /// Creates a memory monitor.
  MemoryMonitor({MemorySnapshotProvider? provider}) : _provider = provider;

  /// Optional platform-specific memory snapshot provider.
  MemorySnapshotProvider? _provider;

  /// Latest recorded memory snapshot.
  MemorySnapshot? _lastSnapshot;

  /// Whether this monitor has been disposed.
  bool _disposed = false;

  /// Latest available memory snapshot.
  MemorySnapshot? get snapshot {
    return _lastSnapshot;
  }

  /// Replaces the memory snapshot provider.
  ///
  /// Passing `null` disables provider-based sampling.
  void setProvider(MemorySnapshotProvider? provider) {
    _ensureNotDisposed();

    _provider = provider;
  }

  /// Collects a memory snapshot from the configured provider.
  ///
  /// Returns `null` when no provider has been configured.
  MemorySnapshot? sample() {
    _ensureNotDisposed();

    final provider = _provider;

    if (provider == null) {
      return null;
    }

    final snapshot = provider();

    _lastSnapshot = snapshot.copyWith(timestamp: clock.now());

    return _lastSnapshot;
  }

  /// Records a memory measurement supplied by the caller.
  ///
  /// [usedBytes] and [availableBytes] are expressed in bytes.
  MemorySnapshot record({required int usedBytes, required int availableBytes, int externalBytes = 0}) {
    _ensureNotDisposed();

    final snapshot = MemorySnapshot(
      timestamp: clock.now(),
      usedBytes: usedBytes,
      availableBytes: availableBytes,
      externalBytes: externalBytes,
    );

    _lastSnapshot = snapshot;

    return snapshot;
  }

  /// Clears the latest memory snapshot.
  void clear() {
    _ensureNotDisposed();

    _lastSnapshot = null;
  }

  /// Disposes the memory monitor.
  ///
  /// The configured provider and the retained snapshot are released.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _provider = null;
    _lastSnapshot = null;
  }

  /// Ensures the monitor has not been disposed.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('MemoryMonitor has been disposed.');
    }
  }
}
