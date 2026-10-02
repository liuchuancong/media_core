import 'package:media_core/source/media_source.dart';

/// Folds a [CompositeMediaSource] into a form a single-input backend
/// can consume.
///
/// The contract the planner's [RemuxPlan] branch points at; the
/// production implementation is `FfmpegMediaRemuxer` in
/// `media_core_remux`, a stream copy (`-c copy`) through
/// `ffmpeg_kit_extended_flutter` on every platform that runs it.
///
/// Two things follow from the shape of the job and hold for any
/// implementation:
///
/// - **the output is a single progressive file, not DASH.** DASH is a
///   delivery model (manifest plus segments); once two essences are
///   folded into one stream there is nothing left to deliver as
///   fragments, and the point of the merge is that one URL with one
///   seekable sample table is what a single-input engine can open.
///     Codecs are copied, never re-encoded, so HEVC stays HEVC.
/// - **the source must be finite.** A copy runs to EOF and only then
///   finalizes the container, so a live composite never completes;
///   live belongs on a backend whose composite support is `native` or
///   `externalAudio`, and a planner facing a live composite should not
///   emit a [RemuxPlan] at all.
///
/// Responsibilities:
///
/// - accept a composite source
/// - return a [MediaSource] a `CompositeSupport.none` backend can play
///
/// It does not:
///
/// - decide whether remuxing is required (that is [MediaSourcePlanner])
/// - open a player
///
/// Those belong to:
///
/// - MediaSourcePlanner
/// - PlayerAdapter
abstract interface class MediaRemuxer {
  /// Remuxes [source] into a directly playable [MediaSource].
  Future<MediaSource> remux(CompositeMediaSource source);
}
