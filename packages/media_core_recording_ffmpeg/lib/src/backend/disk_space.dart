import 'dart:io' show Platform, Process, ProcessResult;

/// How `FfmpegDiskSpace` asks the platform, as a seam a test can answer.
///
/// The real one is [Process.run]. A fake returns a canned `ProcessResult`, which is
/// how the parsing is tested without a disk, and how a platform whose tool is
/// missing (`powershell` on a locked-down box) is tested without one either.
typedef DiskSpaceRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Free space on the volume holding a directory, read from the platform's own tool.
///
/// Dart has no API for this, and the packages that offer it are per-platform
/// plugins — but a recording does not need a number it can put in a graph, it needs
/// "is there room to start writing here", and that question has a portable answer:
/// ask the operating system the way its own users would. Android ships `df` in
/// toybox, Linux and macOS both answer `df -kP`, and Windows answers
/// `System.IO.DriveInfo`.
///
/// Everything here is **best effort**: any part that cannot be asked, parsed or
/// trusted answers null, and a null is never read as "no room". A disk that is
/// genuinely full still fails honestly one segment later — FFmpeg's write error
/// ends the process and the restart path stops at `restartLimit` — so the worst
/// outcome of a missing probe is the same outcome as no probe at all, which is why
/// this may decline rather than guess.
abstract final class FfmpegDiskSpace {
  /// The probe a backend uses when the host named none.
  static Future<int?> probe(String directory, {DiskSpaceRunner? run}) async {
    final runner = run ?? Process.run;

    final executable = Platform.isWindows ? 'powershell' : 'df';
    final arguments = Platform.isWindows
        ? powershellArguments(directory)
        : dfArguments(directory);

    if (arguments == null) {
      return null;
    }

    final ProcessResult result;

    try {
      result = await runner(executable, arguments);
    } on Object {
      // No such tool, no permission to run it, a sandbox that refuses: this is a
      // platform we cannot ask, not a disk that is full.
      return null;
    }

    if (result.exitCode != 0) {
      return null;
    }

    final output = result.stdout?.toString() ?? '';

    return Platform.isWindows ? parseWindows(output) : parseDf(output);
  }

  /// `df -kP <dir>` — the POSIX output format, in 1K blocks.
  ///
  /// `-P` matters: without it a long device name wraps onto a second line, and the
  /// wrapped line is what gets read.
  static List<String> dfArguments(String directory) => <String>['-kP', directory];

  /// The PowerShell one-liner that reports bytes free on the volume of [directory].
  ///
  /// Null when the path is not a local drive (a UNC share, or something with no
  /// drive letter to hang a `DriveInfo` on) — that is a platform question we cannot
  /// phrase, not a disk answer.
  ///
  /// The root goes into a *single*-quoted PowerShell string, where a backslash is
  /// already a literal backslash: doubling it here would ask `DriveInfo` about a
  /// path that is not a root.
  static List<String>? powershellArguments(String directory) {
    final root = windowsRoot(directory);

    if (root == null) {
      return null;
    }

    return <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "(New-Object System.IO.DriveInfo('$root')).AvailableFreeSpace",
    ];
  }

  /// The drive root a `DriveInfo` accepts (`C:\Users\me\recordings` → `C:\`), or
  /// null when the path has no drive letter.
  ///
  /// A bare `C:` is not what `DriveInfo` documents as its root form, and asking for
  /// one is how the probe comes back empty on a machine that could answer.
  static String? windowsRoot(String directory) {
    if (directory.startsWith(r'\\')) {
      // A UNC share: no drive letter to ask about.
      return null;
    }

    final match = RegExp('^([A-Za-z]):').firstMatch(directory);

    return match == null ? null : '${match.group(1)}:\\';
  }

  /// Bytes free, read out of `df -kP` output, or null when it is not legible.
  ///
  /// The POSIX layout is `Filesystem 1024-blocks Used Available Capacity Mounted-on`,
  /// so the fourth field of the last line is the answer. "last line" rather than
  /// "first": a header-only or two-line reply is common enough, and a stale first
  /// line is a header.
  static int? parseDf(String output) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length < 2) {
      return null;
    }

    final fields = lines.last.split(RegExp(r'\s+'));

    if (fields.length < 4) {
      return null;
    }

    final availableKb = int.tryParse(fields[3]);

    // A `-` or `*` in that column is how df says "not measurable"; that is a null,
    // not a zero, and zero would refuse a recording that could have run.
    if (availableKb == null || availableKb < 0) {
      return null;
    }

    return availableKb * 1024;
  }

  /// Bytes free, read out of a PowerShell reply, or null when it is not a number.
  static int? parseWindows(String output) {
    final text = output.trim().replaceAll(RegExp(r'[,\s]'), '');

    return int.tryParse(text);
  }
}
