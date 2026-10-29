import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart' hide Log;
import 'package:media_core/media_core.dart';

import 'package:media_core_audio/src/download/music_download_request.dart';
import 'package:media_core_audio/src/download/music_download_task.dart';

/// Tuning for [MusicDownloader].
final class MusicDownloadConfig {
  /// Creates a config.
  const MusicDownloadConfig({
    this.readTimeout = const Duration(seconds: 20),
    this.threadQueueSize = 4096,
    this.maxLogLines = 80,
    this.protocolWhitelist = 'httpproxy,udp,rtp,rtsp,rtmp,rtmps,srt,tcp,tls,data,file,http,https,crypto,pipe',
  });

  /// Network read timeout (`-rw_timeout`, in microseconds on the wire).
  ///
  /// A music CDN that accepts the connection and then stalls would otherwise
  /// keep a download "running" forever with no progress — the failure mode a
  /// timeout turns into a retryable error.
  final Duration readTimeout;

  /// Input thread queue size (`-thread_queue_size`).
  final int threadQueueSize;

  /// How many ffmpeg log lines are kept for diagnostics.
  final int maxLogLines;

  /// Protocols ffmpeg may follow (`-protocol_whitelist`).
  final String protocolWhitelist;
}

/// Downloads music with ffmpeg.
///
/// Why ffmpeg and not `http.get`: the interesting music URLs are not files.
/// They are HLS manifests, adaptive streams, signed CDN redirects, or FLAC in
/// a container the platform cannot remux by hand — and ffmpeg already does all
/// of that, including writing proper tags and picking the right codec.
///
/// This is a *download*, not a recording: there is no segment clock, no live
/// duration and no lease handling (see pure_live's recorder for that problem
/// space). One source, one output file, progress measured against the track's
/// duration.
///
/// ```dart
/// final downloader = MusicDownloader();
/// await downloader.initialize();
/// final task = await downloader.run(
///   MusicDownloadTask(id: '1', request: request),
///   onUpdate: (task) => print('${task.progress}'),
/// );
/// ```
final class MusicDownloader {
  /// Creates a downloader.
  MusicDownloader({this.config = const MusicDownloadConfig()});

  /// Tuning.
  final MusicDownloadConfig config;

  static bool _ffmpegInitialized = false;
  static Future<void>? _initializing;

  final Map<String, FFmpegSession> _sessions = <String, FFmpegSession>{};
  final Map<String, StringBuffer> _logs = <String, StringBuffer>{};

  bool _disposed = false;

  /// Number of downloads currently running.
  int get runningCount => _sessions.length;

