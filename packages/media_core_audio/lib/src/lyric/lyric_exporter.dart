import 'dart:convert';
import 'dart:io';

import 'package:media_core_audio/src/lyric/lyric_document.dart';

/// How much of a lyric to write into a sidecar file.
///
/// Mirrors lx-music's download options: the plain lyric, the merged
/// translation/romanization tracks, word timing and the `[awlrc:…]` container
/// that lets lx read the extended tracks back without a second request.
final class LyricExportOptions {
  /// Creates export options.
  const LyricExportOptions({
    this.includeTranslation = false,
    this.includeRomanization = false,
    this.includeWordTiming = false,
    this.includeAwlrc = false,
    this.trailingNewline = true,
  });

  /// Whether the translation track is appended.
  final bool includeTranslation;

  /// Whether the romanization track is appended.
  final bool includeRomanization;

  /// Whether word timing is written as `<startMs,duration>` tags.
  final bool includeWordTiming;

  /// Whether the `[awlrc:…]` base64 container is appended.
  final bool includeAwlrc;

  /// Whether the result ends with a newline.
  final bool trailingNewline;
}

/// Builds LRC text from a parsed lyric.
///
/// The document keeps the platform's original text, so the common case (write
/// the lyric the source returned, plus optionally its translation) is a copy,
/// not a re-serialization. Re-serialization is used for decoded formats
/// (QRC/KRC/YRC) whose original shape is not LRC at all, and for word timing —
/// the two cases where the caller explicitly asked for a transformed body.
final class LyricExporter {
  /// Creates an exporter.
  const LyricExporter();

  /// The LRC text for [document].
  String build(LyricDocument document, {LyricExportOptions options = const LyricExportOptions()}) {
    if (document.isEmpty) {
      return '';
    }

    final base = _baseText(document, options);
    final blocks = <String>[base.trim()];

    final timestamps = _lineTimestamps(document);

    if (options.includeTranslation && document.hasTranslation) {
      blocks.add(_extendedText(document, translation: true, timestamps: timestamps));
    }

    if (options.includeRomanization && document.hasRomanization) {
      blocks.add(_extendedText(document, translation: false, timestamps: timestamps));
    }

    if (options.includeAwlrc) {
      final container = _awlrc(document, options);
      if (container.isNotEmpty) {
        blocks.add(container);
      }
    }

    final text = blocks.where((block) => block.isNotEmpty).join('\n\n');

    return options.trailingNewline ? '$text\n' : text;
  }

  /// Formats [value] as `[mm:ss.mmm]`.
  static String timestamp(Duration value) {
    final totalMs = value.inMilliseconds.clamp(0, 359999999);
    final minutes = totalMs ~/ 60000;
    final seconds = (totalMs ~/ 1000) % 60;
    final millis = totalMs % 1000;

    return '[${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}]';
  }

  String _baseText(LyricDocument document, LyricExportOptions options) {
    final raw = document.raw;

    if (raw != null && raw.trim().isNotEmpty && document.format == 'lrc' && !options.includeWordTiming) {
      return raw;
    }

    return _serialize(document, options);
  }

