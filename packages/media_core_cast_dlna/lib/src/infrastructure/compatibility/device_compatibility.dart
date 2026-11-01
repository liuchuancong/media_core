import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';

/// One vendor/model family's protocol quirks (§9, Phase 9).
///
/// Real renderers disagree with the spec in a handful of known ways:
/// some want a non-zero `InstanceID`, some choke on the quoted
/// `SOAPACTION` header, some only Seek in a nonstandard unit, some
/// refuse a DIDL payload entirely. A profile describes one such family
/// — matched against the device's own description, never against a
/// hard-coded IP — and the services read their variations from it.
///
/// Rules the package enforces on profiles (§30.3):
/// - a spec-conformant device never needs one (the standard profile is all
///   defaults and matches everything as the last resort);
/// - quirks live here, not in the protocol code — adding a profile
///   never touches the domain model;
/// - every field has the spec-conformant default, so a profile only
///   states the *differences*.
final class DeviceCompatibilityProfile {
  /// Creates a profile.
  ///
  /// [matches] decides whether this profile governs a device; the
  /// first matching profile in the registry wins.
  const DeviceCompatibilityProfile({
    required this.id,
    required this.description,
    this.matches = _matchEverything,
    this.instanceId = 0,
    this.unquotedSoapAction = false,
    this.seekUnit = 'REL_TIME',
    this.playSpeed = '1',
    this.omitDidl = false,
  });

  /// The spec-conformant profile every device falls back to.
  const DeviceCompatibilityProfile.standard()
    : id = 'standard',
      description = 'spec-conformant UPnP AV renderer',
      matches = _matchEverything,
      instanceId = 0,
      unquotedSoapAction = false,
      seekUnit = 'REL_TIME',
      playSpeed = '1',
      omitDidl = false;

  /// The profile identity, for logs and tests.
  final String id;

  /// Why this profile exists and which devices it was written for —
  /// the record a maintainer reads before touching it.
  final String description;

  /// Whether this profile governs the device. Match on description
  /// fields (manufacturer, model, deviceType, service versions) —
  /// never on addresses or names a DHCP server or user can change.
  final bool Function(DlnaDevice device) matches;

  /// The `InstanceID` this family expects (§13.4: `0` on basic
  /// renderers, but some multi-instance stacks want otherwise).
  final int instanceId;

  /// Whether the `SOAPACTION` header must go without the spec's
  /// surrounding quotes.
  final bool unquotedSoapAction;

  /// The `Unit` value Seek uses (`REL_TIME` per spec; some stacks
  /// answer only to vendor units).
  final String seekUnit;

  /// The `Speed` value Play carries (`1` per spec).
  final String playSpeed;

  /// Whether `SetAVTransportURI` should be sent with an empty
  /// `CurrentURIMetaData` — a minority of firmwares reject DIDL
  /// outright.
  final bool omitDidl;

  static bool _matchEverything(DlnaDevice device) => true;
}

/// Resolves the profile that governs a device (§9, Phase 9 deliverable).
///
/// Custom profiles are consulted in registration order and the first
/// match wins; everything else falls back to
/// [DeviceCompatibilityProfile.standard]. The registry is the only
/// place vendor knowledge enters the package — the domain and the
/// protocol services read the resolved profile without knowing vendors
/// exist.
final class DeviceCompatibilityRegistry {
  /// Creates a registry, optionally seeded with [profiles] in priority
  /// order.
  DeviceCompatibilityRegistry({Iterable<DeviceCompatibilityProfile> profiles = const <DeviceCompatibilityProfile>[]})
    : _profiles = List<DeviceCompatibilityProfile>.of(profiles);

  final List<DeviceCompatibilityProfile> _profiles;

  /// The registered custom profiles, in priority order.
  List<DeviceCompatibilityProfile> get profiles => List<DeviceCompatibilityProfile>.unmodifiable(_profiles);

  /// Adds [profile]; the earlier a profile is registered, the higher
  /// its priority.
  void register(DeviceCompatibilityProfile profile) {
    _profiles.add(profile);
  }

  /// The profile governing [device]; never null — the standard profile
  /// is the terminal fallback.
  DeviceCompatibilityProfile profileFor(DlnaDevice device) {
    for (final profile in _profiles) {
      if (profile.matches(device)) {
        return profile;
      }
    }
    return const DeviceCompatibilityProfile.standard();
  }
}