  /// Initializes the native ffmpeg libraries.
  ///
  /// Safe to call repeatedly and from several downloaders: the plugin's
  /// initialization is process-wide, and racing it is a real crash (two
  /// concurrent `dlopen` chains on Android).
  Future<void> initialize() {
    if (_ffmpegInitialized) {
      return Future<void>.value();
    }

    // A failed initialization is not cached: a transient first failure would
    // otherwise poison every later download for the process lifetime.
    return _initializing ??=
        FFmpegKitExtended.initialize().then((_) {
          _ffmpegInitialized = true;
        }).catchError((Object error, StackTrace stackTrace) {
          _initializing = null;

          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// Builds the ffmpeg arguments for [request].
  ///
  /// Exposed (and pure) on purpose: it is the part worth testing and the part
  /// a host may want to inspect when a download behaves unexpectedly.
  ///
  /// Argument order matters to ffmpeg — input options must precede `-i`, output
  /// options must follow it — which is why this returns a list rather than
  /// letting callers append at will.
  List<String> buildArguments(MusicDownloadRequest request, {String? lyric, String? inputUrl}) {
    final headers = Map<String, String>.from(request.headers);
    final userAgent = request.userAgent ?? headers.remove('user-agent');
    final headerString = _buildHeader(headers);
    final withCover = _canAttachCover(request.extension) && request.embedCover && request.coverUrl != null;

    return <String>[
      '-hide_banner',
      '-loglevel',
      'info',
      '-nostdin',
      '-protocol_whitelist',
      config.protocolWhitelist,
      // The segment cache feeds a local playlist whose entries are files and
      // whose key may still be remote; the demuxer must accept both.
      '-allowed_extensions',
      'ALL',
      '-thread_queue_size',
      '${config.threadQueueSize}',
      '-rw_timeout',
      '${config.readTimeout.inMicroseconds}',
      // A download either produces a correct file or fails; skipping past a
      // corrupt packet would leave a file that plays with a hole in it.
      '-xerror',
      if (userAgent != null && userAgent.isNotEmpty) ...<String>['-user_agent', userAgent],
      if (headerString.isNotEmpty) ...<String>['-headers', headerString],
      '-i',
      inputUrl ?? request.url,
      if (withCover) ...<String>[
        if (userAgent != null && userAgent.isNotEmpty) ...<String>['-user_agent', userAgent],
        if (headerString.isNotEmpty) ...<String>['-headers', headerString],
        '-i',
        request.coverUrl!,
      ],
      // Audio only: a music download must never pull the video track of a
      // music video or an FLV stream.
      '-map',
      '0:a:0',
      if (withCover) ...<String>['-map', '1:v:0'] else '-vn',
      ..._codecArguments(request),
      if (withCover) ...<String>['-c:v', 'copy', '-disposition:v', 'attached_pic'],
      ..._metadataArguments(request, lyric: lyric),
      ...request.extraArguments,
      '-y',
      request.outputPath,
    ];
  }

  /// Rewrites tags on an already-downloaded file, in place.
  ///
  /// A direct HTTP transfer cannot write tags: it appends bytes. The cover,
  /// lyric and title/artist/album are therefore applied afterwards with one
  /// ffmpeg pass that copies the audio stream and only changes the container
  /// metadata. Failure leaves the downloaded audio untouched — a download that
  /// plays is worth more than one whose cover art failed to attach.
  Future<void> rewriteTags(MusicDownloadRequest request, {String? lyric}) async {
    if (!request.embedCover && !request.embedLyric) {
      return;
    }

    if (!_canRewriteTags(request.extension)) {
      MediaCoreLog.debug(
        LogCategory.audio,
        'music tags skipped: ${request.extension} has no writable metadata',
        fields: <String, Object?>{'path': request.outputPath},
      );

      return;
    }

    final file = File(request.outputPath);

    if (!file.existsSync()) {
      return;
    }

    await initialize();

    final tempPath = _temporaryPath(request.outputPath);
    var code = await _runArguments(
      buildTagArguments(request, inputPath: request.outputPath, outputPath: tempPath, lyric: lyric),
    );

    if (code != 0 && request.embedCover) {
      // The cover URL is the part most likely to fail (expired signature,
      // hot-link protection). Retry once without it so the lyric still lands.
      await _deleteIfExists(tempPath);
      code = await _runArguments(
        buildTagArguments(
          request,
          inputPath: request.outputPath,
          outputPath: tempPath,
          includeCover: false,
          lyric: lyric,
        ),
      );
    }

    if (code != 0) {
      await _deleteIfExists(tempPath);

      throw StateError('Writing music tags failed (ffmpeg exit $code)');
    }

    await file.delete();
    await File(tempPath).rename(request.outputPath);
  }

  /// Builds the in-place tag rewrite arguments.
  ///
  /// Exposed for tests: the cover input is the part that is easy to get wrong
  /// (input options must precede its own `-i`, the disposition must sit on the
  /// output stream), and asserting it does not need an ffmpeg binary.
  List<String> buildTagArguments(
    MusicDownloadRequest request, {
    required String inputPath,
    required String outputPath,
    bool includeCover = true,
    String? lyric,
  }) {
    final headers = Map<String, String>.from(request.headers);
    final userAgent = request.userAgent ?? headers.remove('user-agent');
    final headerString = _buildHeader(headers);
    final withCover = includeCover && request.embedCover && request.coverUrl != null && _canAttachCover(request.extension);

    return <String>[
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      '-y',
      '-i',
      inputPath,
      if (withCover) ...<String>[
        if (userAgent != null && userAgent.isNotEmpty) ...<String>['-user_agent', userAgent],
        if (headerString.isNotEmpty) ...<String>['-headers', headerString],
        '-i',
        request.coverUrl!,
      ],
      '-map',
      '0:a:0',
      if (withCover) ...<String>['-map', '1:v:0'],
      '-c:a',
      'copy',
      if (withCover) ...<String>['-c:v', 'copy', '-disposition:v', 'attached_pic'],
      ..._metadataArguments(request, lyric: lyric),
      if (request.extension == 'mp3') ...<String>['-id3v2_version', '3'],
      outputPath,
    ];
  }

  /// Runs one download to completion.
  ///
  /// [onUpdate] receives the task on every progress tick and on every status
  /// change. The returned task is the terminal one; a failure is *returned*
  /// rather than thrown, because a download that fails is a normal outcome the
  /// queue wants to retry.
  Future<MusicDownloadTask> run(
    MusicDownloadTask task, {
    void Function(MusicDownloadTask)? onUpdate,
    String? lyric,
    String? inputUrl,
  }) async {
    if (_disposed) {
      return task.copyWith(status: MusicDownloadStatus.failed, error: 'Downloader disposed');
    }

    await initialize();

    final running = task.copyWith(status: MusicDownloadStatus.running, startedAt: DateTime.now(), clearError: true);

    onUpdate?.call(running);

    final logs = StringBuffer();
    _logs[task.id] = logs;

    final session = FFmpegKit.createSessionFromArguments(buildArguments(task.request, lyric: lyric, inputUrl: inputUrl));
    _sessions[task.id] = session;

    final completer = Completer<MusicDownloadTask>();

    session.setLogCallback((log) {
      // `Log.message` is a plain field in the plugin's current API (it read as
      // a getter in older releases).
      final message = log.message;

      if (message.trim().isNotEmpty) {
        logs.writeln(message);

        // Bounded: a long download logs thousands of lines and only the tail
        // is ever useful for diagnosing a failure.
        final lines = logs.toString().split('\n');

        if (lines.length > config.maxLogLines) {
          logs
            ..clear()
            ..writeln(lines.sublist(lines.length - config.maxLogLines).join('\n'));
        }
      }
    });

    // The live snapshot the terminal copy is derived from: without it the
    // completed/failed task restarts from `running`'s zeros and the UI bar
    // snaps from ~100% back to nothing at the moment of completion.
    var latest = running;

    session.setStatisticsCallback((statistics) {
      latest = running.copyWith(
        processed: Duration(milliseconds: statistics.time),
        speed: statistics.speed > 0 ? statistics.speed : 0,
        bytesReceived: statistics.size,
        sessionId: session.sessionId.toString(),
      );
      onUpdate?.call(latest);
    });

    session.setCompleteCallback((completed) {
      _sessions.remove(task.id);
      _logs.remove(task.id);

      final code = completed.getReturnCode();
      final finishedAt = DateTime.now();

      if (_cancelled.contains(task.id)) {
        _cancelled.remove(task.id);

        if (!completer.isCompleted) {
          completer.complete(latest.copyWith(status: MusicDownloadStatus.cancelled, finishedAt: finishedAt));
        }

        return;
      }

      // ffmpeg's success code is 0; a negative code is a signal (SIGKILL from
      // cancel, SIGTERM from the OS) and anything positive is an ffmpeg error.
      if (code == 0) {
        if (!completer.isCompleted) {
          completer.complete(latest.copyWith(status: MusicDownloadStatus.completed, finishedAt: finishedAt));
        }

        return;
      }

      final tail = logs.toString().trim();
      final reason = _extractError(tail) ?? 'ffmpeg exited with code $code';

      MediaCoreLog.warning(
        LogCategory.error,
        'music download failed: ${task.request.outputPath}',
        fields: <String, Object?>{'code': code, 'url': task.request.url},
      );

      if (!completer.isCompleted) {
        completer.complete(latest.copyWith(status: MusicDownloadStatus.failed, error: reason, finishedAt: finishedAt));
      }
    });

    try {
      await session.executeAsync();
    } on Object catch (error) {
      _sessions.remove(task.id);
      _logs.remove(task.id);

      if (!completer.isCompleted) {
        completer.complete(running.copyWith(status: MusicDownloadStatus.failed, error: error.toString()));
      }
    }

    return await completer.future;
  }

  /// Cancels a running download.
  ///
  /// The task is only reported cancelled once ffmpeg's completion callback
  /// arrives: ffmpeg removes its own partial output, and marking the task
  /// terminal earlier would let a queue start the next attempt while the file
  /// is still being written.
  Future<void> cancel(String taskId) async {
    final session = _sessions[taskId];

    if (session == null) {
      return;
    }

    _cancelled.add(taskId);

    FFmpegKit.cancel(session);
  }

  /// Whether [taskId] was cancelled and is waiting for ffmpeg to confirm.
  bool isCancelling(String taskId) => _cancelled.contains(taskId);

  /// Releases sessions and log buffers.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    for (final session in _sessions.values) {
      try {
        FFmpegKit.cancel(session);
      } on Object catch (_) {
        // Best effort: a session that is already gone needs no cancel.
      }
    }

    _sessions.clear();
    _logs.clear();
    _cancelled.clear();
  }

  final Set<String> _cancelled = <String>{};

  /// Tag arguments shared by the one-pass download and the in-place rewrite.
  List<String> _metadataArguments(MusicDownloadRequest request, {String? lyric}) {
    final writable = _canRewriteTags(request.extension);
    final lyrics = (lyric ?? request.lyric)?.trim() ?? '';

    return <String>[
      if (request.title != null) ...<String>['-metadata', 'title=${request.title}'],
      if (request.artist != null) ...<String>['-metadata', 'artist=${request.artist}'],
      if (request.album != null) ...<String>['-metadata', 'album=${request.album}'],
      if (writable && request.embedLyric && lyrics.isNotEmpty) ...<String>['-metadata', 'lyrics=$lyrics'],
      if (request.extension == 'mp3') ...<String>['-id3v2_version', '3'],
    ];
  }

  /// Runs ffmpeg for one tag-rewrite pass and returns its exit code.
  Future<int> _runArguments(List<String> arguments) async {
    final logs = StringBuffer();
    final session = FFmpegKit.createSessionFromArguments(arguments);
    final completer = Completer<int>();

    session
      ..setLogCallback((log) {
        if (log.message.trim().isNotEmpty) {
          logs.writeln(log.message);
        }
      })
      ..setCompleteCallback((completed) {
        if (!completer.isCompleted) {
          completer.complete(completed.getReturnCode());
        }
      });

    try {
      await session.executeAsync();
    } on Object catch (error) {
      if (!completer.isCompleted) {
        completer.complete(-1);
      }

      MediaCoreLog.warning(
        LogCategory.error,
        'music tag rewrite failed: ${arguments.last}',
        error: error,
      );
    }

    final code = await completer.future;

    if (code != 0) {
      MediaCoreLog.warning(
        LogCategory.error,
        'music tag rewrite exited with $code: ${arguments.last}',
        fields: <String, Object?>{'log': logs.toString().trim()},
      );
    }

    return code;
  }

  /// Containers whose metadata blocks ffmpeg can rewrite.
  static bool _canRewriteTags(String extension) {
    return const <String>{'mp3', 'm4a', 'mp4', 'flac', 'ogg', 'opus'}.contains(extension);
  }

  /// Containers that accept an attached-picture stream.
  static bool _canAttachCover(String extension) {
    return const <String>{'mp3', 'm4a', 'mp4', 'flac'}.contains(extension);
  }

  static String _temporaryPath(String path) {
    final dot = path.lastIndexOf('.');

    return dot <= 0 ? '$path.tmp' : '${path.substring(0, dot)}.tmp${path.substring(dot)}';
  }

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Codec/output arguments for the requested format.
  List<String> _codecArguments(MusicDownloadRequest request) {
    return switch (request.format) {
      MusicDownloadFormat.copy => const <String>['-c:a', 'copy'],
      MusicDownloadFormat.mp3 => <String>['-c:a', 'libmp3lame', '-b:a', '${request.bitrateKbps}k'],
      MusicDownloadFormat.m4a => <String>[
        '-c:a',
        'aac',
        '-b:a',
        '${request.bitrateKbps}k',
        // Puts the index at the front so the file is seekable while it is
        // still being copied around.
        '-movflags',
        '+faststart',
      ],
      MusicDownloadFormat.flac => const <String>['-c:a', 'flac'],
      MusicDownloadFormat.ogg => <String>['-c:a', 'libvorbis', '-b:a', '${request.bitrateKbps}k'],
      MusicDownloadFormat.wav => const <String>['-c:a', 'pcm_s16le'],
    };
  }

  /// Joins [headers] into the CRLF block ffmpeg's `-headers` option expects.
  ///
  /// Validation is the framework's, not this package's: see
  /// [HttpHeaderSanitizer] for why a header that cannot be sent exactly as
  /// given is an error rather than something to rewrite or drop.
  String _buildHeader(Map<String, String> headers) {
    return HttpHeaderSanitizer.ffmpegBlock(HttpHeaderSanitizer.sanitize(headers));
  }

  /// Picks the most useful line out of an ffmpeg log tail.
  static String? _extractError(String logs) {
    if (logs.isEmpty) {
      return null;
    }

    final lines = logs.split('\n').reversed;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.contains('Server returned') ||
          trimmed.contains('HTTP error') ||
          trimmed.contains('Invalid data found') ||
          trimmed.contains('No such file') ||
          trimmed.contains('Permission denied') ||
          trimmed.contains('Error opening') ||
          trimmed.contains('failed')) {
        return trimmed;
      }
    }

    return null;
  }
}
