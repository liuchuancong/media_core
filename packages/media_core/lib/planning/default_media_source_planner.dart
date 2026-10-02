import 'package:media_core/adapter/composite_support.dart';
import 'package:media_core/adapter/player_adapter_capabilities.dart';
import 'package:media_core/remux/media_remuxer.dart';
import 'package:media_core/source/media_source.dart';
import 'package:media_core/planning/media_source_plan.dart';
import 'package:media_core/planning/media_source_planner.dart';
import 'package:media_core_logging/media_core_logging.dart';

/// The default [MediaSourcePlanner].
///
/// Encodes the three rules media_core needs today and leaves room
/// for the remux branch the future [MediaRemuxer] hook will fill:
///
/// 1. A progressive source is always directly playable — no backend
///    capability can turn a single stream into something it can't
///    consume.
/// 2. A composite source with a composite-capable backend is planned
///    as [CompositePlan]; the backend's own
///    [CompositeSupport.native] vs [CompositeSupport.externalAudio]
///    distinction is expressed by the same variant because the
///    planner is only deciding "does the adapter accept this
///    composite" — the how is the adapter's business.
/// 3. A composite source on a `CompositeSupport.none` backend needs
///    extra work. When [remuxer] is wired we emit [RemuxPlan]; when
///    it is not we emit [UnsupportedPlan] rather than silently
///    dropping to the primary track. Falling back without a plan is
///    what lets a provider "accidentally" ship Bilibili DASH audio
///    to a Fijk build with no sound — an explicit unsupported signal
///    keeps that failure at the layer that can react to it.
///    A **live** composite never gets a [RemuxPlan] even with a
///    remuxer wired: a stream copy runs to end-of-file, and a live
///    period does not have one.
///
/// Responsibilities:
///
/// - map source + capabilities to a plan
///
/// It does not:
///
/// - perform remuxing
/// - open backends
/// - cache decisions across calls
///
/// Those belong to:
///
/// - MediaRemuxer
/// - PlayerAdapter
/// - PlayerKernel
///
/// Example:
///
/// ```dart
/// final planner = const DefaultMediaSourcePlanner();
/// final plan = planner.plan(compositeSource, mpvAdapter.capabilities);
/// if (plan case CompositePlan(:final source)) {
///   await adapter.openComposite(source);
/// }
/// ```
final class DefaultMediaSourcePlanner implements MediaSourcePlanner {
  /// Creates the default planner.
  ///
  /// [remuxer] is optional and reserved: passing one changes the
  /// `CompositeSupport.none` outcome from [UnsupportedPlan] to
  /// [RemuxPlan], letting a caller that has wired a muxer decide how
  /// to invoke it.
  const DefaultMediaSourcePlanner({this.remuxer});

  /// Optional remuxer consulted for composite-on-incompatible-backend.
  final MediaRemuxer? remuxer;

  @override
  MediaSourcePlan plan(
    MediaSource source,
    PlayerAdapterCapabilities capabilities,
  ) {
    final plan = _decide(source, capabilities);
    MediaCoreLog.debug(
      LogCategory.fallback,
      'media source plan: ${_planLabel(plan)} for ${source.type.name} source',
      fields: <String, Object?>{
        'sourceType': source.type.name,
        'plan': _planLabel(plan),
        'compositeSupport': capabilities.compositeSupport.name,
        if (source is CompositeMediaSource) 'video': source.videoTracks.length,
        if (source is CompositeMediaSource) 'audio': source.audioTracks.length,
        if (source is CompositeMediaSource)
          'subtitle': source.subtitleTracks.length,
        if (plan is UnsupportedPlan) 'reason': plan.reason,
      },
    );
    return plan;
  }

  static String _planLabel(MediaSourcePlan plan) {
    return switch (plan) {
      DirectPlan() => 'direct',
      CompositePlan(:final mode) => 'composite/${mode.name}',
      RemuxPlan() => 'remux',
      UnsupportedPlan() => 'unsupported',
    };
  }

  MediaSourcePlan _decide(
    MediaSource source,
    PlayerAdapterCapabilities capabilities,
  ) {
    if (source is! CompositeMediaSource) {
      return DirectPlan(source);
    }

    if (capabilities.supportsComposite) {
      return CompositePlan(source, mode: capabilities.compositeSupport);
    }

    // A remux reads every essence to EOF and only then writes the
    // index that makes the file seekable, so a live stream never
    // finishes merging — the call would hang until someone cancelled
    // it. A live composite on a backend that cannot take two inputs
    // has no honest answer here, and pretending to have one (emit a
    // plan nobody can execute) is worse than refusing.
    if (source.live) {
      return UnsupportedPlan(
        'Live composite sources cannot be remuxed (a stream copy runs '
        'to end-of-file); select a backend with native or external-audio '
        'composite support instead.',
        source: source,
      );
    }

    final muxer = remuxer;
    if (muxer != null) {
      return RemuxPlan(source);
    }

    return UnsupportedPlan(
      'Selected backend does not support composite media sources and no '
      'remuxer is wired. Register a composite-capable backend or supply a '
      'MediaRemuxer to DefaultMediaSourcePlanner.',
      source: source,
    );
  }
}
