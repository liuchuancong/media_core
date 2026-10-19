/// What a background job says to the viewer, at either end of its life.
///
/// A download and a recording both end the same way for the user — one line that
/// says whether there is something to open — and neither package knows anything
/// about the platform that draws it. The contract lives here so the job packages
/// can report without depending on a notification implementation, and the
/// notification package can register itself without either one knowing about the
/// other. This is the same split `PlayerKernel.audioDriverFactory` uses for the
/// system media surfaces.
library;

/// Which kind of background work this is.
enum MediaJobKind {
  /// A file download.
  download,

  /// A recording.
  recording,
}

/// The fact that a job began, with nothing about how it will end.
///
/// A start is its own record rather than an [MediaJobOutcome] whose phase says
/// `started`, because a reporter that reads an outcome's `success` would announce a
/// job that has merely begun as one that finished — and a value class carrying four
/// fields a reader must first be told to ignore is a contract that invites the wrong
/// reading.
final class MediaJobStart {
  /// Says that the named job began.
  const MediaJobStart({required this.kind, required this.label});

  /// Which kind of job began.
  final MediaJobKind kind;

  /// What to call this job in the line the viewer reads. The same words as the
  /// verdict's [MediaJobOutcome.label], so a start and a result are recognisably
  /// about the same work.
  final String label;

  @override
  String toString() => 'MediaJobStart(${kind.name}, $label)';
}

/// One finished job, in the words a job knows about itself.
///
/// [label] is what the viewer would recognise — a room title, a file name — not an
/// internal id, because this text is the only thing the notification has to say.
final class MediaJobOutcome {
  /// Creates an outcome.
  const MediaJobOutcome({
    required this.kind,
    required this.label,
    required this.success,
    this.bytesWritten,
    this.elapsed,
    this.path,
    this.error,
  });

  /// Which kind of job ended.
  final MediaJobKind kind;

  /// What to call this job in the line the viewer reads.
  final String label;

  /// Whether there is something to show the user.
  ///
  /// A job reports its own verdict, so a recording whose files hold nothing counts
  /// as a failure even when its process exited cleanly.
  final bool success;

  /// Bytes the job left on disk, when it knows.
  final int? bytesWritten;

  /// How long the job ran, when it knows.
  ///
  /// For a recording this is the media time actually written, not the wall clock:
  /// a stream that dropped for ten minutes is a ten-minutes-shorter file, and that
  /// is the number the viewer opens the file to check.
  final Duration? elapsed;

  /// Where the job's output landed, when there is one file to point at.
  ///
  /// A notification that carries it can open the file on tap; a recording that
  /// produced several leaves this null and names the folder in its own words.
  final String? path;

  /// Why it failed, when it did.
  final Object? error;

  @override
  String toString() =>
      'MediaJobOutcome(${kind.name}, $label, ${success ? 'ok' : 'failed'}'
      '${bytesWritten == null ? '' : ', ${bytesWritten}B'}'
      '${elapsed == null ? '' : ', ${elapsed!.inSeconds}s'}'
      '${error == null ? '' : ', $error'})';
}

/// The layer that turns what a job does into something the user can see.
///
/// Implementations must not throw and must not make the job wait: a notification
/// is how the user finds out what happened, not the thing that happened.
abstract interface class MediaJobReporter {
  /// Hands [start] to whoever says a job began.
  ///
  /// Separate from [report] so that saying so is a choice: a reporter installed by
  /// a host that only wants results keeps wanting only results, and nothing has to
  /// be told to ignore a verdict field it should not have read.
  void reportStart(MediaJobStart start);

  /// Hands [outcome] to whoever draws it.
  void report(MediaJobOutcome outcome);
}

/// The reporter the job packages hand their outcomes to.
///
/// Null until a capability package installs one, which is what lets a host record
/// or download without linking a notification plugin — and what lets a host that
/// already draws its own progress say nothing here instead of silencing a
/// dependency it did not ask for.
abstract final class MediaJobReporting {
  /// The installed reporter, or null when nobody wants to know.
  static MediaJobReporter? reporter;

  /// Forgets the reporter. Used by a host tearing a process down, and by tests.
  static void reset() => reporter = null;
}
