import 'package:media_core_cast_dlna/src/domain/value_objects/media_protocol_info.dart';

/// What a renderer told this package it can play.
///
/// Built from `ConnectionManager.GetProtocolInfo`'s Sink value — the
/// device's own declaration, never a hard-coded brand table. A device
/// that exposes no ConnectionManager or answers with an empty sink
/// yields the unknown capability: capabilities then cannot rule anything out, and
/// selection proceeds permissively instead of pretending to know.
final class DlnaMediaCapability {
  /// Creates a capability set.
  const DlnaMediaCapability({required Set<String> contentFormats, required Set<String> profiles, required this.known})
    : _contentFormats = contentFormats,
      _profiles = profiles;

  /// The capability of a device that said nothing usable.
  const DlnaMediaCapability.unknown() : _contentFormats = const <String>{}, _profiles = const <String>{}, known = false;

  /// Builds a capability set from a parsed Sink list.
  ///
  /// Only `http-get` entries are considered: that is the only transport
  /// this package pushes media over.
  factory DlnaMediaCapability.fromSink(Iterable<MediaProtocolInfo> entries) {
    final formats = <String>{};
    final profiles = <String>{};
    for (final entry in entries) {
      if (entry.protocol != 'http-get') {
        continue;
      }
      if (entry.contentFormat.isNotEmpty) {
        formats.add(entry.contentFormat.toLowerCase());
      }
      final profile = entry.dlnaProfile;
      if (profile != null) {
        profiles.add(profile.toUpperCase());
      }
    }
    if (formats.isEmpty) {
      return const DlnaMediaCapability.unknown();
    }
    return DlnaMediaCapability(contentFormats: formats, profiles: profiles, known: true);
  }

  /// The sink content formats (lower-cased MIME types), `*` included
  /// when the device declares it.
  final Set<String> _contentFormats;

  /// The declared DLNA profile names (`DLNA.ORG_PN` values).
  final Set<String> _profiles;

  /// Whether this set comes from an actual device answer.
  final bool known;

  /// Whether the device listed any DLNA profiles at all.
  bool get declaresProfiles => _profiles.isNotEmpty;

  /// Whether the device declared support for [mimeType].
  ///
  /// On an unknown capability set everything is supported, because
  /// nothing is known; a `*` content format (some devices send it)
  /// counts as supporting everything too.
  bool supportsFormat(String mimeType) {
    if (!known) {
      return true;
    }
    if (_contentFormats.contains('*')) {
      return true;
    }
    return _contentFormats.contains(mimeType.toLowerCase());
  }

  /// Whether the device declared the DLNA profile [profile].
  ///
  /// Same unknown-capability permissiveness applies; a device that
  /// lists formats but no profiles simply says nothing about profiles,
  /// which also reads as "no objection".
  bool supportsProfile(String? profile) {
    if (!known || profile == null || _profiles.isEmpty) {
      return true;
    }
    return _profiles.contains(profile.toUpperCase());
  }
}
