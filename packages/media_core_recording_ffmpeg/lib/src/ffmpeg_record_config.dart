/// Tunables for an FFmpeg recording.
///
/// The defaults are the ones the reference implementation settled on after
/// watching real streams fail in specific ways; each value below says which
/// failure it exists for, because the numbers themselves are not self-evident.
final class FfmpegRecordConfig {
  const FfmpegRecordConfig({
    this.segmentTime = 300,
    this.rwTimeout = 15,
    this.threadQueueSize = 2048,
    this.preferBestStream = true,
    this.filePrefix,
    this.includeTimestampPrefix = true,
    this.segmentSuffix = '.clock-v1.ts',
    this.journalSuffix = '.clock-v1.csv',
    this.keepAlive = true,
    this.keepAliveTitle,
  });

  /// Caller-accepted defaults.
  static const FfmpegRecordConfig defaults = FfmpegRecordConfig();

  /// Whether the process is kept alive while a recording runs.
  ///
  /// A recording is work the user asked for and then stopped watching, and a
  /// phone that freezes the process when the screen goes off ends it with an
  /// FFmpeg exit code that says nothing. With this on, the recording holds a
  /// background-execution session (foreground service + notification and a wake
  /// lock on Android, a sleep assertion on desktop), released when the
  /// recording ends — whatever ends it, including a failure.
  ///
  /// Turn it off for a recording that is expected to finish in seconds, or in a
  /// host that already holds a session for the same job.
  final bool keepAlive;

  /// Title of the notification shown while [keepAlive] holds the process.
  ///
  /// Null uses a neutral "Recording". The body is the file prefix, which is
  /// usually the room or programme name the host chose — that is what a user
  /// needs to recognise, not a timestamp.
  final String? keepAliveTitle;

  /// Length of each segment, in seconds.
  ///
  /// Segments bound the damage of a crash: the completed ones are playable
  /// files, and the journal says how they join. Clamped to 10..86400 because a
  /// segment shorter than ten seconds multiplies container overhead across a
  /// long recording, and one longer than a day is not a segment.
  final int segmentTime;

  /// Read/write timeout for the input, in seconds.
  ///
  /// A live stream that stops delivering must fail the read rather than hang
  /// the recording forever; fifteen seconds is long enough for a slow CDN
  /// segment and short enough to notice.
  final int rwTimeout;

  /// Input packet queue size.
  ///
  /// Recording favours completeness over latency, so this is much larger than
  /// a player would use: a burst from an HLS playlist would otherwise drop
  /// packets while the disk catches up.
  final int threadQueueSize;

  /// Whether to map the first video and audio stream, or every stream.
  ///
  /// `preferBestStream: true` records the first video and first audio stream
  /// and tolerates their absence (`?`), which is what a live room needs: a
  /// stream list with several renditions must not turn into a multi-track file.
  final bool preferBestStream;

  /// Prefix for the recording's files. Generated from the timestamp when null.
  final String? filePrefix;

  /// Whether a timestamp is prepended when no prefix is given.
  final bool includeTimestampPrefix;

  /// Suffix of the segment files.
  ///
  /// The profile is in every name so a recording from older clock semantics is
  /// never mistaken for this one and merged with it.
  final String segmentSuffix;

  /// Suffix of the segment journal.
  final String journalSuffix;

  FfmpegRecordConfig copyWith({
    int? segmentTime,
    int? rwTimeout,
    int? threadQueueSize,
    bool? preferBestStream,
    String? filePrefix,
    bool? includeTimestampPrefix,
    String? segmentSuffix,
    String? journalSuffix,
  }) {
    return FfmpegRecordConfig(
      segmentTime: segmentTime ?? this.segmentTime,
      rwTimeout: rwTimeout ?? this.rwTimeout,
      threadQueueSize: threadQueueSize ?? this.threadQueueSize,
      preferBestStream: preferBestStream ?? this.preferBestStream,
      filePrefix: filePrefix ?? this.filePrefix,
      includeTimestampPrefix: includeTimestampPrefix ?? this.includeTimestampPrefix,
      segmentSuffix: segmentSuffix ?? this.segmentSuffix,
      journalSuffix: journalSuffix ?? this.journalSuffix,
    );
  }
}
