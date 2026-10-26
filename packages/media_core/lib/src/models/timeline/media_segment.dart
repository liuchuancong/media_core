import 'package:built_value/built_value.dart';

part 'media_segment.g.dart';

/// A named range on a presentation timeline.
///
/// The composition layer's generic unit of "a piece of the timeline":
/// an HLS/DASH segment boundary, a chapter marker, an ad break, or a
/// gap left by a removed section all share this shape — a position, a
/// length, and opaque attributes the producing layer interprets.
///
/// Responsibilities:
///
/// - express a presentation-time range with a label and attributes
/// - answer containment questions ([covers], [intersects])
///
/// It does not:
///
/// - reference the bytes or URL of an actual media segment
/// - schedule anything
///
/// Those belong to:
///
/// - the producing manifest layer
/// - PlayerAdapter
abstract class MediaSegment implements Built<MediaSegment, MediaSegmentBuilder> {
  /// Builds a segment from a [updates] callback — the codegen entry.
  factory MediaSegment([void Function(MediaSegmentBuilder)? updates]) = _$MediaSegment;

  /// Creates a segment starting at [start] on the presentation
  /// timeline.
  factory MediaSegment.of({
    required Duration start,
    required Duration duration,
    String? label,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return MediaSegment(
      (builder) => builder
        ..start = start
        ..duration = duration
        ..label = label
        ..attributes = attributes,
    );
  }

  MediaSegment._();

  /// An unset attribute bag stays empty rather than null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(MediaSegmentBuilder builder) => builder..attributes = const <String, Object?>{};

  /// A segment with negative length describes no time at all, so every
  /// construction path is checked.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(MediaSegmentBuilder builder) {
    final duration = builder.duration;
    assert(duration == null || !duration.isNegative, 'Segment duration must not be negative.');
  }

  /// Where the segment begins on the presentation timeline.
  Duration get start;

  /// How long the segment lasts.
  Duration get duration;

  /// Optional human-readable name (chapter title, ad slot id, ...).
  String? get label;

  /// Producer-specific attributes; opaque to media_core.
  Map<String, Object?> get attributes;

  /// Where the segment ends on the presentation timeline.
  Duration get end => start + duration;

  /// Whether [time] falls inside this segment, end-exclusive.
  bool covers(Duration time) => time >= start && time < end;

  /// Whether this segment overlaps [other].
  bool intersects(MediaSegment other) => start < other.end && other.start < end;

  /// The segment shifted by [delta] on the timeline.
  MediaSegment shiftedBy(Duration delta) =>
      MediaSegment.of(start: start + delta, duration: duration, label: label, attributes: attributes);
}
