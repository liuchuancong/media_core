import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:media_core_audio/media_core_audio.dart';

void main() {
  group('LrcParser', () {
    test('handles hh:mm:ss timestamps, multiple cues and the offset tag', () {
      const text = '''
[ti:Test]
[offset:500]
[00:01.00]first
[00:02.50][00:03.50]chorus
''';

      final document = const LrcParser().parse(text);

      expect(document.metadata['ti'], 'Test');
      expect(document.lines.map((line) => line.start.inMilliseconds), <int>[500, 2000, 3000]);
      expect(document.lines.map((line) => line.text), <String>['first', 'chorus', 'chorus']);
    });

    test('reads absolute and relative word timing into absolute starts', () {
      const text = '''
[00:04.00]<00:04.00>Hello <00:04.50>world
[00:10.000]<0,500>Hi <500,300>there
''';

      final document = const LrcParser().parse(text);

      final first = document.lines.first;
      expect(first.words.map((word) => word.start.inMilliseconds), <int>[4000, 4500]);

      final second = document.lines.last;
      expect(second.words.map((word) => word.start.inMilliseconds), <int>[10000, 10500]);
      expect(second.words.map((word) => word.duration?.inMilliseconds), <int>[500, 300]);
    });

    test('merges translation by timestamp and keeps it out of the line text', () {
      const text = '[00:01.00]hello\n[00:02.00]world';
      const translation = '[00:01.00]你好\n[00:02.00]世界';

      final document = const LrcParser().parse(text, translation: translation);

      expect(document.lines.map((line) => line.translation), <String?>['你好', '世界']);
      expect(document.lines.map((line) => line.text), <String>['hello', 'world']);
      expect(document.hasTranslation, isTrue);
    });

    test('plain text becomes an unsynchronized document rather than empty', () {
      final document = const LrcParser().parse('just words\nno timing');

      expect(document.isSynchronized, isFalse);
      expect(document.length, 2);
    });
  });

  group('LyricDocument offset', () {
    const text = '[00:01.00]one\n[00:05.00]two';
    final document = const LrcParser().parse(text);

    test('positive offset delays which line is active', () {
      // At 1.2 s with a 500 ms delay the first line has not started yet.
      expect(document.indexAt(const Duration(milliseconds: 1200), offset: const Duration(milliseconds: 500)), -1);
      expect(document.indexAt(const Duration(milliseconds: 1600), offset: const Duration(milliseconds: 500)), 0);
    });

    test('withOffset keeps the parsed lines and changes the answer', () {
      final delayed = document.withOffset(const Duration(seconds: 1));

      expect(identical(delayed.lines, document.lines), isTrue);
      expect(delayed.lineAt(const Duration(seconds: 1)), isNull);
      expect(delayed.lineAt(const Duration(seconds: 2))?.text, 'one');
    });

    test('shifted moves timestamps but drops the raw text', () {
      final shifted = document.shifted(const Duration(seconds: 2));

      expect(shifted.lines.first.start, const Duration(seconds: 3));
      expect(shifted.raw, isNull);
    });
  });

  group('QRC/KRC/YRC decoded text', () {
    test('parses millisecond headers and parenthesised word offsets', () {
      const text = '''
[0,1500]hello (0,500)he (500,500)llo
[1500,1000]world
''';
      const translation = '''
[0,1500]你好 (0,500)你 (500,500)好
''';

      final document = const LyricParser().parse(text, format: 'qrc', translation: translation);

      expect(document.format, 'qrc');
      expect(document.lines.first.start, Duration.zero);
      expect(document.lines.first.end, const Duration(milliseconds: 1500));
      // Spaces stay attached to the word they follow, as authored.
      expect(document.lines.first.words.map((word) => word.text), <String>['he ', 'llo']);
      expect(document.lines.first.translation, '你 好');
    });

    test('detects the format when the hint is auto', () {
      final document = const LyricParser().parse('[0,1000]hello');

      expect(document.lines.single.text, 'hello');
      expect(document.format, 'qrc');
    });

    test('falls back to the LRC parser when the millisecond shape is absent', () {
      final document = const LyricParser().parse('[00:01.00]hello', format: 'krc');

      expect(document.lines.single.start, const Duration(seconds: 1));
    });
  });

  group('LyricTimeline offset', () {
    test('setOffset re-evaluates the last position and emits once', () async {
      final document = const LrcParser().parse('[00:01.00]one\n[00:05.00]two');
      final timeline = LyricTimeline(document: document);
      final readings = <LyricPosition>[];

      final subscription = timeline.changes.listen(readings.add);

      timeline
        ..update(const Duration(milliseconds: 1500))
        ..setOffset(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(readings.map((reading) => reading.index), <int>[0, -1]);

      await subscription.cancel();
      await timeline.dispose();
    });
  });

  group('LyricExporter', () {
    const text = '[00:01.00]hello\n[00:02.00]world';
    const translation = '[00:01.00]你好\n[00:02.50]世界';

    test('keeps the original text and filters translation cues by timestamp', () {
      final document = const LrcParser().parse(text, translation: translation);

      final exported = const LyricExporter().build(
        document,
        options: const LyricExportOptions(includeTranslation: true),
      );

      expect(exported, contains('[00:01.00]hello'));
      expect(exported, contains('[00:01.00]你好'));
      // The 2.5 s translation has no base cue at 2.5 s and is dropped.
      expect(exported, isNot(contains('世界')));
    });

    test('writes word timing as lx extended tags when asked', () {
      final document = const LrcParser().parse('[00:10.000]<0,500>Hi <500,300>there');

      final exported = const LyricExporter().build(
        document,
        options: const LyricExportOptions(includeWordTiming: true),
      );

      expect(exported, contains('<0,500>Hi'));
      expect(exported, contains('<500,300>there'));
    });

    test('re-serializes decoded QRC tracks as LRC in the sidecar', () {
      final document = const LyricParser().parse(
        '[0,1500]hello (0,500)he (500,500)llo',
        format: 'qrc',
        translation: '[0,1500]你好 (0,500)你 (500,500)好',
      );

      final exported = const LyricExporter().build(
        document,
        options: const LyricExportOptions(includeTranslation: true),
      );

      expect(exported, contains('[00:00.000]he llo'));
      expect(exported, contains('[00:00.000]你 好'));
      expect(exported, isNot(contains('[0,1500]')));
    });

    test('appends the awlrc container with base64 tracks', () {
      final document = const LrcParser().parse(text, translation: translation);

      final exported = const LyricExporter().build(
        document,
        options: const LyricExportOptions(includeAwlrc: true),
      );

      expect(exported, contains('[awlrc:lrc:'));
      expect(exported, contains(',tlrc:'));
    });
  });

  group('LyricFileWriter', () {
    test('writes a UTF-8 BOM by default and creates the directory', () async {
      final directory = await Directory.systemTemp.createTemp('lyric-writer-');
      final path = '${directory.path}/nested/test.lrc';

      try {
        await const LyricFileWriter().write(path, '[00:01.00]hello');

        final bytes = await File(path).readAsBytes();

        expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
        expect(String.fromCharCodes(bytes.skip(3)), '[00:01.00]hello');
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('a custom encoder is used verbatim', () async {
      final directory = await Directory.systemTemp.createTemp('lyric-encoder-');
      final path = '${directory.path}/test.lrc';

      try {
        await const LyricFileWriter().write(
          path,
          'abc',
          encoding: LyricFileEncoding.custom,
          encoder: (text) => text.codeUnits.reversed.toList(),
        );

        expect(await File(path).readAsBytes(), <int>[99, 98, 97]);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
