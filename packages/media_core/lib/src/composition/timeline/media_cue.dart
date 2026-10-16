import 'package:equatable/equatable.dart';

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
final class MediaCue extends Equatable {
  /// Creates a cue covering [start] (inclusive) to [end] (exclusive).
  MediaCue({
    required this.start,
    required this.end,
    required this.text,
    this.id,
    this.language,
    this.attributes = const <String, Object?>{},
  }) : assert(!end.isNegative, 'Cue end must not be negative.');

  /// Presentation time at which the cue appears.
  final Duration start;

  /// Presentation time at which the cue disappears.
  final Duration end;

  /// The caption text.
  final String text;

  /// Optional stable cue id (a VTT cue identifier, for example).
  final String? id;

  /// Optional BCP-47 language tag this cue belongs to.
  final String? language;

  /// Producer-specific attributes (positioning, styling hints).
  final Map<String, Object?> attributes;

  /// Whether [time] falls inside this cue, end-exclusive.
  bool covers(Duration time) => time >= start && time < end;

  /// The cue's length on the presentation timeline.
  Duration get duration => end - start;

  @override
  List<Object?> get props => <Object?>[start, end, text, id, language, attributes];
}
