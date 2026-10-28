import 'package:media_core_audio/src/lyric/lyric_line.dart';

/// A parsed lyric, ready for timed display.
///
/// The document is immutable and holds no cursor: "which line is current" is a
/// pure function of a playback position ([indexAt] / [positionAt]), so a
/// timeline, a desktop-lyric window and a notification can each ask the same
/// question without sharing state.
final class LyricDocument {
  /// Creates a document from already-sorted [lines].
  const LyricDocument({
    required this.lines,
    this.metadata = const <String, String>{},
    this.isSynchronized = true,
    this.offset = Duration.zero,
    this.raw,
    this.rawTranslation,
    this.rawRomanization,
    this.format = 'lrc',
  });

  /// Creates a document from plain text with no timing.
  ///
  /// Unsynchronized lyrics (plain `.txt`, a lyric endpoint without timestamps)
  /// are still worth showing; they are simply never highlighted, which is
  /// exactly what [isSynchronized] tells the UI layer.
  factory LyricDocument.unsynchronized(String text) {
    final lines = text
        .split('\n')
        .map((line) => LyricLine(start: Duration.zero, text: line.trimRight()))
        .toList(growable: false);

    return LyricDocument(lines: lines, isSynchronized: false, raw: text, format: 'text');
  }

  /// A document with nothing to show.
  static const LyricDocument empty = LyricDocument(lines: <LyricLine>[]);

  /// Lines, ordered by start time.
  final List<LyricLine> lines;

  /// LRC metadata tags (`ti`, `ar`, `al`, `by`, `offset`, …).
  final Map<String, String> metadata;

  /// Whether the lines carry timing.
  final bool isSynchronized;

  /// Viewer-adjusted delay applied to every lookup.
  ///
  /// Positive values delay the lyric (a line authored at 10 s starts being
  /// highlighted at 10 s + offset); negative values make it appear earlier.
  /// Kept on the document instead of rewriting [lines] so one cached parse can
  /// serve any number of offset values — lx-music's slider changes this
  /// constantly and must not trigger a refetch.
  final Duration offset;

  /// Original lyric text, when it came from a parser.
  ///
  /// Kept for exporting a sidecar `.lrc` without reconstructing (and possibly
  /// degrading) the file the platform handed over, and so the `[awlrc:…]`
  /// container lx-music writes can round-trip.
  final String? raw;

  /// Original translation track, when one was merged.
  final String? rawTranslation;

  /// Original romanization track, when one was merged.
  final String? rawRomanization;

  /// Source format hint (`lrc`, `qrc`, `krc`, `yrc`, `text`).
  final String format;

  /// Whether a translation track is present.
  bool get hasTranslation => lines.any((line) => (line.translation ?? '').trim().isNotEmpty);

  /// Whether a romanization track is present.
  bool get hasRomanization => lines.any((line) => (line.romanization ?? '').trim().isNotEmpty);

  /// A copy with a different viewer offset; the parsed lines are shared.
  LyricDocument withOffset(Duration value) {
    if (value == offset) {
      return this;
    }

    return LyricDocument(
      lines: lines,
      metadata: metadata,
      isSynchronized: isSynchronized,
      offset: value,
      raw: raw,
      rawTranslation: rawTranslation,
      rawRomanization: rawRomanization,
      format: format,
    );
  }

  /// A copy with every timestamp physically moved by [delta].
  ///
  /// Unlike [withOffset] this loses [raw]: the text no longer matches the
  /// returned timestamps, so exporting it would ship a contradictory file.
  LyricDocument shifted(Duration delta) {
    return LyricDocument(
      lines: List<LyricLine>.unmodifiable(lines.map((line) => line.shifted(delta))),
      metadata: metadata,
      isSynchronized: isSynchronized,
      format: format,
    );
  }

  /// Whether there is nothing to display.
  bool get isEmpty => lines.isEmpty || lines.every((line) => line.isEmpty && line.text.trim().isEmpty);

  /// Number of lines.
  int get length => lines.length;

  /// Reads a metadata tag.
  String? meta(String key) => metadata[key];

  /// Index of the line active at [position], or `-1` before the first line.
  ///
  /// Binary search: lyric files reach a few hundred lines and the position is
  /// polled several times a second, so this has to stay O(log n) — a linear
  /// scan per tick was the classic hot spot in lyric renderers.
  int indexAt(Duration position, {Duration? offset}) {
    if (lines.isEmpty) {
      return -1;
    }

    final effective = position - (offset ?? this.offset);

    if (effective < lines.first.start) {
      return -1;
    }

    var low = 0;
    var high = lines.length - 1;

    while (low <= high) {
      final middle = (low + high) >> 1;
      final start = lines[middle].start;

      if (start <= effective) {
        final next = middle + 1 < lines.length ? lines[middle + 1].start : null;

        if (next == null || next > effective) {
          return middle;
        }

        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    return -1;
  }

  /// The line active at [position], if any.
  LyricLine? lineAt(Duration position, {Duration? offset}) {
    final index = indexAt(position, offset: offset);

    return index < 0 ? null : lines[index];
  }

  /// A full reading of [position]: active line, line progress and, when the
  /// line carries word timing, the active word and its progress.
  LyricPosition positionAt(Duration position, {Duration? offset}) {
    final effective = position - (offset ?? this.offset);
    final index = indexAt(position, offset: offset);

    if (index < 0) {
      return LyricPosition.none;
    }

    final line = lines[index];
    final end = line.end ?? (index + 1 < lines.length ? lines[index + 1].start : null);

    final lineProgress = _progress(line.start, end, effective);

    if (!line.hasWordTiming) {
      return LyricPosition(index: index, line: line, lineProgress: lineProgress);
    }

    var wordIndex = -1;

    for (var i = 0; i < line.words.length; i++) {
      if (line.words[i].start <= effective) {
        wordIndex = i;
      } else {
        break;
      }
    }

    if (wordIndex < 0) {
      return LyricPosition(index: index, line: line, lineProgress: lineProgress);
    }

    final word = line.words[wordIndex];

    // The next word's start is the real end of this one; only the last word
    // falls back to its authored duration or the line's end.
    final wordEnd = wordIndex + 1 < line.words.length
        ? line.words[wordIndex + 1].start
        : (word.duration == null ? end : word.start + word.duration!);

    return LyricPosition(
      index: index,
      line: line,
      lineProgress: lineProgress,
      wordIndex: wordIndex,
      wordProgress: _progress(word.start, wordEnd, effective),
    );
  }

  /// The line following [index], if any.
  LyricLine? lineAfter(int index) => index + 1 < lines.length ? lines[index + 1] : null;

  double _progress(Duration start, Duration? end, Duration position) {
    if (end == null || end <= start) {
      // A line with no knowable end (the last one, or an authored one that
      // never finishes) reads as fully elapsed rather than stuck at 0.
      return 1;
    }

    final span = (end - start).inMilliseconds;
    final elapsed = (position - start).inMilliseconds;

    return (elapsed / span).clamp(0.0, 1.0);
  }

  @override
  String toString() => 'LyricDocument(${lines.length} lines, synchronized: $isSynchronized)';
}
