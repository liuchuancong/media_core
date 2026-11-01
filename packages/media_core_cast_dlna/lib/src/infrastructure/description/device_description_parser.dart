import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';

import 'package:xml/xml.dart';

/// Parses a UPnP device description document into a [DlnaDevice].
abstract final class DeviceDescriptionParser {
  /// Parses the description fetched from [location].
  ///
  /// The parser reads what the device actually sent: namespace prefixes
  /// differ across firmwares (matching is by local name), `URLBase` is
  /// honored when present, embedded devices contribute their services
  /// to the same record, and optional identity fields may be missing.
  /// Only a missing UDN or a document that is not a device description
  /// at all is fatal — pretending otherwise would let a half-read
  /// device into the picker under a broken identity.
  ///
  /// [maxAge] is the announcement lifetime that led here;
  /// [seenAt] overrides the discovery timestamp (tests inject a clock).
  static DlnaDevice parse(
    String xml, {
    required Uri location,
    Duration maxAge = const Duration(seconds: 30),
    DateTime? seenAt,
  }) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw DlnaDeviceDescriptionException('device description is not valid XML', cause: error);
    }

    final root = document.rootElement;
    if (root.localName != 'device' && root.localName != 'root') {
      throw const DlnaDeviceDescriptionException('device description root is not <device>/<root>');
    }

    final deviceElement = root.localName == 'root' ? _child(root, 'device') : root;
    if (deviceElement == null) {
      throw const DlnaDeviceDescriptionException('device description has no <device> element');
    }

    final udn = _text(deviceElement, 'UDN')?.trim();
    if (udn == null || udn.isEmpty) {
      throw const DlnaDeviceDescriptionException('device description has no UDN');
    }

    final base = _resolveBase(location, root);
    final now = seenAt ?? DateTime.now();

    // Services of the root device and of every embedded device feed
    // the same list: a media hub declares one renderer per output and
    // the AVTransport we can drive may sit below the root.
    final services = <DlnaService>[];
    for (final element in document.rootElement.descendantElements) {
      if (element.localName == 'serviceList') {
        services.addAll(_parseServices(element, base));
      }
    }

    final deviceType = _text(deviceElement, 'deviceType')?.trim() ?? '';
    final presentation = _text(deviceElement, 'presentationURL')?.trim();
    final friendlyName = _text(deviceElement, 'friendlyName')?.trim();

    return DlnaDevice(
      udn: udn,
      friendlyName: friendlyName == null || friendlyName.isEmpty ? udn : friendlyName,
      deviceType: deviceType,
      location: location,
      services: List<DlnaService>.unmodifiable(services),
      manufacturer: _text(deviceElement, 'manufacturer')?.trim(),
      modelName: _text(deviceElement, 'modelName')?.trim(),
      modelNumber: _text(deviceElement, 'modelNumber')?.trim(),
      presentationUrl: presentation == null ? null : _resolveUrl(base, presentation),
      discoveredAt: now,
      lastSeenAt: now,
      maxAge: maxAge,
    );
  }

  /// The base every relative service URL resolves against: `URLBase`
  /// when the document declares one, the description location's origin
  /// otherwise.
  static Uri _resolveBase(Uri location, XmlElement root) {
    for (final element in root.childElements) {
      if (element.localName.toLowerCase() == 'urlbase') {
        final raw = element.innerText.trim();
        if (raw.isNotEmpty) {
          return _resolveUrl(location, raw);
        }
      }
    }
    return Uri(scheme: location.scheme, host: location.host, port: location.hasPort ? location.port : null);
  }

  static List<DlnaService> _parseServices(XmlElement serviceList, Uri base) {
    final services = <DlnaService>[];
    for (final service in serviceList.childElements) {
      if (service.localName != 'service') {
        continue;
      }
      final type = _text(service, 'serviceType')?.trim();
      final control = _text(service, 'controlURL')?.trim();
      // A service without a type or a control URL cannot be called;
      // skipping it keeps the rest of the device usable.
      if (type == null || type.isEmpty || control == null || control.isEmpty) {
        continue;
      }
      final event = _text(service, 'eventSubURL')?.trim();
      final scpd = _text(service, 'SCPDURL')?.trim();
      services.add(
        DlnaService(
          serviceType: type,
          serviceId: _text(service, 'serviceId')?.trim(),
          controlUrl: _resolveUrl(base, control),
          eventSubUrl: event == null || event.isEmpty ? null : _resolveUrl(base, event),
          scpdUrl: scpd == null || scpd.isEmpty ? null : _resolveUrl(base, scpd),
        ),
      );
    }
    return services;
  }

  /// Resolves a (possibly relative) UPnP URL against [base].
  ///
  /// UPnP control URLs are notoriously mixed: some devices emit
  /// `/ctrl-avtransport`, some `ctrl-avtransport` with no slash, some
  /// full absolute URLs. The bare-relative form must not resolve
  /// against the location's *path* (which for `/description.xml` would
  /// yield a wrong sibling path), so it is anchored at the origin.
  static Uri _resolveUrl(Uri base, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    if (url.startsWith('/')) {
      return base.replace(path: url);
    }
    return base.replace(path: '/$url');
  }

  static XmlElement? _child(XmlElement parent, String name) {
    for (final element in parent.children.whereType<XmlElement>()) {
      if (element.localName == name) {
        return element;
      }
    }
    return null;
  }

  static String? _text(XmlElement parent, String name) {
    for (final element in parent.childElements) {
      if (element.localName == name) {
        return element.innerText;
      }
    }
    return null;
  }
}
