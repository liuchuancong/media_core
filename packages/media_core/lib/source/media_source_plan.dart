import 'package:media_core/adapter/composite_support.dart';
import 'package:media_core/source/media_source.dart';

/// A decision about how to play a [MediaSource] on a given backend.
///
/// The planner produces a plan; it never touches the adapter itself.
/// Splitting the two is what lets a provider hand a Bilibili DASH
/// pair to `PlayerKernel` without knowing whether the eventual
/// backend is Media3, MPV, or a single-URL engine that will need a
/// remux step first.
///
/// Every variant is a leaf — consumers switch on the shape and are
/// forced by the compiler to handle each one, which is what makes
/// adding a `RemuxPlan` here later a compile-time migration instead
/// of a silent runtime fall-through.
///
/// Responsibilities:
///
/// - express one of the outcomes a planner can produce
///
/// It does not:
///
/// - carry playback state
/// - schedule any work
///
/// Those belong to:
///
/// - PlayerKernel
/// - MediaSourcePlanner
sealed class MediaSourcePlan {
  /// Creates a plan.
  const MediaSourcePlan();

  /// Whether this plan is directly playable by the target backend.
  ///
  /// True for [DirectPlan] and [CompositePlan]; false for [RemuxPlan]
  /// and [UnsupportedPlan], which need either extra work or a
  /// different backend before anything plays.
  bool get isPlayable;
}

/// Feed the underlying [MediaSource] to the adapter unchanged.
///
/// Used for progressive sources and for composite sources that the
/// backend can already consume through its native merging API —
/// from the planner's point of view both cases end in "hand it
/// over, no work here".
final class DirectPlan extends MediaSourcePlan {
  /// Creates a direct plan.
  const DirectPlan(this.source);

  /// The source to hand over.
  final MediaSource source;

  @override
  bool get isPlayable => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DirectPlan && other.source == source;

  @override
  int get hashCode => Object.hash(DirectPlan, source);

  @override
  String toString() => 'DirectPlan($source)';
}

/// Hand a [CompositeMediaSource] to a backend whose composite
/// support is [CompositeSupport.native] or
/// [CompositeSupport.externalAudio].
///
/// Distinct from [DirectPlan] so a consumer can log or instrument
/// the composite path specifically — for example an adapter that
/// routes external audio through a side channel needs to know it
/// is expected to do that.
///
/// [mode] mirrors the backend's declared [CompositeSupport] so a
/// caller that has the plan but not the registration (for example a
/// debug screen or a replayed plan in a test) can still see which
/// consumption strategy the plan chose.
final class CompositePlan extends MediaSourcePlan {
  /// Creates a composite plan.
  ///
  /// [mode] defaults to [CompositeSupport.native] because a caller
  /// building a plan by hand is almost always exercising the plain
  /// "merge the tracks" case; planners must pass the actual backend
  /// value explicitly.
  const CompositePlan(this.source, {this.mode = CompositeSupport.native});

  /// The composite source to hand over.
  final CompositeMediaSource source;

  /// How the selected backend will consume the composite.
  ///
  /// Never [CompositeSupport.none] — the planner would have produced
  /// a [RemuxPlan] or [UnsupportedPlan] in that case.
  final CompositeSupport mode;

  @override
  bool get isPlayable => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositePlan &&
          other.source == source &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(CompositePlan, source, mode);

  @override
  String toString() => 'CompositePlan($source, $mode)';
}

/// The source is composite but the backend cannot consume composites.
///
/// A [MediaRemuxer] is available and should be invoked to fold the
/// essence tracks into a single stream before playback. The planner
/// declares the intent; running the remux belongs to the caller
/// (typically `PlayerKernel`) so the planner stays synchronous and
/// side-effect free.
final class RemuxPlan extends MediaSourcePlan {
  /// Creates a remux plan.
  const RemuxPlan(this.source);

  /// The composite source that needs remuxing.
  final CompositeMediaSource source;

  @override
  bool get isPlayable => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RemuxPlan && other.source == source;

  @override
  int get hashCode => Object.hash(RemuxPlan, source);

  @override
  String toString() => 'RemuxPlan($source)';
}

/// No backend can play this source as-is.
///
/// The message carried here is user-facing-safe by convention: it
/// explains what was rejected and why, without leaking internals a
/// UI layer would have to redact anyway.
final class UnsupportedPlan extends MediaSourcePlan {
  /// Creates an unsupported plan.
  const UnsupportedPlan(this.reason, {this.source});

  /// Human-readable explanation of why the source cannot be played.
  final String reason;

  /// The source that could not be planned, when available.
  ///
  /// Nullable because a planner can decide a source is unsupported
  /// before it even reads it — for example, an argument-validation
  /// rejection has nothing to carry.
  final MediaSource? source;

  @override
  bool get isPlayable => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnsupportedPlan &&
          other.reason == reason &&
          other.source == source;

  @override
  int get hashCode => Object.hash(UnsupportedPlan, reason, source);

  @override
  String toString() => 'UnsupportedPlan($reason)';
}
