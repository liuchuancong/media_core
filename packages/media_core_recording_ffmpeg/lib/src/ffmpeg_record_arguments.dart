import 'package:media_core/media_core.dart' show UriUtils;

import 'ffmpeg_record_config.dart';

/// Builds the FFmpeg argument lists a recording uses.
///
/// Ported from the reference implementation, where every option below was added
/// because a real stream failed without it. The comments are kept because they
/// say *which* failure each flag prevents — the flags alone look arbitrary.
///
/// Two shapes are built:
///
/// - [recordArguments]: segmented MPEG-TS capture straight to files, with a CSV
///   journal that lets the segments be joined later.
/// - [audioRelayArguments]: an audio-only MPEG-TS relay on localhost, for hosts
///   that need a single audio stream they can subscribe to (for example to feed
///   a media player's audio pipeline from the same input).
///
/// Arguments are returned as a list, never as a shell string: FFmpegKit takes an
/// argument list directly, and formatting one into a command line would
/// re-introduce quoting bugs for URLs, headers and paths containing spaces.
/// [formatArguments] exists for logs and tests only.
final class FfmpegRecordArguments {
  const FfmpegRecordArguments({this.config = FfmpegRecordConfig.defaults});

  /// Tunables.
  final FfmpegRecordConfig config;

  /// Protocols FFmpeg is allowed to open.
  ///
  /// Deliberately explicit: a live URL is attacker-influenced input, and the
  /// whitelist is what keeps it from being read as a `file:` or `data:` URI.
  static const String protocolWhitelist =
      'httpproxy,udp,rtp,rtsp,rtmp,rtmps,srt,tcp,tls,data,file,http,https,crypto';

  /// Segmented recording arguments.
  ///
  /// [segmentPattern] and [journalPath] come from the caller so the naming and
  /// the journal location stay the host's decision, and [outputDirectory] is
  /// where the pattern is resolved.
  List<String> recordArguments({
    required String url,
    required String outputDirectory,
    required String segmentPattern,
    required String journalPath,
    Map<String, String>? headers,
    String? filePrefix,
  }) {
    final normalizedHeaders = normalizeHeaders(headers);
    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = buildHeader(normalizedHeaders);
    final prefix = safeFilePrefix(filePrefix ?? config.filePrefix ?? timestampPrefix(DateTime.now()));
    final separator = outputDirectory.endsWith('/') || outputDirectory.endsWith(r'\') ? '' : _separator(outputDirectory);

    final arguments = <String>[
      // Keep no-overwrite intent: segment muxers open child outputs separately,
      // so `-n` is what stops a restart from silently appending to an old file.
      '-n',
      '-hide_banner',
      '-loglevel',
      'info',
      // Recording favours complete stream discovery over playback latency.
      '-analyzeduration',
      '5000000',
      '-probesize',
      '5000000',
      '-fflags',
      '+genpts+discardcorrupt',
      '-protocol_whitelist',
      protocolWhitelist,
      ...inputProtocolOptions(url),
      '-thread_queue_size',
      config.threadQueueSize.clamp(64, 65536).toString(),
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],
      if (headerString.isNotEmpty) ...['-headers', headerString],
      // Preserve the source cadence while correcting only discontinuities.
      // `use_wallclock_as_timestamps` is deliberately avoided: HLS/HTTP
      // downloads packets in bursts, so arrival time collapses many frames into
      // near-identical timestamps and produces visibly uneven playback.
      // FFmpeg applies dts_delta_threshold to discontinuity-aware inputs such
      // as HLS/MPEG-TS and dts_error_threshold to formats such as live FLV;
      // together with +genpts this removes a CDN timestamp jump without
      // replacing every valid source timestamp.
      if (usesNetworkInput(url)) ...['-dts_delta_threshold', '2', '-dts_error_threshold', '2'],
      '-i',
      url,
      // Optional mappings support audio-only rooms and temporarily missing
      // video tracks without selecting metadata or data streams.
      '-map',
      config.preferBestStream ? '0:v:0?' : '0:v?',
      '-map',
      config.preferBestStream ? '0:a:0?' : '0:a?',
      '-c',
      'copy',
      '-avoid_negative_ts',
      'make_non_negative',
      '-f',
      'segment',
      '-segment_format',
      'mpegts',
      // Commit complete packets in each child TS while running, rather than
      // leaving a partial 512 KiB AVIO prefix when cancellation prevents the
      // trailer from flushing.
      //
      // Only the outer muxer normalizes the clock: a second per-child shift
      // breaks reconstruction from the segment list's reference timestamps.
      // Zero child mux delay keeps each timestamped audio packet's anchor, and
      // the 1.4 s offset retains MPEG-TS's former preroll — without it, concat's
      // inpoint 0 discards leading negative DTS in later segments.
      '-segment_format_options',
      'flush_packets=1:avoid_negative_ts=disabled:max_delay=0:output_ts_offset=1.4',
      '-segment_list',
      journalPath,
      '-segment_list_type',
      'csv',
      '-segment_time',
      config.segmentTime.clamp(10, 86400).toString(),
      '-segment_start_number',
      '0',
      '-reset_timestamps',
      '1',
      '$outputDirectory$separator$segmentPattern',
    ];

    // The prefix is part of the path the caller passed, so the recorded name is
    // authoritative here; it is validated to keep a hostile room title out of
    // the filesystem.
    assert(prefix.isNotEmpty);

    return List<String>.unmodifiable(arguments);
  }

