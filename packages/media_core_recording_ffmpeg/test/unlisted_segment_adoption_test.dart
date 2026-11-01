import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';
import 'package:media_core_recording_ffmpeg/src/config/output_path.dart';

/// The take directory a test writes into, removed with the test that made it.
Directory _tempDirectory() {
  final directory = Directory.systemTemp.createTempSync('media_core_unlisted_segments');

  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  return directory;
}

/// Writes [bytes] into a file named [name] under [directory].
File _write(Directory directory, String name, {int bytes = 8192}) {
  return File(joinOutputPath(directory.path, name))
    ..createSync(recursive: true)
    ..writeAsBytesSync(List<int>.filled(bytes, 0));
}

/// The journal FFmpeg would have left after closing exactly [segments] segments
/// of the recording named [prefix], written under the conventional suffixes.
File _writeJournal(Directory directory, String prefix, List<int> segments) {
  final journal = File(joinOutputPath(directory.path, '$prefix$kFfmpegDefaultJournalSuffix'));
  final lines = segments.map((index) => "file,'${prefix}_${index.toString().padLeft(6, '0')}.clock-v1.ts'").join('\n');

  journal.writeAsStringSync(lines.isEmpty ? '' : '$lines\n');

  return journal;
}

/// Where the attempt named [prefix] keeps its files.
UnlistedSegmentSource _source(Directory directory, String prefix) => UnlistedSegmentSource(
  directory: directory.path,
  prefix: prefix,
  segmentSuffix: FfmpegRecordContainer.mpegTs.segmentSuffix,
);

void main() {
  group('FfmpegSegmentJournal unlisted-segment adoption', () {
    late Directory directory;
    late String prefix;

    setUp(() {
      directory = _tempDirectory();
      prefix = 'rec_20261101_221129_653';
    });

    test('the segment a stop left open is the recording, when nothing closed', () {
      // The short-recording case: `-segment_time` is minutes, the viewer stopped
      // after seconds, so the journal is empty and the only output on disk is the
      // segment FFmpeg was still writing.
      final journal = _writeJournal(directory, prefix, <int>[]);
      _write(directory, '${prefix}_000000.clock-v1.ts');

      final read = FfmpegSegmentJournal.fromFiles(
        <File>[journal],
        unlisted: <UnlistedSegmentSource>[_source(directory, prefix)],
      );

      expect(read.length, 1);
      expect(read.entries.single.name, '${prefix}_000000.clock-v1.ts');
      expect(read.totalBytes, 8192);
    });

    test('a verdict over an adopted segment is a recording, not missing output', () async {
      final journal = _writeJournal(directory, prefix, <int>[]);
      _write(directory, '${prefix}_000000.clock-v1.ts');

      final check = await FfmpegRecordingCheck.evaluate(
        journal: FfmpegSegmentJournal.fromFiles(
          <File>[journal],
          unlisted: <UnlistedSegmentSource>[_source(directory, prefix)],
        ),
        claimedDuration: const Duration(seconds: 9),
      );

      expect(check.verdict, FfmpegRecordingVerdict.complete);
      expect(check.isUsable, isTrue);
      expect(check.bytesOnDisk, 8192);
    });

    test('the tail joins after the closed segments of its own attempt', () {
      final first = _writeJournal(directory, prefix, <int>[0, 1]);
      final second = _writeJournal(directory, '${prefix}_r1', <int>[0]);

      for (final name in <String>[
        '${prefix}_000000.clock-v1.ts',
        '${prefix}_000001.clock-v1.ts',
        '${prefix}_000002.clock-v1.ts',
        '${prefix}_r1_000000.clock-v1.ts',
      ]) {
        _write(directory, name);
      }

      final read = FfmpegSegmentJournal.fromFiles(
        <File>[first, second],
        unlisted: <UnlistedSegmentSource>[_source(directory, prefix), _source(directory, '${prefix}_r1')],
      );

      // `_000002` belongs between attempt 0's list and attempt 1's, not at the
      // end: a merge reads this order back as a concat list.
      expect(read.entries.map((entry) => entry.name).toList(), <String>[
        '${prefix}_000000.clock-v1.ts',
        '${prefix}_000001.clock-v1.ts',
        '${prefix}_000002.clock-v1.ts',
        '${prefix}_r1_000000.clock-v1.ts',
      ]);
    });

    test('a segment the journal already named is not counted twice', () {
      final journal = _writeJournal(directory, prefix, <int>[0]);
      _write(directory, '${prefix}_000000.clock-v1.ts');

      final read = FfmpegSegmentJournal.fromFiles(
        <File>[journal],
        unlisted: <UnlistedSegmentSource>[_source(directory, prefix)],
      );

      expect(read.length, 1);
      expect(read.totalBytes, 8192);
    });

    test('what the attempt cannot own stays out of the list', () {
      final journal = _writeJournal(directory, prefix, <int>[]);

      _write(directory, '$prefix.combined.mp4'); // a merge, not a segment
      _write(directory, 'other_000000.clock-v1.ts'); // a different recording
      _write(directory, '${prefix}_000000.clock-v1.mp4'); // the other container's suffix
      _write(directory, '${prefix}_000001.clock-v1.ts', bytes: 0); // opened and abandoned

      final read = FfmpegSegmentJournal.fromFiles(
        <File>[journal],
        unlisted: <UnlistedSegmentSource>[_source(directory, prefix)],
      );

      expect(read.isEmpty, isTrue);
    });

    test("a file from before this session is not this session's output", () {
      final journal = _writeJournal(directory, prefix, <int>[]);

      // Backdate it past the session's start: the same lie a stale journal tells.
      _write(
        directory,
        '${prefix}_000000.clock-v1.ts',
      ).setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

      final read = FfmpegSegmentJournal.fromFiles(
        <File>[journal],
        notBefore: DateTime.now().subtract(const Duration(minutes: 1)),
        unlisted: <UnlistedSegmentSource>[_source(directory, prefix)],
      );

      expect(read.isEmpty, isTrue);
    });

    test('without a source to scan, the reader says what the journal says', () {
      _writeJournal(directory, prefix, <int>[]);
      _write(directory, '${prefix}_000000.clock-v1.ts');

      final journal = File(joinOutputPath(directory.path, '$prefix$kFfmpegDefaultJournalSuffix'));

      expect(FfmpegSegmentJournal.fromFiles(<File>[journal]).isEmpty, isTrue);
    });
  });

  group('journal naming helpers', () {
    test('a re-opened attempt owns a prefixed name of its own', () {
      expect(attemptFilePrefix('rec_a', 0), 'rec_a');
      expect(attemptFilePrefix('rec_a', 1), 'rec_a_r1');
      expect(attemptFilePrefix('rec_a', 2), 'rec_a_r2');
    });

    test('a journal names the prefix its segments were written under', () {
      expect(journalFilePrefix(r'C:\takes\rec_a.clock-v1.csv', '.clock-v1.csv'), 'rec_a');
      expect(journalFilePrefix('/takes/rec_a_r1.clock-v1.csv', '.clock-v1.csv'), 'rec_a_r1');

      // A host that renamed its journal keeps the name rather than losing it to a
      // substring run off the end.
      expect(journalFilePrefix('/takes/notes.txt', '.clock-v1.csv'), 'notes.txt');
    });
  });
}
