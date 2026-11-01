import 'dart:math';

import 'package:media_core_cast_dlna/src/utils/mime_type.dart';

/// One proxied remote resource: an upstream URL plus the headers needed
/// to fetch it, exposed to renderers behind a token route.
final class RemoteProxyRegistration {
  RemoteProxyRegistration._({
    required this.token,
    required this.upstream,
    required this.upstreamHeaders,
    required this.mimeType,
    required this.isPlaylist,
    required this.registeredAt,
    this.expiresAt,
  }) : lastAccessAt = registeredAt;

  /// The route token (path segment 1 under `/r/`).
  final String token;

  /// The upstream URL to fetch.
  final Uri upstream;

  /// Headers forwarded on every upstream fetch (Referer, Cookie, UA...).
  final Map<String, String> upstreamHeaders;

  /// The MIME type served for the root resource; children relay the
  /// upstream's answer.
  final String mimeType;

  /// Whether the root resource is an HLS playlist whose children are
  /// rewritten into proxy URLs.
  final bool isPlaylist;

  /// When this registration was created.
  final DateTime registeredAt;

  /// When access ends; null means until unregistered.
  final DateTime? expiresAt;

  /// When the route was last touched.
  DateTime lastAccessAt;

  /// Child resources discovered by playlist rewriting: childId (16-hex)
  /// → absolute upstream URI.
  final Map<String, Uri> children = <String, Uri>{};

  /// The registry key for the root resource.
  String get rootKey => token;

  /// Whether the registration is past its expiry.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Resolves [reference] (absolute or relative to the playlist URL) to
  /// an absolute upstream URI and allocates its stable child id.
  Uri childUri(String reference, Uri playlistUrl) {
    final absolute = playlistUrl.resolve(reference);
    final id = childIdFor(absolute);
    children[id] = absolute;
    return absolute;
  }

  /// The proxy path for a resolved child upstream URI (the `/r/` route
  /// prefix the server dispatches on).
  String pathForChild(Uri absolute) => '/r/$token/${childIdFor(absolute)}';

  /// Stable short id for an upstream URL: two 32-bit FNV-1a lanes, hex.
  /// Deterministic, so a live playlist refresh maps the same segment to
  /// the same child id without a dictionary lookup on the write path.
  static String childIdFor(Uri absolute) {
    var hi = 0xcbf29ce4;
    var lo = 0x84222325;
    for (final byte in absolute.toString().codeUnits) {
      lo = (lo ^ byte) & 0xFFFFFFFF;
      final carry = hi;
      hi = (hi ^ 0x93) & 0xFFFFFFFF;
      var product = lo * 0x1000001b3;
      lo = product & 0xFFFFFFFF;
      product = carry * 0x1000001b3 + (product >> 32);
      hi = (hi + (product & 0xFFFFFFFF)) & 0xFFFFFFFF;
    }
    return (hi.toRadixString(16).padLeft(8, '0') + lo.toRadixString(16).padLeft(8, '0')).substring(0, 16);
  }
}

/// Generates a URL-safe token: 16 random bytes, hex-encoded.
String _randomToken([Random? random]) {
  final generator = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => generator.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// The remote resources a media server currently proxies.
///
/// Lookups are exact token matches; an unknown token and an expired one
/// produce the same empty answer, so the registry leaks nothing about
/// what it holds.
final class RemoteProxyRegistry {
  final Map<String, RemoteProxyRegistration> _roots = <String, RemoteProxyRegistration>{};

  /// How many root resources are registered.
  int get length => _roots.length;

  /// Whether nothing is registered.
  bool get isEmpty => _roots.isEmpty;

  /// Registers [upstream]; [isPlaylist] marks an HLS manifest whose
  /// child references are rewritten into proxy URLs on fetch.
  RemoteProxyRegistration register(
    Uri upstream, {
    Map<String, String> upstreamHeaders = const <String, String>{},
    String? mimeType,
    Duration? ttl,
    bool isPlaylist = false,
  }) {
    final now = DateTime.now();
    final registration = RemoteProxyRegistration._(
      token: _randomToken(),
      upstream: upstream,
      upstreamHeaders: Map<String, String>.of(upstreamHeaders),
      mimeType: mimeType ?? MimeType.forPath(upstream.path),
      registeredAt: now,
      expiresAt: ttl == null ? null : now.add(ttl),
      isPlaylist: isPlaylist,
    );
    _roots[registration.rootKey] = registration;
    return registration;
  }

  /// The registration answering this token, when present and unexpired;
  /// a hit refreshes last-access, an expired one is removed on sight.
  RemoteProxyRegistration? lookup(String token) {
    final registration = _roots[token];
    if (registration == null) {
      return null;
    }
    registration.lastAccessAt = DateTime.now();
    if (registration.isExpired) {
      _roots.remove(token);
      return null;
    }
    return registration;
  }

  /// The child upstream URI for a rewritten child id, when registered.
  Uri? childOf(RemoteProxyRegistration registration, String childId) => registration.children[childId];

  /// Unregisters the resource behind a proxy [url]; unknown URLs are
  /// ignored.
  void unregisterUrl(Uri url) {
    _roots.remove(_tokenOf(url));
  }

  /// Drops every registration.
  void clear() => _roots.clear();

  /// Removes expired registrations; returns how many were dropped.
  int sweepExpired() {
    var removed = 0;
    _roots.removeWhere((_, registration) {
      final drop = registration.isExpired;
      if (drop) {
        removed++;
      }
      return drop;
    });
    return removed;
  }

  /// Whether any registration carries an expiry.
  bool get anyExpiring => _roots.values.any((registration) => registration.expiresAt != null);

  String _tokenOf(Uri url) {
    final segments = url.pathSegments;
    if (segments.length < 2 || segments.first != 'r') {
      return '';
    }
    return segments[1];
  }
}
