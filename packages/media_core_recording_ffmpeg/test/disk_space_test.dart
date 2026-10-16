import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

ProcessResult _result(int exitCode, String stdout) => ProcessResult(0, exitCode, stdout, '');

void main() {
  group('df output', () {
    test('the fourth column of the last line, in 1K blocks', () {
      const reply = '''
Filesystem             1024-blocks      Used Available Capacity Mounted on
/dev/sda1              483264524  345169288  117548736      75% /
''';

      expect(FfmpegDiskSpace.parseDf(reply), 117548736 * 1024);
    });

    test('a header alone or one field short is not an answer', () {
      expect(FfmpegDiskSpace.parseDf('Filesystem 1024-blocks Used Available Capacity Mounted on\n'), isNull);
      expect(FfmpegDiskSpace.parseDf('/dev/sda1 483264524 345169288\n'), isNull);
      expect(FfmpegDiskSpace.parseDf(''), isNull);
    });

    test('"not measurable" is unknown, never zero', () {
      // A zero would refuse a recording that had plenty of room; `-P` prints `-` or
      // `*` in the available column for a filesystem that cannot report it.
      expect(FfmpegDiskSpace.parseDf('Filesystem 1024-blocks Used Available Capacity Mounted on\nnone - - - - /here\n'), isNull);
      expect(FfmpegDiskSpace.parseDf('Filesystem 1024-blocks Used Available Capacity Mounted on\nnone 1 1 * - /here\n'), isNull);
    });

    test('the POSIX format never wraps, which is why -kP is asked for', () {
      expect(FfmpegDiskSpace.dfArguments('/x/recordings'), <String>['-kP', '/x/recordings']);
    });
  });

  group('Windows volume', () {
    test('a drive letter becomes the root form DriveInfo takes', () {
      expect(FfmpegDiskSpace.windowsRoot(r'C:\Users\me\recordings'), r'C:\');
      expect(FfmpegDiskSpace.windowsRoot(r'c:\x'), r'c:\');
      expect(FfmpegDiskSpace.windowsRoot(r'\\nas\share\room-42'), isNull, reason: 'a UNC path has no drive to ask about');
      expect(FfmpegDiskSpace.windowsRoot('/mnt/data'), isNull);
    });

    test('the root is passed through a single-quoted PowerShell string, unescaped', () {
      final arguments = FfmpegDiskSpace.powershellArguments(r'D:\media\recordings');

      expect(arguments, isNotNull);
      expect(arguments!.first, '-NoProfile');
      // Doubling the backslash here would ask DriveInfo about something that is not
      // a root: inside single quotes PowerShell has no escape sequences.
      expect(arguments[3], r"(New-Object System.IO.DriveInfo('D:\')).AvailableFreeSpace");
      expect(FfmpegDiskSpace.powershellArguments(r'\\nas\share'), isNull);
    });

    test('a plain byte count, with or without the thousands separator', () {
      expect(FfmpegDiskSpace.parseWindows(' 12345678901 \n'), 12345678901);
      expect(FfmpegDiskSpace.parseWindows('12,345,678,901'), 12345678901);
      expect(FfmpegDiskSpace.parseWindows(''), isNull);
      expect(FfmpegDiskSpace.parseWindows('Get-Object : not found'), isNull);
    });
  });

  group('asking the platform', () {
    test('the platform in front of us is asked the way that platform answers', () async {
      final asked = <List<String>>[];

      final free = await FfmpegDiskSpace.probe(
        Platform.isWindows ? r'C:\tmp\recordings' : '/tmp/recordings',
        run: (executable, arguments) async {
          asked.add(<String>[executable, ...arguments]);

          return _result(
            0,
            Platform.isWindows
                ? '1073741824'
                : 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/sda1 1 1 1048576 0% /tmp\n',
          );
        },
      );

      expect(asked.single.first, Platform.isWindows ? 'powershell' : 'df');
      expect(free, Platform.isWindows ? 1073741824 : 1048576 * 1024);
    });

    test('a tool that is not there, or that refused, is no answer', () async {
      expect(
        await FfmpegDiskSpace.probe('/tmp', run: (e, a) async => throw StateError('no df here')),
        isNull,
        reason: 'cannot ask is not "the disk is full"',
      );
      expect(await FfmpegDiskSpace.probe('/tmp', run: (e, a) async => _result(1, '')), isNull);
      expect(await FfmpegDiskSpace.probe('/tmp', run: (e, a) async => _result(0, 'nonsense')), isNull);
    });

    test('a path with no volume to ask about never runs anything', () async {
      var calls = 0;

      final free = await FfmpegDiskSpace.probe(r'\\nas\share\room', run: (e, a) async {
        calls++;

        return _result(0, '1');
      });

      if (Platform.isWindows) {
        expect(free, isNull);
        expect(calls, 0, reason: 'the question could not be phrased, so none was asked');
      } else {
        // On a POSIX host the same path is just a directory name to `df`, which
        // either answers or does not; the point of this branch is that the probe
        // never throws about it.
        expect(calls, 1);
      }
    });
  });
}
