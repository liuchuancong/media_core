import 'package:meta/meta.dart';

/// A point-in-time diagnostic snapshot (§25.3).
///
/// Counts and flags a host can surface in a debug panel or health
/// check without reaching into package internals. Everything is read
/// from live state at [capturedAt]; nothing here is cached.
@immutable
final class DlnaDiagnostics {
  /// Creates a snapshot.
  const DlnaDiagnostics({
    required this.discoveredDeviceCount,
    required this.activeSessionCount,
    required this.mediaServerRunning,
    required this.discoveryRunning,
    required this.capturedAt,
  });

  /// How many devices discovery currently lists.
  final int discoveredDeviceCount;

  /// How many cast sessions are active.
  final int activeSessionCount;

  /// Whether the media server is serving.
  final bool mediaServerRunning;

  /// Whether discovery is running.
  final bool discoveryRunning;

  /// When the snapshot was taken.
  final DateTime capturedAt;

  @override
  String toString() =>
      'DlnaDiagnostics(devices: $discoveredDeviceCount, sessions: $activeSessionCount, '
      'server: $mediaServerRunning, discovery: $discoveryRunning)';
}
