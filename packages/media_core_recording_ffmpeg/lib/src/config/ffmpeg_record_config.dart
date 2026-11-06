import 'package:media_core_recording_ffmpeg/src/ffmpeg/ffmpeg_record_arguments.dart';
import 'package:media_core_recording_ffmpeg/src/ffmpeg/ffmpeg_record_container.dart';

/// The journal suffix [FfmpegRecordConfig] writes by default.
///
/// Named because a reader holding only a recording's manifest on disk — the
/// remuxer, or whoever wonders what a folder contains — has to strip exactly
/// this to recover the prefix the segments were named from, and a second
/// literal is how the two sides stop agreeing.
const String kFfmpegDefaultJournalSuffix = '.clock-v1.csv';

/// Tunables for an FFmpeg recording.
///
/// The defaults are the ones the reference implementation settled on after
/// watching real streams fail in specific ways; each value below says which
/// failure it exists for, because the numbers themselves are not self-evident.
final class FfmpegRecordConfig {
  /// Creates a recording configuration; every field defaults to the value the reference
  /// implementation settled on after watching real streams fail.
  const FfmpegRecordConfig({
    this.segmentTime = 300,
    this.rwTimeout = 15,
    this.proxy,
    this.caFile,
    this.tlsVerify = true,
    this.analyzeDuration = const Duration(seconds: 20),
    this.probeSizeBytes = 10 * 1024 * 1024,
    this.extensionPicky = true,
    this.threadQueueSize = 2048,
    this.preferBestStream = true,
    this.container = FfmpegRecordContainer.mpegTs,
    this.filePrefix,
    this.jobLabel,
    this.includeTimestampPrefix = true,
    this.subdirectoryPerRecording = false,
    this.writeManifest = true,
    this.segmentSuffix,
    this.journalSuffix = kFfmpegDefaultJournalSuffix,
    this.verifyOutput = true,
    this.verifyPlayability = true,
    this.restartLimit = 3,
    this.healthyAfter = const Duration(minutes: 1),
    this.restartBackoff = const Duration(seconds: 3),
    this.restartBackoffMax = const Duration(minutes: 1),
    this.freshAddressBackoff = const Duration(seconds: 2),
    this.freshAddressBackoffMax = const Duration(seconds: 15),
    this.stallTimeout = const Duration(seconds: 30),
    this.diskWatermarkBytes = 200 * 1024 * 1024,
    this.keepAlive = true,
    this.keepAliveTitle,
    this.keepAliveIcon,
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
  /// recording ends — whatever ends it, including a failure. The notification
  /// permission is asked for by the platform package on first use, so a host
  /// needs to do nothing; declining it hides the notification but keeps the
  /// wake lock.
  ///
  /// Turn it off for a recording that is expected to finish in seconds, or in a
  /// host that already holds a session for the same job.
  final bool keepAlive;

  /// Title of the notification shown while [keepAlive] holds the process.
  ///
  /// Null uses a neutral "Recording". The body is the file prefix plus the
  /// elapsed time and bytes written, which is what a user needs to recognise the
  /// job and see that it is moving.
  final String? keepAliveTitle;

  /// Name of a drawable in the host app's `res/drawable` (or `res/mipmap`) for
  /// the notification's icon.
  ///
  /// Null uses the glyph the platform package ships for a recording. A name that
  /// does not resolve falls back to that glyph, so a missing asset leaves a
  /// plain notification rather than a broken one.
  final String? keepAliveIcon;

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

  /// HTTP proxy the input is opened through, as `http://host:port`.
  ///
  /// A host that already routes its player through a proxy must route the
  /// recording the same way, or the account's address resolves while the
  /// capture does not. FFmpeg's HTTP protocol option is used, so this covers
  /// both `http://` and `https://` inputs; it has no SOCKS or PAC support.
  final String? proxy;

  /// PEM bundle of trusted certificate authorities.
  ///
  /// FFmpeg's OpenSSL build keeps a compile-time CA path that does not exist
  /// on a phone, so an HTTPS input without this file fails verification even
  /// when the server uses a public CA. A host that ships a bundle passes its
  /// path here; null keeps FFmpeg's own defaults.
  final String? caFile;

  /// Whether an HTTPS input's certificate chain and host name are verified.
  ///
  /// Leave this on. Turning it off accepts a self-signed or intercepted
  /// certificate, which is the only way to record through a proxy that
  /// terminates TLS without installing its CA, and it also removes the
  /// protection against a real interception.
  final bool tlsVerify;

  /// How long FFmpeg analyses the input before it starts writing.
  ///
  /// A live HLS playlist can take several segments before its codecs and
  /// timestamps are unambiguous; five seconds cut some slow CDNs short, so the
  /// default is the twenty seconds the reference settled on.
  final Duration analyzeDuration;

  /// How many bytes FFmpeg probes for the same reason.
  final int probeSizeBytes;

  /// Whether FFmpeg's strict HLS extension/container check stays on.
  ///
  /// A few HLS streams declare a segment extension the container does not
  /// match (CHZZK is the known one) and only open with `-extension_picky 0`.
  /// The host turns it off for those platforms rather than for every stream.
  final bool extensionPicky;

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

  /// Prefix for the recording's files.
  ///
  /// Room titles reach this from the network, so it is validated rather than
  /// trusted: see [FfmpegRecordArguments.safeFilePrefix]. Null (or a value that
  /// sanitises to nothing) takes the generated name described by
  /// [includeTimestampPrefix].
  final String? filePrefix;

  /// A human label for job reporting — the body of a finished recording's
  /// notification — when [filePrefix] is not one.
  ///
  /// The prefix is chosen for the filesystem and for FFmpeg's path handling: an
  /// ASCII stem the host renames afterwards, which reads as
  /// `rec_20261031_120000_000` in a toast. This is the same recording under the
  /// name a person recognises — the room — while the files keep the prefix.
  final String? jobLabel;

  /// Whether the generated prefix carries a timestamp.
  ///
  /// True gives `20261013_182232_915`, which is what a host recording several
  /// rooms into one directory needs in order to tell two takes of the same room
  /// apart. False gives `recording`, which is what a host that already keeps one
  /// directory per recording (see [subdirectoryPerRecording]) wants: the
  /// directory says when, the file says what.
  final bool includeTimestampPrefix;

  /// The container each segment is written into.
  ///
  /// See [FfmpegRecordContainer]: both options are per-segment playable and
  /// survive a kill, which is the requirement a live recording has and a plain
  /// MP4 does not meet.
  final FfmpegRecordContainer container;

  /// Whether one recording gets its own directory under the output directory.
  ///
  /// Off by default because it moves where files land for a host that already
  /// knows the flat layout. On, a long-running host's recordings stay browsable
  /// (one folder per take, prefix plus segments plus journal inside) and the
  /// prefix can drop its timestamp ([includeTimestampPrefix]).
  final bool subdirectoryPerRecording;

  /// Whether a recording writes the small JSON file that says what it was.
  ///
  /// See `FfmpegRecordingManifest`: a TS segment carries no creation date, and a
  /// re-muxed file carries the re-mux's date rather than the recording's, so the
  /// wall-clock start, the container and the list of attempt journals have to be
  /// written somewhere by whoever knows them. Off only for a host that keeps that
  /// record in its own database.
  final bool writeManifest;

  /// Suffix of the segment files, or null for the container's own.
  ///
  /// The profile is in the default so a recording from older clock semantics is
  /// never mistaken for this one and merged with it; see
  /// `FfmpegRecordContainer.segmentSuffix`.
  final String? segmentSuffix;

  /// The suffix the next segment is actually written with.
  String get resolvedSegmentSuffix => segmentSuffix ?? container.segmentSuffix;

  /// Suffix of the segment journal.
  final String journalSuffix;

  /// Whether a finished recording's output is checked before it is reported.
  ///
  /// An FFmpeg exit code says the process ended, not that anything was captured,
  /// so `stop()` would otherwise report success for a recording that wrote no
  /// segment. With this on, the journal is read back and the segments it names
  /// are sized on disk, and a recording with nothing usable in it is reported as
  /// a failure instead. Turn it off only for a host that does its own checking
  /// and cannot afford the extra file I/O.
  final bool verifyOutput;

  /// Whether the checked output is also opened by FFprobe.
  ///
  /// A segment can be the right size and still not decode — a child file whose
  /// header was never flushed looks identical to a captured one in a directory
  /// listing. Two FFprobe calls (first and last segment) answer that. It costs a
  /// native call on the way out of every recording, so a host recording on a
  /// device where FFprobe is not available turns this off and keeps the
  /// filesystem check.
  final bool verifyPlayability;

  /// How many times in a row a process that died on its own is re-opened.
  ///
  /// A live stream drops: the CDN rotates a segment, the room's encoder
  /// restarts, and FFmpeg exits with a code that says nothing about whether the
  /// input will come back. Re-opening it is what keeps a two-hour recording, so
  /// this is not a retry of a *request* but of a *source*.
  ///
  /// It counts consecutive failures that did not reach [healthyAfter]; a run
  /// longer than that is treated as the source being fine and the drop being
  /// incidental, so it resets the count and a recording that survives a daily
  /// outage of one drop an hour keeps going. What it stops is the loop that
  /// cannot work: an expired signed URL fails in under a second, and three
  /// attempts at a growing delay is the honest end of that.
  ///
  /// `0` never restarts — a dropped stream then ends the recording, which is
  /// what a host that only records on user action wants.
  final int restartLimit;

  /// How long a run must hold before its failure is considered unrelated.
  ///
  /// See [restartLimit]: this is the line between "the source dropped again" and
  /// "the source never worked".
  final Duration healthyAfter;

  /// Base delay before a restart; grows by doubling with jitter up to
  /// [restartBackoffMax].
  final Duration restartBackoff;

  /// Base delay of the fast lane: an end the process's own words blame on
  /// the address (a refused grant, an input that ran out) is a room that is
  /// likely still live and only needs a fresh signed URL, so the retry
  /// waits this long — not the plain [restartBackoff].
  final Duration freshAddressBackoff;

  /// Ceiling of the fast lane's backoff.
  final Duration freshAddressBackoffMax;

  /// Ceiling of the restart backoff.
  ///
  /// A minute, because a room that is closed is not opened by retrying every
  /// three seconds, and a host that wants to wait longer should poll the room's
  /// own API rather than the stream.
  final Duration restartBackoffMax;

  /// How long without any progress before the input is called dead.
  ///
  /// FFmpeg's own `-rw_timeout` bounds a read that never returns, but a stream
  /// that keeps delivering something unreadable — an HLS playlist refreshing with
  /// no new segment, an RTMP connection that reports bytes and no media time —
  /// advances nothing and never trips it. This is measured on wall clock between
  /// statistics reports, and tripping it ends the process so the restart path
  /// takes over. `Duration.zero` disables the watchdog.
  final Duration stallTimeout;

  /// Free space a recording directory must have before work starts there.
  ///
  /// Only consulted when the backend was given a `diskSpace` probe, because asking
  /// means running a platform tool (`df -kP`, or PowerShell's `DriveInfo`) on the
  /// path that starts a recording — the same reason the backend's `executor` is
  /// injected rather than constructed. `FfmpegDiskSpace.probe` is that one-line
  /// answer for a host that wants the check; `example` passes it. A probe that cannot
  /// answer is read as unknown, never as "no room".
  ///
  /// A full disk still fails honestly with no probe at all (FFmpeg's write error ends
  /// the process, and restarting onto the same full disk stops at [restartLimit]),
  /// but "there was no room" said before the first segment is a better report than
  /// "an FFmpeg exit code" after the last one. Set this to `0` to skip the question.
  final int diskWatermarkBytes;

  /// The same configuration with the given fields replaced.
  FfmpegRecordConfig copyWith({
    int? segmentTime,
    int? rwTimeout,
    String? proxy,
    String? caFile,
    bool? tlsVerify,
    Duration? analyzeDuration,
    int? probeSizeBytes,
    bool? extensionPicky,
    int? threadQueueSize,
    bool? preferBestStream,
    FfmpegRecordContainer? container,
    String? filePrefix,
    String? jobLabel,
    bool? includeTimestampPrefix,
    bool? subdirectoryPerRecording,
    bool? writeManifest,
    String? segmentSuffix,
    String? journalSuffix,
    bool? verifyOutput,
    bool? verifyPlayability,
    int? restartLimit,
    Duration? healthyAfter,
    Duration? restartBackoff,
    Duration? restartBackoffMax,
    Duration? freshAddressBackoff,
    Duration? freshAddressBackoffMax,
    Duration? stallTimeout,
    int? diskWatermarkBytes,
    bool? keepAlive,
    String? keepAliveTitle,
    String? keepAliveIcon,
  }) {
    return FfmpegRecordConfig(
      segmentTime: segmentTime ?? this.segmentTime,
      rwTimeout: rwTimeout ?? this.rwTimeout,
      proxy: proxy ?? this.proxy,
      caFile: caFile ?? this.caFile,
      tlsVerify: tlsVerify ?? this.tlsVerify,
      analyzeDuration: analyzeDuration ?? this.analyzeDuration,
      probeSizeBytes: probeSizeBytes ?? this.probeSizeBytes,
      extensionPicky: extensionPicky ?? this.extensionPicky,
      threadQueueSize: threadQueueSize ?? this.threadQueueSize,
      preferBestStream: preferBestStream ?? this.preferBestStream,
      container: container ?? this.container,
      filePrefix: filePrefix ?? this.filePrefix,
      jobLabel: jobLabel ?? this.jobLabel,
      includeTimestampPrefix: includeTimestampPrefix ?? this.includeTimestampPrefix,
      subdirectoryPerRecording: subdirectoryPerRecording ?? this.subdirectoryPerRecording,
      writeManifest: writeManifest ?? this.writeManifest,
      segmentSuffix: segmentSuffix ?? this.segmentSuffix,
      journalSuffix: journalSuffix ?? this.journalSuffix,
      verifyOutput: verifyOutput ?? this.verifyOutput,
      verifyPlayability: verifyPlayability ?? this.verifyPlayability,
      restartLimit: restartLimit ?? this.restartLimit,
      healthyAfter: healthyAfter ?? this.healthyAfter,
      restartBackoff: restartBackoff ?? this.restartBackoff,
      restartBackoffMax: restartBackoffMax ?? this.restartBackoffMax,
      freshAddressBackoff: freshAddressBackoff ?? this.freshAddressBackoff,
      freshAddressBackoffMax: freshAddressBackoffMax ?? this.freshAddressBackoffMax,
      stallTimeout: stallTimeout ?? this.stallTimeout,
      diskWatermarkBytes: diskWatermarkBytes ?? this.diskWatermarkBytes,
      keepAlive: keepAlive ?? this.keepAlive,
      keepAliveTitle: keepAliveTitle ?? this.keepAliveTitle,
      keepAliveIcon: keepAliveIcon ?? this.keepAliveIcon,
    );
  }
}
