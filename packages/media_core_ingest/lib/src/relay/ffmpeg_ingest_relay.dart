import 'dart:async';
import 'dart:io';

import 'package:media_core_ingest/src/relay/ingest_ffmpeg.dart';
import 'package:media_core_logging/media_core_logging.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// Remuxes an upstream with FFmpeg into a rolling loopback HLS tree.
///
/// Some sources are outside what the player's own FFmpeg can parse - codec-id-12
/// HEVC FLV is the observed case - and some swap their signed URL underneath a
/// playing stream. Both are "give FFmpeg one job and let the player read a plain
/// local playlist" problems, which is what this relay is: one process, one
/// directory, one port, a rolling `index.m3u8`.
///
/// The player only ever sees `http://127.0.0.1:<port>/index.m3u8`; the playlist's
/// own segment names are relative to that URL, so nothing has to be rewritten.
///
/// A signed source also expires under a running FFmpeg, and FFmpeg cannot swap
/// its input mid flight. [renewAddress] continues the relay on a fresh address
/// with a second round in the same directory: the second round first proves the
/// new address by publishing a join playlist, then the first round is stopped
/// and requests for `index.m3u8` are served the join's bytes under the old
/// name - the player's URL never changes. The join is a new encode round, so
/// its timestamps restart; the player reads it as a fresh window, and segments
/// of earlier rounds stay on disk until [close].
final class FfmpegIngestRelay {
  FfmpegIngestRelay._({
    required Uri source,
    required HttpServer server,
    required Directory directory,
    required IngestFfmpegProcess execution,
    required IngestFfmpegStarter startFfmpeg,
    required Duration segmentDuration,
    required int playlistSize,
    required bool copyStreams,
    required String? videoCodec,
    required String? audioCodec,
    required Duration startupTimeout,
    required bool dashMerge,
  }) : _source = source,
       _server = server,
       _directory = directory,
       _execution = execution,
       _startFfmpeg = startFfmpeg,
       _segmentDuration = segmentDuration,
       _playlistSize = playlistSize,
       _copyStreams = copyStreams,
       _videoCodec = videoCodec,
       _audioCodec = audioCodec,
       _startupTimeout = startupTimeout,
       _dashMerge = dashMerge;

