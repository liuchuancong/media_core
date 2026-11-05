/// What the native side can actually do on this device (spec §13.2).
///
/// Every layer of this feature keeps "unknown" expressible, so the host
/// decides "should we try" instead of guessing from the iOS version. A
/// device without a Dynamic Island still supports the lock-screen activity.
final class MediaActivityCapabilitiesReport {
  /// Creates the capability report.
  const MediaActivityCapabilitiesReport({
    required this.isSupported,
    this.activitiesEnabled = false,
    this.frequentUpdatesEnabled = false,
    this.supportsDynamicIsland = false,
    this.systemMajorVersion = 0,
  });

  /// The app's default report: no native bridge (non-iOS platform, or the
  /// plugin is missing). Hosts treat this as "feature off", not an error.
  static const MediaActivityCapabilitiesReport unsupported =
      MediaActivityCapabilitiesReport(isSupported: false);

  /// The device can host Live Activities at all (iOS 16.1+, plugin loaded).
  final bool isSupported;

  /// The user has Live Activities enabled system-wide.
  final bool activitiesEnabled;

  /// The user granted frequent-update authorization for this app. The
  /// lyric-line cadence never needs it; it would matter for future
  /// higher-frequency content (spec §14).
  final bool frequentUpdatesEnabled;

  /// The device has a Dynamic Island — never inferred from the iOS version
  /// (spec §13.2: version is not a proxy for hardware).
  final bool supportsDynamicIsland;

  /// Major iOS version, for version-gated features (buttons need iOS 17).
  final int systemMajorVersion;

  /// Whether every gate is green: bridge present, system able, user allowed.
  bool get usable => isSupported && activitiesEnabled;

  @override
  String toString() =>
      'MediaActivityCapabilities(supported: $isSupported, enabled: '
      '$activitiesEnabled, island: $supportsDynamicIsland, iOS $systemMajorVersion)';
}
