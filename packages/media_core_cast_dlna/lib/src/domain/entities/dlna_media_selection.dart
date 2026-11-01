import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_resource.dart';

/// The outcome of a capability-based media selection.
///
/// [resource] is the form the device should be given;
/// [requiresTranscoding] marks that no available resource fits the
/// device as-is (a transcode resolver, when one exists upstream, picks
/// it up from here); [reasons] records why this choice was made or why
/// the others were rejected, so a host can show or log something
/// better than "cast failed".
final class DlnaMediaSelection {
  /// Creates a selection.
  const DlnaMediaSelection({required this.resource, this.requiresTranscoding = false, this.reasons = const <String>[]});

  /// The chosen resource.
  final DlnaMediaResource resource;

  /// Whether the device needs a converted stream to play this item.
  final bool requiresTranscoding;

  /// Human-readable decision trace.
  final List<String> reasons;
}
