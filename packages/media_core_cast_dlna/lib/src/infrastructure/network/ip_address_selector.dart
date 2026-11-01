import 'dart:io';

/// Picks the LAN address a renderer should use to reach this device.
///
/// A cast URL must not say `localhost` or `127.0.0.1` — the TV fetches
/// it from its own stack — so the address comes from a real interface.
/// The heuristics follow TECHNICAL_DESIGN.md §16.2: prefer site-local
/// IPv4, skip loopback, and let the host override everything (VPN and
/// virtual adapters make the perfect pick impossible from the outside).
abstract final class IpAddressSelector {
  /// The best LAN address of this host, or null when none qualifies.
  ///
  /// [preferred] short-circuits the scan: hosts that know their
  /// network (a bound client socket, a setting) should pass it.
  static Future<InternetAddress?> bestLanAddress([InternetAddress? preferred]) async {
    if (preferred != null && !_isLoopback(preferred)) {
      return preferred;
    }
    final interfaces = await NetworkInterface.list();
    InternetAddress? fallback;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type != InternetAddressType.IPv4 || _isLoopback(address)) {
          continue;
        }
        if (address.isLinkLocal) {
          continue;
        }
        if (address.isLoopback) {
          continue;
        }
        // A site-local (private) range is what home LANs use; the first
        // non-private IPv4 is kept only as a last resort.
        if (_isSiteLocal(address)) {
          return address;
        }
        fallback ??= address;
      }
    }
    return fallback;
  }

  static bool _isLoopback(InternetAddress address) => address.isLoopback || address.address.startsWith('127.');

  static bool _isSiteLocal(InternetAddress address) {
    final parts = address.address.split('.');
    if (parts.length != 4) {
      return false;
    }
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == null || second == null) {
      return false;
    }
    return first == 10 || (first == 172 && second >= 16 && second <= 31) || (first == 192 && second == 168);
  }
}
