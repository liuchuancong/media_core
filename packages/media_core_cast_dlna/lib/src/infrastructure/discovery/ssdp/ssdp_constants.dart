/// Wire constants of the SSDP transport.
abstract final class SsdpConstants {
  /// The SSDP multicast group address.
  static const String multicastAddress = '239.255.255.250';

  /// The SSDP UDP port.
  static const int port = 1900;

  /// The required MAN value of an M-SEARCH.
  static const String discoverMan = '"ssdp:discover"';

  /// How long responders may stagger their replies, in seconds.
  static const int defaultMx = 3;

  /// Search targets a discovery run issues by default.
  ///
  /// Different renderers answer different STs — some only respond to
  /// their exact device version, others to nothing but `upnp:rootdevice`
  /// — so the default covers both renderer generations, and the response
  /// (or the description that follows) is what actually decides whether
  /// a device is castable. `ssdp:all` would reach more devices but
  /// floods the LAN with answers from every printer on the floor.
  static const List<String> defaultSearchTargets = <String>[
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:schemas-upnp-org:device:MediaRenderer:2',
  ];

  /// The announcement lifetime applied when `CACHE-CONTROL` carries no
  /// usable `max-age`.
  ///
  /// Erring short: a stale-but-listed device the user can select and
  /// then fail to cast to is worse than one that briefly disappears.
  static const Duration defaultCacheLifetime = Duration(seconds: 30);
}
