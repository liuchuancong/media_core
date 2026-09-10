import 'network_snapshot.dart';
import 'package:clock/clock.dart';

/// Monitors network activity for the media core.
///
/// A [NetworkMonitor] maintains the latest aggregate network diagnostics.
/// It does not own the underlying network implementation and receives
/// measurements from the network layer or a platform integration.
///
/// Responsibilities:
///
/// - maintain the latest network snapshot
/// - track active network requests
/// - track transferred bytes
/// - record latency measurements
/// - record transfer rates
/// - maintain connection state
///
/// It does not:
///
/// - create network clients
/// - perform network requests
/// - monitor sockets directly
/// - determine network connectivity by itself
/// - retain a history of network snapshots
///
/// Those responsibilities belong to:
///
/// - network/source modules
/// - platform-specific network integrations
/// - DiagnosticsManager
final class NetworkMonitor {
  /// Creates a network monitor.
  NetworkMonitor() : _snapshot = NetworkSnapshot(timestamp: clock.now());

  /// Latest network snapshot.
  NetworkSnapshot _snapshot;

  /// Whether this monitor has been disposed.
  bool _disposed = false;

  /// Current network snapshot.
  NetworkSnapshot get snapshot {
    return _snapshot;
  }

  /// Updates the current connection state.
  void setConnected(bool connected) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(timestamp: clock.now(), connected: connected);
  }

  /// Updates the number of active network requests.
  ///
  /// Negative values are normalized to zero.
  void setActiveRequests(int count) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(timestamp: clock.now(), activeRequests: count < 0 ? 0 : count);
  }

  /// Records received network bytes.
  ///
  /// [bytes] represents the number of newly received bytes.
  void recordReceived(int bytes) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(timestamp: clock.now(), bytesReceived: _snapshot.bytesReceived + bytes);
  }

  /// Records sent network bytes.
  ///
  /// [bytes] represents the number of newly sent bytes.
  void recordSent(int bytes) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(timestamp: clock.now(), bytesSent: _snapshot.bytesSent + bytes);
  }

  /// Records a network latency measurement.
  void recordLatency(Duration latency) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(timestamp: clock.now(), latency: latency);
  }

  /// Records current network transfer rates.
  ///
  /// Rates are expressed in bytes per second.
  void recordRates({double? downloadBytesPerSecond, double? uploadBytesPerSecond}) {
    _ensureNotDisposed();

    _snapshot = _snapshot.copyWith(
      timestamp: clock.now(),
      downloadRateBytesPerSecond: downloadBytesPerSecond,
      uploadRateBytesPerSecond: uploadBytesPerSecond,
    );
  }

  /// Resets accumulated network measurements.
  ///
  /// The current connection state is preserved because resetting diagnostic
  /// counters does not imply that the network connection has changed.
  void reset() {
    _ensureNotDisposed();

    _snapshot = NetworkSnapshot(timestamp: clock.now(), connected: _snapshot.connected);
  }

  /// Disposes the network monitor.
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
  }

  /// Ensures the monitor has not been disposed.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('NetworkMonitor has been disposed.');
    }
  }
}