  String _serialize(LyricDocument document, LyricExportOptions options) {
    final buffer = StringBuffer();

    for (var index = 0; index < document.lines.length; index++) {
      final line = document.lines[index];
      buffer.write(timestamp(line.start));

      if (options.includeWordTiming && line.words.isNotEmpty) {
        for (var wordIndex = 0; wordIndex < line.words.length; wordIndex++) {
          final word = line.words[wordIndex];
          final nextStart = wordIndex + 1 < line.words.length
              ? line.words[wordIndex + 1].start
              : line.endOr(line.words[wordIndex].start);
          final duration = word.duration ?? (nextStart - word.start);
          final offset = (word.start - line.start).inMilliseconds.clamp(0, 1 << 31);

          buffer
            ..write('<')
            ..write(offset)
            ..write(',')
            ..write(duration.inMilliseconds.clamp(0, 1 << 31))
            ..write('>')
            ..write(word.text);
        }
      } else {
        buffer.write(line.text);
      }

      if (index + 1 < document.lines.length) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  String _extendedText(LyricDocument document, {required bool translation, required Set<int> timestamps}) {
    final raw = translation ? document.rawTranslation : document.rawRomanization;

    // A raw track can be appended only when it is LRC: QRC/KRC/YRC use the
    // millisecond header, which lx players that read a sidecar `.lrc` do not
    // understand. Those are re-serialized from the merged document instead.
    if (raw != null && raw.trim().isNotEmpty && document.format == 'lrc') {
      return _filterExtended(raw, timestamps);
    }

    final buffer = StringBuffer();

    for (final line in document.lines) {
      final text = translation ? line.translation : line.romanization;

      if (text == null || text.trim().isEmpty) {
        continue;
      }

      buffer.writeln('${timestamp(line.start)}${text.trim()}');
    }

    return buffer.toString().trim();
  }

  /// Keeps only the translation/romanization lines whose timestamp exists in
  /// the base lyric.
  ///
  /// This is lx-music's rule: an extended track can arrive with timestamps a
  /// few milliseconds off or with lines for a different edit of the song, and
  /// appending those wholesale produces a sidecar where the translation drifts
  /// away from the words it belongs to.
  String _filterExtended(String raw, Set<int> timestamps) {
    final timeTag = RegExp(r'\[(?:(\d{1,3}):)?(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final lines = <String>[];

    for (final rawLine in raw.split(RegExp(r'\r\n|\n|\r'))) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        continue;
      }

      final matches = timeTag.allMatches(line).toList(growable: false);

      // A line without a cue is a credit, not a translation of a lyric line.
      if (matches.isEmpty) {
        continue;
      }

      final text = line.substring(matches.last.end).trim();

      if (text.isEmpty) {
        continue;
      }

      final starts = <String>[];

      for (final match in matches) {
        final start = _matchToDuration(match);

        if (timestamps.contains(start.inMilliseconds)) {
          starts.add(timestamp(start));
        }
      }

      if (starts.isEmpty) {
        continue;
      }

      // Everything matched: keep the authored tagging (lx-music does the same)
      // so a 2-digit fraction does not silently become 3-digit.
      if (starts.length == matches.length) {
        lines.add(line);
      } else {
        lines.add('${starts.join()}$text');
      }
    }

    return lines.join('\n');
  }

  Set<int> _lineTimestamps(LyricDocument document) {
    return <int>{
      for (final line in document.lines) line.start.inMilliseconds,
    };
  }

  String _awlrc(LyricDocument document, LyricExportOptions options) {
    final entries = <String>[];

    void add(String key, String? text) {
      if (text == null || text.trim().isEmpty) {
        return;
      }

      entries.add('$key:${base64Encode(utf8.encode(text.trim()))}');
    }

    final isLrc = document.format == 'lrc';

    add('lrc', isLrc ? (document.raw ?? _serialize(document, options)) : _serialize(document, options));
    add('tlrc', isLrc ? document.rawTranslation : null);
    add('rlrc', isLrc ? document.rawRomanization : null);
    add(
      'awlrc',
      _serialize(
        document,
        const LyricExportOptions(
          includeWordTiming: true,
          trailingNewline: false,
        ),
      ),
    );

    return entries.isEmpty ? '' : '[awlrc:${entries.join(',')}]';
  }

  Duration _matchToDuration(RegExpMatch match) {
    final hours = match.group(1) == null ? 0 : int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final fraction = match.group(4);

    var millis = 0;

    if (fraction != null && fraction.isNotEmpty) {
      final value = int.parse(fraction);

      millis = switch (fraction.length) {
        1 => value * 100,
        2 => value * 10,
        _ => value,
      };
    }

    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }
}

/// Text encoding for a sidecar lyric file.
enum LyricFileEncoding {
  /// UTF-8 without a byte-order mark.
  utf8,

  /// UTF-8 with a BOM, which Windows players tend to need.
  utf8Bom,

  /// Whatever the injected `LyricEncoder` produces; used for GBK, which Dart
  /// does not ship.
  custom,
}

/// Encodes a lyric string into bytes.
typedef LyricEncoder = List<int> Function(String text);

/// Writes sidecar lyric files next to downloaded audio.
///
/// File IO is kept here rather than in [LyricExporter] so the exporter stays
/// pure and testable; the writer owns the encoding and directory creation.
/// GBK is deliberately an injection point: `dart:convert` has no GBK codec,
/// and silently writing GBK bytes as UTF-8 would produce mojibake in exactly
/// the players that asked for GBK.
final class LyricFileWriter {
  /// Creates a writer.
  const LyricFileWriter();

  /// Writes [text] to [path] and returns it.
  Future<String> write(
    String path,
    String text, {
    LyricFileEncoding encoding = LyricFileEncoding.utf8Bom,
    LyricEncoder? encoder,
  }) async {
    final bytes = _encode(text, encoding, encoder);
    final file = File(path);

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  List<int> _encode(String text, LyricFileEncoding encoding, LyricEncoder? encoder) {
    switch (encoding) {
      case LyricFileEncoding.utf8:
        return utf8.encode(text);
      case LyricFileEncoding.utf8Bom:
        return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
      case LyricFileEncoding.custom:
        final custom = encoder;

        if (custom == null) {
          throw ArgumentError('LyricFileEncoding.custom requires an encoder.');
        }

        return custom(text);
    }
  }
}