  /// Audio-only relay arguments: reads [url] and serves MPEG-TS on [port].
  List<String> audioRelayArguments({
    required String url,
    required int port,
    int? rwTimeout,
    Map<String, String>? headers,
  }) {
    final normalizedHeaders = normalizeHeaders(headers);
    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = buildHeader(normalizedHeaders);

    final arguments = <String>[
      '-hide_banner',
      '-loglevel',
      'info',
      '-protocol_whitelist',
      protocolWhitelist,
      ...inputProtocolOptions(url, rwTimeout: rwTimeout),
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],
      if (headerString.isNotEmpty) ...['-headers', headerString],
      '-i',
      url,
      '-map',
      '0:a:0',
      '-vn',
      '-c:a',
      'copy',
      '-listen',
      '1',
      '-f',
      'mpegts',
      'http://127.0.0.1:$port/live.ts',
    ];

    return List<String>.unmodifiable(arguments);
  }

  /// Per-scheme input options.
  ///
  /// Reconnection is only armed for HTTP(S): a signed URL that expired cannot
  /// be fixed by retrying it, so only server-side failures are retried inside
  /// FFmpeg and everything else surfaces to the caller, which is the only one
  /// that can fetch a fresh URL.
  List<String> inputProtocolOptions(String rawUrl, {int? rwTimeout}) {
    // Scheme parsing and the network check come from the core's URI helpers, so
    // this package cannot drift from the framework's idea of what a network
    // input is.
    final scheme = UriUtils.scheme(rawUrl)?.toLowerCase() ?? '';
    final seconds = (rwTimeout ?? config.rwTimeout).clamp(1, 3600);
    final timeoutMicros = (seconds * 1000000).clamp(1, 2147483647).toString();
    final options = <String>[];

    if (scheme == 'http' || scheme == 'https') {
      options.addAll([
        '-reconnect',
        '1',
        '-reconnect_streamed',
        '1',
        '-reconnect_on_network_error',
        '1',
        '-reconnect_on_http_error',
        '5xx',
        '-reconnect_delay_max',
        '5',
        '-rw_timeout',
        timeoutMicros,
      ]);
    } else if (scheme == 'rtsp') {
      options.addAll(['-rtsp_transport', 'tcp', '-rw_timeout', timeoutMicros]);
    } else if (scheme == 'udp' || scheme == 'rtp') {
      options.addAll(['-fifo_size', '5000000', '-overrun_nonfatal', '1']);
    } else if (scheme != 'file' && scheme.isNotEmpty) {
      options.addAll(['-rw_timeout', timeoutMicros]);
    }

    return options;
  }

  /// Whether [rawUrl] is a network input that needs discontinuity handling.
  static bool usesNetworkInput(String rawUrl) {
    if (UriUtils.isNetwork(rawUrl)) {
      return true;
    }
    final scheme = UriUtils.scheme(rawUrl)?.toLowerCase() ?? '';
    return const <String>{'rtmps', 'rtp', 'srt'}.contains(scheme);
  }

  /// Normalizes HTTP headers for FFmpeg.
  ///
  /// Header names are lower-cased and restricted to the token characters FFmpeg
  /// accepts, and values lose CR/LF/NUL: a header value is attacker-influenced
  /// input reaching a native parser, and a newline in one would inject another
  /// header.
  static Map<String, String> normalizeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return <String, String>{};
    }
    final normalized = <String, String>{};
    final validName = RegExp(r'^[A-Za-z0-9-]+$');
    for (final entry in headers.entries) {
      final name = entry.key.trim().toLowerCase();
      final value = entry.value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();
      if (name.isEmpty || value.isEmpty || !validName.hasMatch(name)) {
        continue;
      }
      normalized[name] = value;
    }
    return normalized;
  }

  /// Joins normalized headers into FFmpeg's `Name: value\r\n` block.
  static String buildHeader(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '';
    }
    return '${headers.entries.map((entry) => '${entry.key}: ${entry.value}').join('\r\n')}\r\n';
  }

  /// Makes [value] safe to use as a file name.
  ///
  /// Room titles reach this from the network; everything outside
  /// `[A-Za-z0-9_-]` collapses to `_` so a title can never escape the recording
  /// directory.
  static String safeFilePrefix(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_');
    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? timestampPrefix(DateTime.now()) : trimmed;
  }

  /// Timestamp used when no usable prefix is supplied.
  static String timestampPrefix(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}_'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Quotes one argument for display.
  static String quoteArgument(String value) {
    if (value.isEmpty) {
      return '""';
    }
    if (!value.contains(RegExp(r'''[\s"'\\$`]'''))) {
      return value;
    }
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  /// Human-readable command for logs and tests. Never passed to FFmpeg.
  static String formatArguments(Iterable<String> arguments) => arguments.map(quoteArgument).join(' ');

  static String _separator(String outputDirectory) {
    // Windows accepts both separators, POSIX only `/`; `Platform` is avoided so
    // this stays callable from a test on any host.
    return outputDirectory.contains('\\') ? '\\' : '/';
  }
}
