import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/thumbnail/thumbnail.dart';
import 'package:media_core/src/models/thumbnail/thumbnail_slice.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart' show SourceHeaders;

part 'thumbnail_track.g.dart';

/// A parsed WebVTT thumbnail track.
///
/// The data behind a scrubber preview: one frame per cue, addressed by
/// `#xywh` fragment when the server ships sprites. This type only
/// parses and looks up — decoding, cropping and painting are a
/// renderer's job, which is why the slice stays a rectangle and never
/// tries to be a shader.
///
/// Responsibilities:
///
/// - parse the WebVTT cue subset thumbnail tracks use
/// - answer [at] for a hovered media time
///
/// It does not:
///
/// - fetch the WebVTT text
/// - load or crop images
///
/// Those belong to:
///
/// - the host (HTTP with the same [SourceHeaders] as the media)
/// - the widget layer
abstract class ThumbnailTrack implements Built<ThumbnailTrack, ThumbnailTrackBuilder> {
  /// Builds a track from a [updates] callback — the codegen entry.
  factory ThumbnailTrack([void Function(ThumbnailTrackBuilder)? updates]) = _$ThumbnailTrack;

  /// Creates a track from parsed [thumbnails].
  factory ThumbnailTrack.of({required List<Thumbnail> thumbnails}) {
    return ThumbnailTrack(
      (builder) => builder..thumbnails = thumbnails,
    );
  }

  ThumbnailTrack._();

  /// Parses WebVTT text containing cue blocks whose cue text is an
  /// image URL, optionally with an `#xywh=x,y,w,h` fragment.
  ///
  /// Header blocks (`WEBVTT`), `STYLE`, `REGION` and `NOTE` blocks and
  /// timing-only settings lines are skipped; cue blocks that do not
  /// resolve to an image URL are skipped too, which is what makes a
  /// caption VTT parse to an empty track rather than throwing — the
  /// caller asked for thumbnails and this file has none, a fact the
  /// empty track states precisely.
  ///
  /// A malformed timestamp pair fails that cue only and never aborts
  /// the track: one broken line in a generated sprite file must not
  /// erase every preview frame a scrubber can show.
  factory ThumbnailTrack.parseWebVtt(String text) {
    final thumbnails = <Thumbnail>[];

    // A cue is "timestamp line, then cue text, then a blank line". The
    // scanner keeps the most recent timestamp pair until it sees the
    // next non-empty line, which is the cue text.
    Duration? pendingStart;
    Duration? pendingEnd;

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        pendingStart = null;
        pendingEnd = null;
        continue;
      }

      final timing = _parseTiming(line);
      if (timing != null) {
        pendingStart = timing.start;
        pendingEnd = timing.end;
        continue;
      }

      // Anything before the first timing line is header or metadata;
      // without a pending pair a cue text line has no window and is
      // noise (a caption line under a cue we could not parse, for
      // instance) and skipping it is the only safe reading.
      if (pendingStart == null || pendingEnd == null) {
        continue;
      }

      if (!_looksLikeImageReference(line)) {
        // Not a URL-looking cue text (a caption's words, a NOTE body):
        // consume the pending pair so it does not bleed onto the next
        // text line.
        pendingStart = null;
        pendingEnd = null;
        continue;
      }

      final url = Uri.parse(line);
      ThumbnailSlice? slice;
      var image = url;
      final fragment = url.fragment;
      if (fragment.startsWith('xywh=')) {
        slice = ThumbnailSlice.tryParse(fragment.substring('xywh='.length));
        // `replace(fragment: '')` would leave a dangling `#` behind on
        // Dart's Uri, so the reference is rebuilt from the text before
        // the fragment separator.
        final text = url.toString();
        final hash = text.indexOf('#');
        image = Uri.parse(hash < 0 ? text : text.substring(0, hash));
      }

      thumbnails.add(Thumbnail.of(start: pendingStart, end: pendingEnd, imageUrl: image, slice: slice));
      pendingStart = null;
      pendingEnd = null;
    }

    return ThumbnailTrack.of(thumbnails: List<Thumbnail>.unmodifiable(thumbnails));
  }

  /// An empty track is what a caption file parses to, so it must be
  /// constructible without the caller naming a list.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ThumbnailTrackBuilder builder) => builder..thumbnails = const <Thumbnail>[];

  /// Parsed cues, in document order.
  List<Thumbnail> get thumbnails;

  /// The frame representing [time], or null when the track has none.
  ///
  /// Null is the correct answer at the end of a timeline (cues are
  /// end-exclusive) and for a caption file parsed as a thumbnail
  /// track; a scrubber that gets null simply shows no preview rather
  /// than inventing a frame from a neighbouring cue.
  Thumbnail? at(Duration time) {
    for (final thumbnail in thumbnails) {
      if (thumbnail.covers(time)) {
        return thumbnail;
      }
    }
    return null;
  }

  /// Whether this track can drive a preview at all.
  bool get isEmpty => thumbnails.isEmpty;

  /// The interval each cue covers, when the file is regular.
  ///
  /// Sprite VTTs step uniformly; the first cue's span is the honest
  /// answer for "how far apart are these frames", which a renderer
  /// uses to decide preview density.
  Duration? get cueInterval => thumbnails.isEmpty ? null : thumbnails.first.end - thumbnails.first.start;

  static bool _looksLikeImageReference(String cueText) {
    // A thumbnail cue's text is one image reference; a caption cue's
    // text is a sentence. The difference is decided here and nowhere
    // else: scheme-ful URLs count, and a relative path only counts
    // when it ends in an extension-shaped tail (optionally followed
    // by a fragment or query). A sentence that merely ends with a
    // period — "I am fine, thanks." — matches neither, which is what
    // keeps a caption track parsing empty instead of inventing cues.
    if (cueText.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(cueText);
    if (uri == null) {
      return false;
    }
    if (uri.hasScheme && uri.scheme.isNotEmpty) {
      return true;
    }
    final path = cueText.split('#').first.split('?').first;
    return RegExp(r'\.[A-Za-z0-9]{2,5}$').hasMatch(path);
  }

  static _Timing? _parseTiming(String line) {
    final arrow = line.indexOf('-->');
    if (arrow < 0) {
      return null;
    }
    final start = _parseTimestamp(line.substring(0, arrow).trim());
    final end = _parseTimestamp(line.substring(arrow + 3).trim());
    if (start == null || end == null) {
      return null;
    }
    return _Timing(start, end);
  }

  static Duration? _parseTimestamp(String raw) {
    // `HH:MM:SS.mmm`, or `MM:SS.mmm` when the hour is omitted, and any
    // trailing cue settings (`line:0% align:start`) are cut at the
    // first space.
    final text = raw.split(' ').first;
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) {
      return null;
    }
    final secondsPart = parts.last;
    final dot = secondsPart.indexOf('.');
    final seconds = int.tryParse(dot < 0 ? secondsPart : secondsPart.substring(0, dot));
    if (seconds == null) {
      return null;
    }
    final millis = dot < 0 ? 0 : int.tryParse(secondsPart.substring(dot + 1).padRight(3, '0').substring(0, 3)) ?? 0;

    final minutes = int.tryParse(parts[parts.length - 2]);
    final hours = parts.length == 3 ? int.tryParse(parts[parts.length - 3]) ?? 0 : 0;
    if (minutes == null) {
      return null;
    }

    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }
}

class _Timing {
  const _Timing(this.start, this.end);
  final Duration start;
  final Duration end;
}
