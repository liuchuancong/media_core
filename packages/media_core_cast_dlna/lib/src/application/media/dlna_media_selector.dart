import 'package:media_core_cast_dlna/src/domain/entities/dlna_media.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_capability.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_resource.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_selection.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/domain/value_objects/media_protocol_info.dart';

/// Picks the resource of a media item that best fits a device.
///
/// The scoring follows TECHNICAL_DESIGN.md §15.5, restricted to what a
/// ProtocolInfo can actually tell this package: format support, DLNA
/// profile agreement, byte-range support and whether a resource is
/// already a transcoded rendition. Codec-level details (H.264 level,
/// resolution ceilings) are not carried by `GetProtocolInfo`, and a
/// scorer that pretended to read them would be guessing with extra
/// steps.
///
/// With an unknown capability set (the device said nothing), every
/// resource is playable by definition and the best-stated one wins —
/// permissive, because "unknown" is not "impossible". With a known
/// capability set and no fitting resource, the failure is explicit:
/// [DlnaUnsupportedMediaException] with the per-resource rejection
/// trace, never a silent fallback to an unsupported resource.
final class DlnaMediaSelector {
  /// Creates a selector.
  const DlnaMediaSelector();

  /// Selects the resource of [media] for a device with [capability].
  ///
  /// Throws [ArgumentError] when the item carries no resources at all,
  /// and [DlnaUnsupportedMediaException] when the device is known to
  /// reject every candidate.
  DlnaMediaSelection select({required DlnaMedia media, required DlnaMediaCapability capability}) {
    if (media.resources.isEmpty) {
      throw ArgumentError('media item "${media.id}" carries no resources');
    }

    final scored = <_Scored>[];
    for (final resource in media.resources) {
      scored.add(_Scored(resource, _evaluate(resource, capability)));
    }

    final playable = scored.where((entry) => entry.verdict.playable).toList()..sort(_betterFirst);
    if (playable.isEmpty) {
      throw DlnaUnsupportedMediaException(
        'device cannot play any resource of "${media.title}"',
        reasons: <String>[for (final entry in scored) entry.verdict.reason],
      );
    }

    final best = playable.first;
    return DlnaMediaSelection(
      resource: best.resource,
      requiresTranscoding: best.verdict.transcodingHint,
      reasons: <String>[for (final entry in scored) entry.verdict.reason],
    );
  }

  _Verdict _evaluate(DlnaMediaResource resource, DlnaMediaCapability capability) {
    final info = resource.protocolInfo == null ? null : MediaProtocolInfo.tryParse(resource.protocolInfo!);
    final mimeType = info?.contentFormat ?? resource.mimeType;
    final profile = info?.dlnaProfile;

    if (!capability.supportsFormat(mimeType)) {
      return _Verdict(playable: false, reason: '${resource.uri}: device does not declare $mimeType');
    }

    if (!capability.supportsProfile(profile)) {
      return _Verdict(playable: false, reason: '${resource.uri}: device does not declare DLNA profile $profile');
    }

    var score = 0;
    final notes = <String>[];
    if (capability.known) {
      score += 40;
      notes.add('format declared by device');
    } else {
      notes.add('device capabilities unknown; assuming playable');
    }

    if (profile != null && capability.supportsProfile(profile) && capability.declaresProfiles) {
      score += 20;
      notes.add('DLNA profile $profile declared');
    }

    if (resource.supportsByteRange && (info?.supportsByteRange ?? true)) {
      score += 15;
    } else {
      score -= 10;
      notes.add('no byte-range support; seeking may fail');
    }

    final transcoded = info?.requiresConversion ?? false;
    if (transcoded) {
      score -= 5;
      notes.add('resource is already a converted rendition');
    }

    if (resource.size != null) {
      score += 1;
    }

    return _Verdict(
      playable: true,
      reason: '${resource.uri}: ${notes.join('; ')}',
      score: score,
      transcodingHint: transcoded,
    );
  }

  static int _betterFirst(_Scored a, _Scored b) => b.verdict.score.compareTo(a.verdict.score);
}

final class _Scored {
  const _Scored(this.resource, this.verdict);

  final DlnaMediaResource resource;
  final _Verdict verdict;
}

final class _Verdict {
  const _Verdict({required this.playable, required this.reason, this.score = -1 << 30, this.transcodingHint = false});

  final bool playable;
  final int score;
  final String reason;
  final bool transcodingHint;
}
