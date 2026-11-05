import 'dart:io';
import 'dart:math';

import 'package:media_core_cast_dlna/src/utils/mime_type.dart';

/// A resource the media server exposes to renderers.
///
/// Access is by token: the path is `/{token}/{resourceId}` and only a
/// registration that answers for both is served. There is no directory
/// listing, no path parameter, and no way to ask for anything the host
/// did not explicitly register — the filesystem is never exposed.
final class MediaRegistration {
  MediaRegistration._({
    required this.id,
    required this.token,
    required this.file,
    required this.mimeType,
    required this.registeredAt,
    this.expiresAt,
  }) : lastAccessAt = registeredAt;

  /// The public resource id (path segment 2).
  final String id;

  /// The random access token (path segment 1). Unknown tokens are
  /// indistinguishable from unknown resources in the server's answers.
  final String token;

  /// The file being served.
  final File file;

  /// The MIME type served with the resource.
  final String mimeType;

  /// When this registration was created.
  final DateTime registeredAt;

  /// When access to this resource ends; null means until unregistered.
  final DateTime? expiresAt;

  /// When a renderer last touched this resource.
  DateTime lastAccessAt;

  /// The size read on first use. Every request and every range parse
  /// needs the size; a stat per request is pure overhead for a file
  /// that does not change while it is registered.
  int? _cachedSize;

  /// The registry key: token + id, the two path segments.
  String get key => '$token/$id';

  /// The byte size of the file.
  int get size => _cachedSize ??= file.lengthSync();

  /// Whether the registration is past its expiry.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Generates a URL-safe token: 16 random bytes, hex-encoded.
  static String generateToken([Random? random]) {
    final generator = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => generator.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// The resources a media server currently serves.
///
/// Lookups are exact key matches (`token/id`); an unknown key and a
/// wrong token produce the same empty answer, so the registry leaks
/// nothing about what it holds.
final class MediaResourceRegistry {
  final Map<String, MediaRegistration> _registrations = <String, MediaRegistration>{};

  /// How many resources are currently registered.
  int get length => _registrations.length;

  /// Whether nothing is registered.
  bool get isEmpty => _registrations.isEmpty;

  /// Registers [file], returning the registration.
  ///
  /// [mimeType] defaults to the path's extension; [ttl] sweeps the
  /// registration out after that lifetime, null keeps it until the
  /// unregister method is called.
  MediaRegistration register(File file, {String? mimeType, Duration? ttl}) {
    final now = DateTime.now();
    final registration = MediaRegistration._(
      id: MediaRegistration.generateToken().substring(0, 8),
      token: MediaRegistration.generateToken(),
      file: file,
      mimeType: mimeType ?? MimeType.forPath(file.path),
      registeredAt: now,
      expiresAt: ttl == null ? null : now.add(ttl),
    );
    _registrations[registration.key] = registration;
    return registration;
  }

  /// The registration answering this key, when present and unexpired.
  ///
  /// A hit refreshes the registration's last-access time; an expired
  /// registration is removed on sight.
  MediaRegistration? lookup(String key) {
    final registration = _registrations[key];
    if (registration == null) {
      return null;
    }
    registration.lastAccessAt = DateTime.now();
    if (registration.isExpired) {
      _registrations.remove(key);
      return null;
    }
    return registration;
  }

  /// Unregisters the resource answering [url]; unknown URLs are
  /// ignored, because a second cleanup must not fail a session.
  void unregisterUrl(Uri url) {
    _registrations.remove(_keyOf(url));
  }

  /// Drops every registration.
  void clear() => _registrations.clear();

  /// Removes expired registrations; returns how many were dropped.
  int sweepExpired() {
    var removed = 0;
    _registrations.removeWhere((_, registration) {
      final drop = registration.isExpired;
      if (drop) {
        removed++;
      }
      return drop;
    });
    return removed;
  }

  /// Whether any registration carries an expiry (and a sweep is worth
  /// scheduling).
  bool get anyExpiring => _registrations.values.any((registration) => registration.expiresAt != null);

  String _keyOf(Uri url) {
    final segments = url.pathSegments;
    if (segments.length < 2) {
      return '';
    }
    return '${segments[segments.length - 2]}/${segments.last}';
  }
}
