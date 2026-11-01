import 'package:media_core_cast_dlna/src/domain/value_objects/service_type.dart';

/// A UPnP service a device advertises, with its endpoints resolved.
final class DlnaService {
  /// Creates a service entry.
  const DlnaService({
    required this.serviceType,
    required this.controlUrl,
    this.serviceId,
    this.eventSubUrl,
    this.scpdUrl,
  });

  /// Full service type URN, e.g.
  /// `urn:schemas-upnp-org:service:AVTransport:1`.
  final String serviceType;

  /// Full service id URN (e.g. `urn:upnp-org:serviceId:AVTransport`),
  /// when the description carries one.
  final String? serviceId;

  /// Absolute control endpoint — the SOAP POST target.
  ///
  /// Resolution follows the UPnP rules: an absolute URL passes through,
  /// otherwise it resolves against `URLBase` when the description
  /// declares one, else against the description document's origin.
  final Uri controlUrl;

  /// Absolute eventing endpoint (a GENA `SUBSCRIBE` target), when
  /// advertised.
  final Uri? eventSubUrl;

  /// Absolute URL of the SCPD document declaring this service's actions,
  /// when advertised.
  final Uri? scpdUrl;

  /// The short service name (`AVTransport`, `RenderingControl`), read
  /// from the type URN.
  String get name {
    final parsed = _type;
    return parsed?.name ?? serviceType;
  }

  /// The parsed type URN, when the device emitted a well-formed one.
  ServiceType? get _type => ServiceType.tryParse(serviceType);
}
