/// A timed fragment inside one lyric line (word-by-word / karaoke timing).
final class LyricWord {
  /// Creates a word.
  const LyricWord({required this.start, required this.text});

  /// When this word starts.
  final Duration start;

  /// Word text (may carry trailing punctuation/spacing as authored).
  final String text;

  @override
  String toString() => 'LyricWord(${start.inMilliseconds}ms, "$text")';
}

/// One line of a lyric, with optional translation and per-word timing.
final class LyricLine {
  /// Creates a lyric line.
  const LyricLine({
    required this.start,
    required this.text,
    this.end,
    this.translation,
    this.romanization,
    this.words = const <LyricWord>[],
  });

  /// When the line becomes current.
  final Duration start;

  /// When the next line starts, when known.
  ///
  /// Left null by the parser: the *next* line's start is the line's effective
  /// end, and filling it in during parsing would make the last line wrong.
  final Duration? end;

  /// Original text.
  final String text;

  /// Translation, when the source provided one for the same timestamp.
  final String? translation;

  /// Romanization, when provided.
  final String? romanization;

  /// Word-level timing, empty unless the lyric carried `<mm:ss.xx>` tags.
  final List<LyricWord> words;

  /// Whether the line carries no displayable text at all.
  ///
  /// A blank line is meaningful in LRC: it is how a file clears the display
  /// between verses, so it is kept rather than dropped.
  bool get isEmpty => text.trim().isEmpty && (translation ?? '').trim().isEmpty;

  /// Whether the line has word-level timing.
  bool get hasWordTiming => words.isNotEmpty;

  /// The line's end, either authored or carried by the following line.
  Duration endOr(Duration fallback) => end ?? fallback;

  /// Returns a copy with [end] filled in.
  LyricLine withEnd(Duration value) {
    return LyricLine(
      start: start,
      end: value,
      text: text,
      translation: translation,
      romanization: romanization,
      words: words,
    );
  }

  @override
  String toString() => 'LyricLine(${start.inMilliseconds}ms, "$text")';
}

/// Where a playback position falls inside a lyric document.
final class LyricPosition {
  /// Creates a position reading.
  const LyricPosition({
    required this.index,
    required this.line,
    required this.lineProgress,
    this.wordIndex = -1,
    this.wordProgress = 0,
  });

  /// Index of the active line, `-1` before the first line.
  final int index;

  /// The active line, if any.
  final LyricLine? line;

  /// Progress through the line, 0.0–1.0.
  final double lineProgress;

  /// Index of the active word, `-1` when the line has no word timing.
  final int wordIndex;

  /// Progress through the active word, 0.0–1.0.
  final double wordProgress;

  /// The position before any lyric line.
  static const LyricPosition none = LyricPosition(index: -1, line: null, lineProgress: 0);

  /// Whether a line is active.
  bool get hasLine => line != null;

  @override
  String toString() => 'LyricPosition(index: $index, lineProgress: ${lineProgress.toStringAsFixed(2)})';
}
