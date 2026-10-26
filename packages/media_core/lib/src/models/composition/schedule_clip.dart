import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/composition/clip_kind.dart';
import 'package:media_core/src/source/model/media_source.dart';

part 'schedule_clip.g.dart';

/// One media item placed on a schedule.
///
/// A [ScheduleClip] is a duration-typed [MediaSource] with a role: the
/// schedule cannot plan against a source whose length it does not
/// know, so [duration] is required and is the host's answer to
/// "exactly how long does this occupy the timeline" (an ad's VAST
/// duration, a program's manifest duration, a bumper's fixed length).
///
/// Responsibilities:
///
/// - bind a media source to a role and a duration
///
/// It does not:
///
/// - carry placement rules (that is MediaBreak)
/// - track its own playback state
///
/// Those belong to:
///
/// - MediaBreak
/// - ScheduleNavigator
abstract class ScheduleClip implements Built<ScheduleClip, ScheduleClipBuilder> {
  /// Builds ScheduleClip from a [updates] callback — the codegen entry.
  factory ScheduleClip([void Function(ScheduleClipBuilder)? updates]) = _$ScheduleClip;

  /// Creates one scheduled clip.
  factory ScheduleClip.of({
    required MediaSource source,
    required Duration duration,
    ClipKind kind = ClipKind.content,
    String? id,
    Duration? skipAfter,
    Uri? clickThroughUrl,
    List<Uri> trackingUris = const <Uri>[],
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return ScheduleClip(
      (builder) => builder
        ..source = source
        ..duration = duration
        ..kind = kind
        ..id = id
        ..skipAfter = skipAfter
        ..clickThroughUrl = clickThroughUrl
        ..trackingUris = trackingUris
        ..attributes = attributes,
    );
  }

  ScheduleClip._();

  /// A clip is the program itself, tracks nothing and carries nothing until
  /// the feed says otherwise.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ScheduleClipBuilder builder) => builder
    ..kind = ClipKind.content
    ..trackingUris = const <Uri>[]
    ..attributes = const <String, Object?>{};

  /// A clip that occupies negative time, or offers a skip point before it
  /// starts, describes a timeline the composer cannot walk.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(ScheduleClipBuilder builder) {
    final duration = builder.duration;
    final skipAfter = builder.skipAfter;
    assert(
      duration == null || !duration.isNegative,
      'A scheduled clip must occupy a non-negative span.',
    );
    assert(
      skipAfter == null || !skipAfter.isNegative,
      'A skip point cannot precede the start of its clip.',
    );
  }

  /// The media to present for this clip.
  MediaSource get source;

  /// How long the clip occupies the combined timeline.
  ///
  /// Required, not inferred: an ad server that reports a 15-second
  /// creative and a manifest that disagrees about the program's
  /// length are different failure modes, and the schedule wants to be
  /// able to name which one it hit.
  Duration get duration;

  /// The role this clip plays. See [ClipKind].
  ClipKind get kind;

  /// Optional stable id (an ad slot id, a VAST AdId, an episode id).
  String? get id;

  /// When inside an advertisement the viewer may dismiss it.
  ///
  /// Null means "no skip is offered". Meaningful only for
  /// [ClipKind.advertisement]; the navigator reports a non-null value
  /// on any other kind as an unskippable pass-through, because the
  /// decision rule lives in one place, not in kind-shaped branches.
  Duration? get skipAfter;

  /// Optional click-through destination for a tappable advertisement.
  Uri? get clickThroughUrl;

  /// Tracking beacons to ping at creative lifecycle points.
  ///
  /// URIs only; firing them (and when) is host behavior — a schedule
  /// machine with network side effects could not be a pure function.
  List<Uri> get trackingUris;

  /// Producer-specific attributes; opaque to media_core.
  Map<String, Object?> get attributes;

  /// The end of the clip relative to whatever it is placed after.
  Duration get relativeEnd => duration;
}
