import 'package:media_core/source/media_source.dart';

/// Folds a [CompositeMediaSource] into a form a single-input backend
/// can consume.
///
/// Declared now so the planner's [RemuxPlan] branch has a type to
/// point at. Implementations — a lightweight MP4 muxer, a platform
/// native muxer, FFmpeg, or a Media3 side-channel wrapper — arrive
/// later without disturbing the plan / capabilities model.
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
