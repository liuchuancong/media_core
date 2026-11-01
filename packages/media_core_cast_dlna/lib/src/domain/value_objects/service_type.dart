import 'package:meta/meta.dart';

/// A parsed UPnP type URN, device or service.
///
/// UPnP identifies devices and services with URNs shaped
/// `urn:<domain>:<device|service>:<name>:<version>`, e.g.
/// `urn:schemas-upnp-org:device:MediaRenderer:1`. Deciding whether a
/// discovered device is a renderer (and which service versions it
/// speaks) must come from these URNs — never from the friendly name,
/// which is free text a user edits on the TV.
@immutable
final class ServiceType {
  /// Creates a parsed URN.
  const ServiceType({required this.domain, required this.kind, required this.name, required this.version});

  /// Parses a URN, throwing [FormatException] when it is not a UPnP
  /// type URN at all.
  factory ServiceType.parse(String urn) {
    final parsed = tryParse(urn);
    if (parsed == null) {
      throw FormatException('not a UPnP device/service type URN', urn);
    }
    return parsed;
  }

  /// The URN domain segment (`schemas-upnp-org`, vendor domains, ...).
  final String domain;

  /// Either `device` or `service`.
  final String kind;

  /// The type name (`MediaRenderer`, `AVTransport`, ...).
  final String name;

  /// The numeric version, when the device emitted one a human can read;
  /// some firmwares pad this field with junk and a parser that insisted
  /// on an integer would drop the device entirely.
  final int? version;

  /// Whether this URN declares a device type.
  bool get isDevice => kind == 'device';

  /// Whether this URN declares a service type.
  bool get isService => kind == 'service';

  /// Whether this is any version of the UPnP MediaRenderer device.
  bool get isMediaRenderer => isDevice && name == 'MediaRenderer';

  /// Parses a URN, returning null when malformed.
  ///
  /// Real descriptions carry just enough variety (missing versions,
  /// `urn:domain:service:Name` with three segments) that a lenient
  /// reader beats a strict one: a service whose version cannot be read
  /// is still a service.
  static ServiceType? tryParse(String urn) {
    final value = urn.trim();
    if (!value.toLowerCase().startsWith('urn:')) {
      return null;
    }
    final segments = value.split(':');
    if (segments.length < 4) {
      return null;
    }
    final kind = segments[2].toLowerCase();
    if (kind != 'device' && kind != 'service') {
      return null;
    }
    final rawVersion = segments.length >= 5 ? int.tryParse(segments[4]) : null;
    return ServiceType(domain: segments[1], kind: kind, name: segments[3], version: rawVersion);
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceType &&
      other.domain == domain &&
      other.kind == kind &&
      other.name == name &&
      other.version == version;

  @override
  int get hashCode => Object.hash(domain, kind, name, version);

  @override
  String toString() => 'urn:$domain:$kind:$name${version == null ? '' : ':$version'}';
}