  /// Starts the pipeline and waits for the first playlist.
  ///
  /// FFmpeg writes `index.m3u8` only after it has probed the input, so the wait
  /// doubles as "the source is actually playable"; a timeout or a non-zero exit
  /// before the first playlist throws, and the caller can fall back to a direct
  /// open instead of showing a black player.
  ///
  /// [startFfmpeg] is the host's own FFmpeg runtime; this package starts no
  /// process by itself.
  static Future<FfmpegIngestRelay> start({
    required Uri source,
    required IngestFfmpegStarter startFfmpeg,
    Map<String, String> headers = const <String, String>{},
    Duration segmentDuration = const Duration(seconds: 2),
    int playlistSize = 4,
    bool copyStreams = true,
    String? videoCodec,
    String? audioCodec,
    Duration startupTimeout = const Duration(seconds: 12),
  }) async {
    final directory = await Directory.systemTemp.createTemp('media_core_ingest_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final playlistPath = '${directory.path}${Platform.pathSeparator}$ingestPlaylistName';
    IngestFfmpegProcess? execution;
    try {
      execution = await startFfmpeg(
        buildIngestArguments(
          source: source,
          headers: headers,
          outputDirectory: directory.path,
          segmentDuration: segmentDuration,
          playlistSize: playlistSize,
          copyStreams: copyStreams,
          videoCodec: videoCodec,
          audioCodec: audioCodec,
        ),
      );
      final relay = FfmpegIngestRelay._(
        source: source,
        server: server,
        directory: directory,
        execution: execution,
        startFfmpeg: startFfmpeg,
        segmentDuration: segmentDuration,
        playlistSize: playlistSize,
        copyStreams: copyStreams,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        startupTimeout: startupTimeout,
        dashMerge: false,
      );
      // One subscription records the exit; `exitCode` is only readable once.
      final exitWatch = relay._adopt(execution);
      server.listen(
        relay._handle,
        onError: (Object error) {
          _log.warning('ingest loopback server error', error: error, fields: <String, Object?>{'source': source});
        },
        cancelOnError: false,
      );
      await _awaitPublished(File(playlistPath), exitWatch, startupTimeout);
      _log.info(
        'ingest relay started',
        fields: <String, Object?>{'source': source, 'port': server.port, 'directory': directory.path},
      );
      return relay;
    } on Object catch (error) {
      _log.error(
        'ingest relay failed to start',
        error: error,
        stackTrace: StackTrace.current,
        fields: <String, Object?>{'source': source},
      );
      await execution?.stop();
      await server.close(force: true);
      await _deleteQuietly(directory);
      rethrow;
    }
  }

  /// Name FFmpeg writes and the player reads.
  static const String ingestPlaylistName = 'index.m3u8';

  /// Name the renewal round writes; served under [ingestPlaylistName] once
  /// the relay cuts over.
  static const String joinPlaylistName = 'join.m3u8';

  static const String _joinSegmentPrefix = 'join';

  /// Starts a DASH merge pipeline: two separate essence URLs (video m4s +
  /// audio m4s) are muxed by FFmpeg into one rolling loopback HLS tree.
  ///
  /// The player only ever sees [inputUri]; the merge is transparent. Both
  /// inputs share [headers] (bilibili DASH gives one Referer for the pair),
  /// but [audioHeaders] overrides for the audio leg when the CDN differs.
  static Future<FfmpegIngestRelay> startDashMerge({
    required Uri videoSource,
    required Uri audioSource,
    required IngestFfmpegStarter startFfmpeg,
    Map<String, String> headers = const <String, String>{},
    Map<String, String>? audioHeaders,
    Duration segmentDuration = const Duration(seconds: 2),
    int playlistSize = 4,
    Duration startupTimeout = const Duration(seconds: 12),
  }) async {
    final directory = await Directory.systemTemp.createTemp('media_core_dash_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final playlistPath = '${directory.path}${Platform.pathSeparator}$ingestPlaylistName';
    IngestFfmpegProcess? execution;
    try {
      execution = await startFfmpeg(
        buildDashMergeArguments(
          videoSource: videoSource,
          audioSource: audioSource,
          headers: headers,
          audioHeaders: audioHeaders,
          outputDirectory: directory.path,
          segmentDuration: segmentDuration,
          playlistSize: playlistSize,
        ),
      );
      final relay = FfmpegIngestRelay._(
        source: videoSource,
        server: server,
        directory: directory,
        execution: execution,
        startFfmpeg: startFfmpeg,
        segmentDuration: segmentDuration,
        playlistSize: playlistSize,
        copyStreams: true,
        videoCodec: null,
        audioCodec: null,
        startupTimeout: startupTimeout,
        dashMerge: true,
      );
      // One subscription records the exit; `exitCode` is only readable once.
      final exitWatch = relay._adopt(execution);
      server.listen(
        relay._handle,
        onError: (Object error) {
          _log.warning(
            'ingest loopback server error',
            error: error,
            fields: <String, Object?>{'videoSource': videoSource},
          );
        },
        cancelOnError: false,
      );
      await _awaitPublished(File(playlistPath), exitWatch, startupTimeout);
      _log.info(
        'DASH merge relay started',
        fields: <String, Object?>{
          'videoSource': videoSource,
          'audioSource': audioSource,
          'port': server.port,
          'directory': directory.path,
        },
      );
      return relay;
    } on Object catch (error) {
      _log.error(
        'DASH merge relay failed to start',
        error: error,
        stackTrace: StackTrace.current,
        fields: <String, Object?>{'videoSource': videoSource, 'audioSource': audioSource},
      );
      await execution?.stop();
      await server.close(force: true);
      await _deleteQuietly(directory);
      rethrow;
    }
  }

  /// Stable argument list, exposed for tests and for hosts that log it.
  static List<String> buildIngestArguments({
    required Uri source,
    required String outputDirectory,
    Map<String, String> headers = const <String, String>{},
    Duration segmentDuration = const Duration(seconds: 2),
    int playlistSize = 4,
    bool copyStreams = true,
    String? videoCodec,
    String? audioCodec,
  }) {
    final separator = Platform.pathSeparator;
    final arguments = <String>[
      '-hide_banner',
      '-loglevel',
      'warning',
      if (headers.isNotEmpty) ...<String>[
        '-headers',
        headers.entries.map((entry) => '${entry.key}: ${entry.value}\r\n').join(),
      ],
      '-i',
      source.toString(),
      if (copyStreams) ...<String>['-c', 'copy'] else ...<String>[
        '-c:v',
        videoCodec ?? 'libx264',
        '-preset',
        'veryfast',
        '-tune',
        'zerolatency',
        '-c:a',
        audioCodec ?? 'aac',
      ],
      // A live rolling window: the player seeks inside it, FFmpeg drops what it
      // has already published.
      '-f',
      'hls',
      '-hls_time',
      (segmentDuration.inMilliseconds / 1000).toStringAsFixed(3),
      '-hls_list_size',
      playlistSize.toString(),
      '-hls_flags',
      'delete_segments+append_list+omit_endlist',
      '-hls_segment_filename',
      '$outputDirectory${separator}segment%05d.ts',
      '$outputDirectory$separator$ingestPlaylistName',
    ];
    return arguments;
  }

  /// DASH merge argument list: two inputs (video m4s + audio m4s), stream-copy
  /// into one rolling HLS tree. Exposed for tests and host logging.
  ///
  /// FFmpeg's `-headers` binds to the *next* `-i`, so each input carries its
  /// own header block. `-map 0:v:0 -map 1:a:0` pins the first video stream
  /// from input 0 and the first audio stream from input 1 — a DASH manifest
  /// can list alternates, and an unmapped merge would silently pick whichever
  /// FFmpeg likes best.
  static List<String> buildDashMergeArguments({
    required Uri videoSource,
    required Uri audioSource,
    required String outputDirectory,
    Map<String, String> headers = const <String, String>{},
    Map<String, String>? audioHeaders,
    Duration segmentDuration = const Duration(seconds: 2),
    int playlistSize = 4,
  }) {
    final separator = Platform.pathSeparator;
    final effectiveAudioHeaders = audioHeaders ?? headers;
    return <String>[
      '-hide_banner',
      '-loglevel',
      'warning',
      if (headers.isNotEmpty) ...<String>['-headers', headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join()],
      '-i',
      videoSource.toString(),
      if (effectiveAudioHeaders.isNotEmpty) ...<String>[
        '-headers',
        effectiveAudioHeaders.entries.map((e) => '${e.key}: ${e.value}\r\n').join(),
      ],
      '-i',
      audioSource.toString(),
      '-c',
      'copy',
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-f',
      'hls',
      '-hls_time',
      (segmentDuration.inMilliseconds / 1000).toStringAsFixed(3),
      '-hls_list_size',
      playlistSize.toString(),
      '-hls_flags',
      'delete_segments+append_list+omit_endlist',
      '-hls_segment_filename',
      '$outputDirectory${separator}segment%05d.ts',
      '$outputDirectory$separator$ingestPlaylistName',
    ];
  }

  /// Renewal-round argument list: one input on the fresh address, writing a
  /// [joinPlaylistName] tree with its own segment prefix next to the running
  /// round's. Exposed for tests and host logging.
  ///
  /// The flags drop `append_list`: the join is a list of its own, not an
  /// extension of the running playlist - two processes must never write one
  /// playlist file, so the relay switches which file it serves instead.
  static List<String> buildJoinArguments({
    required Uri source,
    required String outputDirectory,
    Map<String, String> headers = const <String, String>{},
    Duration segmentDuration = const Duration(seconds: 2),
    int playlistSize = 4,
    bool copyStreams = true,
    String? videoCodec,
    String? audioCodec,
  }) {
    final separator = Platform.pathSeparator;
    return <String>[
      '-hide_banner',
      '-loglevel',
      'warning',
      if (headers.isNotEmpty) ...<String>['-headers', headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join()],
      '-i',
      source.toString(),
      if (copyStreams) ...<String>['-c', 'copy'] else ...<String>[
        '-c:v',
        videoCodec ?? 'libx264',
        '-preset',
        'veryfast',
        '-tune',
        'zerolatency',
        '-c:a',
        audioCodec ?? 'aac',
      ],
      '-f',
      'hls',
      '-hls_time',
      (segmentDuration.inMilliseconds / 1000).toStringAsFixed(3),
      '-hls_list_size',
      playlistSize.toString(),
      '-hls_flags',
      'delete_segments+omit_endlist',
      '-hls_segment_filename',
      '$outputDirectory$separator$_joinSegmentPrefix%05d.ts',
      '$outputDirectory$separator$joinPlaylistName',
    ];
  }

  final HttpServer _server;
  final Directory _directory;
  final IngestFfmpegStarter _startFfmpeg;
  final Duration _segmentDuration;
  final int _playlistSize;
  final bool _copyStreams;
  final String? _videoCodec;
  final String? _audioCodec;
  final Duration _startupTimeout;

  /// A DASH merge carries two inputs; only the single-input rounds renew.
  final bool _dashMerge;
  IngestFfmpegProcess _execution;

  /// The upstream the current round was started for.
  Uri get source => _source;
  Uri _source;
  bool _closed = false;
  bool _exited = false;
  int? _exitCode;
  bool _servingJoin = false;
  Future<bool>? _renewing;

  /// The URL the player opens.
  Uri get inputUri =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _server.port, path: '/$ingestPlaylistName');

  /// Whether FFmpeg has stopped, and with which code.
  bool get hasExited => _exited;

  /// FFmpeg's exit code once it has stopped, or `null` while it runs.
  int? get exitCode => _exitCode;

  /// Subscribes the one [exitCode] read of a round; the flags flip only when
  /// the exited round is still the current one, so a dead first round cannot
  /// mark the relay down after a renewal replaced it. The returned watch is
  /// the spawn site's handle for waiting on a first playlist.
  Completer<int> _adopt(IngestFfmpegProcess execution) {
    final watch = Completer<int>();
    unawaited(
      execution.exitCode.then(
        (code) {
          if (!watch.isCompleted) watch.complete(code);
          if (!identical(_execution, execution)) return;
          _exited = true;
          _exitCode = code;
          _log.info('ingest FFmpeg exited', fields: <String, Object?>{'source': _source, 'exitCode': code});
        },
        onError: (Object error) {
          if (!watch.isCompleted) watch.completeError(error);
          if (!identical(_execution, execution)) return;
          _exited = true;
          _log.warning('ingest FFmpeg died', error: error, fields: <String, Object?>{'source': _source});
        },
      ),
    );
    return watch;
  }

  static Future<void> _awaitPublished(File playlist, Completer<int> exited, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (playlist.existsSync()) return;
      if (exited.isCompleted) {
        final code = await exited.future;
        throw FormatException('FFmpeg ingest stopped (exit $code) before publishing a playlist');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('FFmpeg ingest published no playlist in ${timeout.inSeconds}s', timeout);
  }

  Future<void> _handle(HttpRequest request) async {
    final name = request.uri.pathSegments.isEmpty ? '' : request.uri.pathSegments.last;
    // The playlist is the only dynamic name; everything else must be one of the
    // segments FFmpeg wrote, so a request can never walk out of the directory.
    if (name.isEmpty || name.contains('..') || name.contains('/') || name.contains(r'\')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    // After a renewal the join round's playlist is served under the name the
    // player already knows; the old file stays frozen and unread.
    final served = _servingJoin && name == ingestPlaylistName ? joinPlaylistName : name;
    final file = File('${_directory.path}${Platform.pathSeparator}$served');
    if (!file.existsSync()) {
      // The player retries; a missing segment is not an error worth closing on.
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = name.endsWith('.m3u8')
        ? ContentType('application', 'vnd.apple.mpegurl')
        : ContentType('video', 'mp2t');
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    try {
      await request.response.addStream(file.openRead());
      await request.response.close();
    } on Object catch (error) {
      // `delete_segments` can remove a segment between the existence check and
      // the read, and the player can hang up mid-file. Either way the answer is
      // a clean end of what was already sent - not an abandoned socket the
      // reader reports as a dead relay.
      _log.warning('ingest file serve failed', error: error, fields: <String, Object?>{'file': name});
      try {
        await request.response.close();
      } on Object catch (_) {
        // The player closed first; nothing left to answer.
      }
    }
  }

  /// Continues the relay on a fresh upstream address; false when the relay is
  /// closed, is a DASH merge, or the renewal round did not come up.
  ///
  /// The renewal first proves the fresh address with a second FFmpeg round in
  /// the same directory, then stops the first round and serves the join's
  /// playlist under the player's own `index.m3u8`. A failed renewal leaves the
  /// first round running - it may simply not be the address's moment - so the
  /// caller retries at its own pace. A round that died on its own can be
  /// revived: the player's window is frozen either way, and the join restarts
  /// it in place. Concurrent calls share one renewal; the address joined is
  /// the first caller's.
  Future<bool> renewAddress(Uri upstream, {Map<String, String> headers = const <String, String>{}}) {
    if (_closed || _dashMerge) return Future<bool>.value(false);
    return _renewing ??= _renew(upstream, headers).whenComplete(() => _renewing = null);
  }

  Future<bool> _renew(Uri upstream, Map<String, String> headers) async {
    IngestFfmpegProcess? join;
    try {
      join = await _startFfmpeg(
        buildJoinArguments(
          source: upstream,
          outputDirectory: _directory.path,
          headers: headers,
          segmentDuration: _segmentDuration,
          playlistSize: _playlistSize,
          copyStreams: _copyStreams,
          videoCodec: _videoCodec,
          audioCodec: _audioCodec,
        ),
      );
      final watch = _adopt(join);
      if (_closed) throw StateError('the relay closed under the renewal');
      await _awaitPublished(
        File('${_directory.path}${Platform.pathSeparator}$joinPlaylistName'),
        watch,
        _startupTimeout,
      );
      if (_closed) throw StateError('the relay closed under the renewal');
      final previous = _execution;
      _log.info('ingest relay renewed', fields: <String, Object?>{'from': _source, 'to': upstream});
      _execution = join;
      _source = upstream;
      _servingJoin = true;
      _exited = false;
      _exitCode = null;
      previous.stop().ignore();
      return true;
    } on Object {
      await join?.stop();
      return false;
    }
  }

  /// Stops FFmpeg, the port and the staging directory.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _log.info('ingest relay closed', fields: <String, Object?>{'source': source});
    await _execution.stop();
    await _server.close(force: true);
    await _deleteQuietly(_directory);
  }

  static Future<void> _deleteQuietly(Directory directory) async {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
    } on Object catch (error) {
      // Staging cleanup is best-effort: the OS temp sweeper is the backstop.
      _log.warning('staging cleanup failed', error: error, fields: <String, Object?>{'directory': directory.path});
    }
  }
}
