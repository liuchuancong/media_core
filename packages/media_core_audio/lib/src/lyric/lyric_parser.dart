import 'package:media_core_audio/src/lyric/lrc_parser.dart';
import 'package:media_core_audio/src/lyric/lyric_document.dart';
import 'package:media_core_audio/src/lyric/lyric_line.dart';

/// Lyric text formats the module understands.
///
/// Platforms do not all hand over LRC. QQ returns QRC, Kugou returns KRC and
/// NetEase returns YRC; lx-music decodes those in its source modules and keeps
/// the parser generic. This package does the same: [LyricFormat.qrc],
/// [LyricFormat.krc] and [LyricFormat.yrc] describe the *decoded* text shape
/// (a millisecond line header with parenthesised word offsets), while the
/// source keeps ownership of decryption, tokens and request signing.
enum LyricFormat {
  /// Standard LRC, including lx-music's `<startMs,duration>` word tags.
  lrc,

  /// Decoded QRC: `[startMs,duration]words (offset,duration)word…`.
  qrc,

  /// Decoded KRC, in the same millisecond shape as [qrc].
  krc,

  /// Decoded YRC, in the same millisecond shape as [qrc].
  yrc,

  /// Chooses by inspecting the text.
  auto;

  /// Maps a source-provided format hint, defaulting to [auto].
  static LyricFormat fromName(String? name) {
    return switch (name?.trim().toLowerCase()) {
      'lrc' => LyricFormat.lrc,
      'qrc' => LyricFormat.qrc,
      'krc' => LyricFormat.krc,
      'yrc' => LyricFormat.yrc,
      _ => LyricFormat.auto,
    };
  }
}

/// Parses any supported lyric text into a [LyricDocument].
///
/// A source reports the format it returned through
/// `MusicLyricPayload.format`; [LyricFormat.auto] sniffs the text when the
/// source does not know. The fallback is always the LRC parser, so a payload
/// with an unfamiliar hint still produces something displayable instead of an
/// empty document.
final class LyricParser {
  /// Creates a parser.
  const LyricParser({this.lrc = const LrcParser()});

  /// Parser used for LRC and as the fallback.
  final LrcParser lrc;

  /// Parses [text], merging [translation] and [romanization] when present.
  LyricDocument parse(
    String text, {
    String? format,
    String? translation,
    String? romanization,
  }) {
    final kind = _resolve(text, LyricFormat.fromName(format));

    return switch (kind) {
      LyricFormat.qrc || LyricFormat.krc || LyricFormat.yrc => MillisecondLyricParser(format: kind.name).parse(
        text,
        translation: translation,
        romanization: romanization,
      ),
      LyricFormat.lrc || LyricFormat.auto => lrc.parse(text, translation: translation, romanization: romanization),
    };
  }

  LyricFormat _resolve(String text, LyricFormat declared) {
    if (declared != LyricFormat.auto) {
      return declared;
    }

    // A millisecond header is the unambiguous shape shared by decoded
    // QRC/KRC/YRC; LRC always has a colon in its timestamp.
    return MillisecondLyricParser.millisecondHeader.hasMatch(text) ? LyricFormat.qrc : LyricFormat.lrc;
  }
}

/// Parser for the millisecond line format decoded QRC/KRC/YRC lyrics use.
///
/// The shape is `[lineStartMs,lineDurationMs]text`, with word timing written as
/// `(startMs,durationMs)` or `(startMs,durationMs,0)` where the start is
/// relative to the line. Authoring quirks are tolerated: missing durations,
/// blank lines, BOMs and metadata lines are skipped rather than parsed as
/// lyrics.
final class MillisecondLyricParser {
  /// Creates a parser.
  const MillisecondLyricParser({this.format = 'qrc'});

  /// Format name recorded on the produced document.
  final String format;

  /// Matches `[1234,567]text`.
  static final RegExp millisecondHeader = RegExp(r'^\[(\d+),(\d+)\]');

