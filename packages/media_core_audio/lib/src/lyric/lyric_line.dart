/// A timed fragment inside one lyric line (word-by-word / karaoke timing).
///
/// Two authoring styles resolve to the same model: absolute tags
/// (`<mm:ss.xx>word`, the enhanced-LRC spelling) and relative offsets
/// (`<startMs,duration>word`, the shape lx-music's decoded QRC/KRC/YRC lyrics
/// use). [start] is always absolute; [duration] is kept only when the source
/// authored one, because the next word's start is usually the real end and a
/// stale authored duration would make the highlight overshoot.
final class LyricWord {
  /// Creates a word.
  const LyricWord({required this.start, required this.text, this.duration});

  /// When this word starts.
  final Duration start;

  /// Word text (may carry trailing punctuation/spacing as authored).
  final String text;

  /// Authored word duration, when the source carried one.
  final Duration? duration;

  /// A copy moved by [offset]; negative results clamp at zero.
  LyricWord shifted(Duration offset) {
    final moved = start + offset;

    return LyricWord(
      start: moved < Duration.zero ? Duration.zero : moved,
      text: text,
      duration: duration,
    );
  }

  @override
  String toString() => 'LyricWord(${start.inMilliseconds}ms, "$text"${duration == null ? '' : ', ${duration!.inMilliseconds}ms'})';
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

  /// Returns a copy moved by [offset].
  ///
  /// A negative shift clamps at zero rather than producing a negative
  /// timestamp, which no player can seek to.
  LyricLine shifted(Duration offset) {
    final moved = start + offset;

    return LyricLine(
      start: moved < Duration.zero ? Duration.zero : moved,
      end: end == null ? null : (end! + offset < Duration.zero ? Duration.zero : end! + offset),
      text: text,
      translation: translation,
      romanization: romanization,
      words: words.isEmpty
          ? const <LyricWord>[]
          : List<LyricWord>.unmodifiable(words.map((word) => word.shifted(offset))),
    );
  }

  /// Secondary display lines (translation / romanization) in display order.
  ///
  /// lx-music lets a viewer toggle either track and swap which one sits closer
  /// to the original; returning a list keeps that decision out of the parser
  /// and out of the renderer.
  List<String> secondaryTexts({bool showTranslation = true, bool showRomanization = true, bool swap = false}) {
    final translationText = showTranslation ? translation?.trim() : null;
    final romanizationText = showRomanization ? romanization?.trim() : null;

    final ordered = swap
        ? <String?>[romanizationText, translationText]
        : <String?>[translationText, romanizationText];

    return ordered.whereType<String>().where((text) => text.isNotEmpty).toList(growable: false);
  }

  /// Secondary display text joined with newlines, or null when there is none.
  String? secondaryText({bool showTranslation = true, bool showRomanization = true, bool swap = false}) {
    final texts = secondaryTexts(
      showTranslation: showTranslation,
      showRomanization: showRomanization,
      swap: swap,
    );

    return texts.isEmpty ? null : texts.join('\n');
  }

  @override
  String toString() => 'LyricLine(${start.inMilliseconds}ms, "$text")';
}

/// Which secondary lyric tracks a renderer should show.
///
/// The document always carries both; this is the viewer's choice, not a
/// property of the lyric file — the same reason lx-music can toggle translation
/// and romanization without refetching anything.
final class LyricDisplayOptions {
  /// Creates display options.
  const LyricDisplayOptions({
    this.showTranslation = true,
    this.showRomanization = true,
    this.swapTranslationAndRomanization = false,
  });

  /// Whether translation lines are shown.
  final bool showTranslation;

  /// Whether romanization lines are shown.
  final bool showRomanization;

  /// Whether romanization is placed before translation.
  final bool swapTranslationAndRomanization;

  /// The secondary lines for [line].
  List<String> textsFor(LyricLine line) {
    return line.secondaryTexts(
      showTranslation: showTranslation,
      showRomanization: showRomanization,
      swap: swapTranslationAndRomanization,
    );
  }

  /// A copy with selected fields replaced.
  LyricDisplayOptions copyWith({
    bool? showTranslation,
    bool? showRomanization,
    bool? swapTranslationAndRomanization,
  }) {
    return LyricDisplayOptions(
      showTranslation: showTranslation ?? this.showTranslation,
      showRomanization: showRomanization ?? this.showRomanization,
      swapTranslationAndRomanization: swapTranslationAndRomanization ?? this.swapTranslationAndRomanization,
    );
  }
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
