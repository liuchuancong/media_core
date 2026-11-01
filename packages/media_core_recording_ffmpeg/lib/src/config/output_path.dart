import 'package:path/path.dart' as p;

/// The [p.Context] whose separators match [path].
///
/// The style comes from the string the caller was given, not from the host this
/// code runs on. A recording's paths are written by FFmpeg and read back by
/// this package, and both sides have to agree on the separator even when the
/// output directory was built on one platform and is being inspected on another
/// (a desktop host passing a Windows path, a test running on any of them).
p.Context pathContextFor(String path) => path.contains(r'\') ? p.windows : p.posix;

/// Joins [directory] and [name] with the separator [directory] already uses.
String joinOutputPath(String directory, String name) => pathContextFor(directory).join(directory, name);

/// The directory [path] lives in, or the path itself when it has no parent.
String outputDirectoryOf(String path) {
  final parent = pathContextFor(path).dirname(path);

  return parent.isEmpty ? '.' : parent;
}

/// The file-name prefix of attempt [attempt] of a recording whose first attempt
/// was given [basePrefix].
///
/// One attempt, one prefix: `-n` means a re-open that reused the first
/// attempt's names would refuse to run, or would overwrite the list that says
/// where the earlier segments are. The first attempt keeps the plain names so a
/// recording that never dropped its stream is named exactly as it was before
/// re-opening existed.
String attemptFilePrefix(String basePrefix, int attempt) => attempt == 0 ? basePrefix : '${basePrefix}_r$attempt';

/// The prefix the segments named by the journal [journalPath] were written
/// under, given journals are written as `<prefix><journalSuffix>`.
///
/// Read back from the name rather than carried alongside it, so a scan for the
/// segments a journal never listed cannot disagree with the attempt that wrote
/// either file.
String journalFilePrefix(String journalPath, String journalSuffix) {
  final name = pathContextFor(journalPath).basename(journalPath);

  return name.endsWith(journalSuffix) ? name.substring(0, name.length - journalSuffix.length) : name;
}