  static final RegExp _wordTag = RegExp(r'\((\d+),(\d+)(?:,\d+)?\)');
  static final RegExp _metadataTag = RegExp(r'^\[([a-zA-Z_]+):(.*)\]$');

  /// Parses [text], merging optional translation and romanization tracks.
  LyricDocument parse(String text, {String? translation, String? romanization}) {
    if (text.trim().isEmpty) {
      return LyricDocument.empty;
    }

    final metadata = <String, String>{};
    final lines = _parseTrack(text, metadata);

    if (lines.isEmpty) {
      // The hint said QRC but the body is ordinary LRC: let the LRC parser
      // handle it rather than reporting an unsynchronized wall of tags.
      return const LrcParser().parse(
        text,
        translation: translation,
        romanization: romanization,
      );
    }

    final translationIndex = _indexTrack(translation);
    final romanizationIndex = _indexTrack(romanization);

    final merged = <LyricLine>[
      for (final line in lines)
        LyricLine(
          start: line.start,
          end: line.end,
          text: line.text,
          words: line.words,
          translation: translationIndex[line.start.inMilliseconds],
          romanization: romanizationIndex[line.start.inMilliseconds],
        ),
    ];

    return LyricDocument(
      lines: List<LyricLine>.unmodifiable(merged..sort((a, b) => a.start.compareTo(b.start))),
      metadata: Map<String, String>.unmodifiable(metadata),
      raw: text,
      rawTranslation: translation,
      rawRomanization: romanization,
      format: format,
    );
  }

  List<LyricLine> _parseTrack(String text, Map<String, String> metadata) {
    final lines = <LyricLine>[];

    for (final rawLine in text.split(RegExp(r'\r\n|\n|\r'))) {
      final line = rawLine.replaceFirst('\uFEFF', '').trim();

      if (line.isEmpty) {
        continue;
      }

      final header = millisecondHeader.firstMatch(line);

      if (header == null) {
        final meta = _metadataTag.firstMatch(line);

        if (meta != null) {
          metadata[meta.group(1)!.toLowerCase()] = meta.group(2)!.trim();
        }

        continue;
      }

      final startMs = int.parse(header.group(1)!);
      final durationMs = int.parse(header.group(2)!);
      final start = Duration(milliseconds: startMs);
      final content = line.substring(header.end);

      final words = _parseWords(content, start);

      lines.add(
        LyricLine(
          start: start,
          end: durationMs > 0 ? start + Duration(milliseconds: durationMs) : null,
          text: words.isEmpty ? content.trim() : words.map((word) => word.text).join().trim(),
          words: words,
        ),
      );
    }

    return lines;
  }

  List<LyricWord> _parseWords(String content, Duration lineStart) {
    final matches = _wordTag.allMatches(content).toList(growable: false);

    if (matches.isEmpty) {
      return const <LyricWord>[];
    }

    final words = <LyricWord>[];

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : content.length;
      final text = content.substring(match.end, end);

      if (text.isEmpty) {
        continue;
      }

      words.add(
        LyricWord(
          start: lineStart + Duration(milliseconds: int.parse(match.group(1)!)),
          text: text,
          duration: Duration(milliseconds: int.parse(match.group(2)!)),
        ),
      );
    }

    return List<LyricWord>.unmodifiable(words);
  }

  Map<int, String> _indexTrack(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const <int, String>{};
    }

    final metadata = <String, String>{};
    final lines = _parseTrack(text, metadata);

    if (lines.isEmpty) {
      // A translation in plain LRC arrives with its own timestamps; delegate so
      // the merge still lines up with the base track's millisecond keys.
      final parsed = const LrcParser().parse(text);

      return <int, String>{
        for (final line in parsed.lines)
          if (line.text.trim().isNotEmpty) line.start.inMilliseconds: line.text,
      };
    }

    return <int, String>{
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line.start.inMilliseconds: line.text,
    };
  }
}
