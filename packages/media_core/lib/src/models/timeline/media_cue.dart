import 'package:built_value/built_value.dart';

part 'media_cue.g.dart';

/// A timed caption on a presentation timeline.
///
/// [MediaCue] is presentation-time: after a composite source's
/// subtitle track has been aligned to the shared timeline, the cue's
/// [start] and [end] sit on the same clock the player reports, so an
/// overlay can look cues up with the playback position directly and
/// never needs the track's offset again.
///
/// Responsibilities:
///
/// - carry one cue's time range and text
/// - answer [covers] against a presentation position
///
/// It does not:
///
/// - parse subtitle formats (SRT/VTT/ASS)
/// - own styling beyond [attributes]
///
/// Those belong to:
///
/// - a provider or inspector that produces cues
/// - presentation widgets
abstract class MediaCue implements Built<MediaCue, MediaCueBuilder> {
  /// Builds a cue from a [updates] callback — the codegen entry.
  factory MediaCue([void Function(MediaCueBuilder)? updates]) = _$MediaCue;

  /// Creates a cue covering [start] (inclusive) to [end] (exclusive).
  factory MediaCue.of({
    required Duration start,
    required Duration end,
    required String text,
    String? id,
    String? language,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return MediaCue(
      (builder) => builder
        ..start = start
        ..end = end
        ..text = text
        ..id = id
        ..language = language
        ..attributes = attributes,
    );
  }

  MediaCue._();

  /// An unset attribute bag stays empty rather than null; id and
  /// language are genuinely absent until the producing layer states them.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(MediaCueBuilder builder) => builder..attributes = const <String, Object?>{};

  /// A cue that ends before it starts is a producer bug, not a cue an
  /// overlay could ever show, so every construction path is checked.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(MediaCueBuilder builder) {
    final end = builder.end;
    assert(end == null || !end.isNegative, 'Cue end must not be negative.');
  }

  /// Presentation time at which the cue appears.
  Duration get start;

  /// Presentation time at which the cue disappears.
  Duration get end;

  /// The caption text.
  String get text;

  /// Optional stable cue id (a VTT cue identifier, for example).
  String? get id;

  /// Optional BCP-47 language tag this cue belongs to.
  String? get language;

  /// Producer-specific attributes (positioning, styling hints).
  Map<String, Object?> get attributes;

  /// Whether [time] falls inside this cue, end-exclusive.
  bool covers(Duration time) => time >= start && time < end;

  /// The cue's length on the presentation timeline.
  Duration get duration => end - start;
}
