import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/value_objects/service_type.dart';

/// A DLNA/UPnP device discovery has resolved from its description
/// document.
///
/// Identity rules the rest of the package relies on: the [udn] is the
/// one stable identifier, an IP address is not (DHCP re-assigns, and
/// one proxy address can front several devices), and neither is the
/// friendly name (users rename their TVs).
final class DlnaDevice {
  /// Creates a device.
  const DlnaDevice({
    required this.udn,
    required this.friendlyName,
    required this.deviceType,
    required this.location,
    required this.services,
    required this.discoveredAt,
    required this.lastSeenAt,
    this.manufacturer,
    this.modelName,
    this.modelNumber,
    this.presentationUrl,
    this.maxAge = const Duration(seconds: 30),
  });

  /// The unique device name (`uuid:...`), stable across re-announcements.
  final String udn;

  /// Device-reported display name; a UI label, never an identifier.
  final String friendlyName;

  /// Full device type URN, e.g.
  /// `urn:schemas-upnp-org:device:MediaRenderer:1`.
  final String deviceType;

  /// Where the description document was fetched from.
  final Uri location;

  /// Every service the description advertises, root and embedded
  /// devices alike — a renderer hub often parks its AVTransport on an
  /// embedded device.
  final List<DlnaService> services;

  /// Manufacturer as advertised.
  final String? manufacturer;

  /// Model as advertised.
  final String? modelName;

  /// Model number as advertised.
  final String? modelNumber;

  /// The device's own web UI, when it advertises one.
  final Uri? presentationUrl;

  /// When this device was first resolved.
  final DateTime discoveredAt;

  /// When the latest announcement (or search response) confirmed it.
  final DateTime lastSeenAt;

  /// How long the announcement that last confirmed this device stays
  /// valid, from its `CACHE-CONTROL: max-age`.
  final Duration maxAge;

  /// Whether the device type URN declares a MediaRenderer.
  ///
  /// A false result does not disqualify the device by itself: the
  /// castable check is the AVTransport service, and plenty of real
  /// hubs declare an odd root type while still carrying one.
  bool get isMediaRenderer => ServiceType.tryParse(deviceType)?.isMediaRenderer ?? false;

  /// The AVTransport endpoint every cast goes through, when present.
  DlnaService? get avTransport => _byName('AVTransport');

  /// The volume/mute endpoint, when the device has one.
  DlnaService? get renderingControl => _byName('RenderingControl');

  /// The protocol-info endpoint, when the device has one.
  DlnaService? get connectionManager => _byName('ConnectionManager');

  /// Rebuilds this device with announcement freshness refreshed.
  DlnaDevice renewed({required DateTime at, Duration? maxAge, Uri? location}) {
    return DlnaDevice(
      udn: udn,
      friendlyName: friendlyName,
      deviceType: deviceType,
      location: location ?? this.location,
      services: services,
      manufacturer: manufacturer,
      modelName: modelName,
      modelNumber: modelNumber,
      presentationUrl: presentationUrl,
      discoveredAt: discoveredAt,
      lastSeenAt: at,
      maxAge: maxAge ?? this.maxAge,
    );
  }

  DlnaService? _byName(String name) => services.where((service) => service.name == name).firstOrNull;
}
