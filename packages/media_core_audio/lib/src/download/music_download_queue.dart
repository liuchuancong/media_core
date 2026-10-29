import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_core/media_core.dart' show IdGenerator, LogCategory, MediaCoreLog;
import 'package:media_core_audio/src/download/hls_playlist.dart';
import 'package:media_core_audio/src/download/music_download_request.dart';
import 'package:media_core_audio/src/download/music_download_task.dart';
import 'package:media_core_audio/src/download/music_downloader.dart';
import 'package:media_core_audio/src/lyric/lyric_exporter.dart';
import 'package:media_core_audio/src/lyric/lyric_parser.dart';
import 'package:media_core_audio/src/source/music_source.dart' show MusicLyricPayload;
import 'package:media_core_audio/src/track/music_quality.dart';
import 'package:media_core_audio/src/track/music_track.dart';
import 'package:media_core_audio/src/track/track_source.dart';
import 'package:media_core_download/media_core_download.dart';

/// A download queue with bounded concurrency, pause/resume and retries.
///
/// Music downloads are started from a list (select several songs, "download
/// all"), which means they arrive in bursts. Running them all at once turns a
/// rate-limited music API into a wall of failures, so the queue keeps at most
/// [maxConcurrent] transfers alive and retries a failed one up to
/// [maxAttempts] times — a signed URL that expired mid-download, or a CDN that
/// dropped a connection, both succeed on a second attempt with a fresh URL.
///
/// Two transfer strategies share the queue:
///
/// - **direct** — a finished container over HTTP is appended byte-by-byte with
///   the core download primitives, so pausing keeps the partial file and
///   resuming verifies its tail before continuing (lx-music's resume rule);
/// - **ffmpeg** — HLS/DASH/segmented sources and transcodes run through
///   ffmpeg. A DASH stream or a transcode cannot be resumed mid-file, so
///   pausing cancels it; an HLS playlist is cached segment by segment first,
///   and a resumed task fetches only the segments it is missing before ffmpeg
///   reads the local playlist.
///
/// The queue owns task *status*, not task URLs: a host that needs a fresh URL
/// per attempt passes a `resolve` callback, and the queue re-resolves before
/// each retry instead of replaying a spent signature.
final class MusicDownloadQueue {
  /// Creates a queue.
  MusicDownloadQueue({
    MusicDownloader? downloader,
    DownloadTransport? transport,
    DownloadFileSink? files,
    this.maxConcurrent = 1,
    this.maxAttempts = 2,
    this.retryDelay = const Duration(seconds: 2),
    this.progressInterval = const Duration(milliseconds: 250),
  }) : _downloader = downloader ?? MusicDownloader(),
       _transport = transport ?? HttpDownloadTransport(),
       _files = files ?? const IoDownloadFileSink();

  /// Maximum simultaneous downloads; [setMaxConcurrent] changes it while
  /// tasks are queued. Transfers already running are left alone.
  int maxConcurrent;

  /// Attempts per task, including the first.
  final int maxAttempts;

  /// Delay before a retry.
  final Duration retryDelay;

  /// Minimum spacing between progress events for one task.
  final Duration progressInterval;

  final MusicDownloader _downloader;
  final DownloadTransport _transport;
  final DownloadFileSink _files;
  final DownloadResumePlanner _resumePlanner = const DownloadResumePlanner();
  final LyricParser _lyricParser = const LyricParser();
  final LyricExporter _lyricExporter = const LyricExporter();

  final Map<String, MusicDownloadTask> _tasks = <String, MusicDownloadTask>{};
  final Map<String, Completer<void>> _running = <String, Completer<void>>{};
  final StreamController<MusicDownloadTask> _updates = StreamController<MusicDownloadTask>.broadcast();

  /// Per-task URL resolvers, used by retries to obtain a fresh URL.
  final Map<String, Future<MusicDownloadRequest> Function()> _resolvers = {};

  /// Task ids whose transfer must stop at its next chunk boundary.
  final Set<String> _paused = <String>{};

  /// Task ids the viewer cancelled or removed.
  final Set<String> _abandoned = <String>{};

  /// Task → the attempt currently transferring it.
  final Map<String, Object> _inFlight = <String, Object>{};

  final Map<String, DateTime> _lastProgressAt = <String, DateTime>{};
  final Map<String, DateTime> _lastSpeedAt = <String, DateTime>{};
  final Map<String, int> _lastSpeedBytes = <String, int>{};

  bool _disposed = false;

  /// Task updates: progress ticks and status changes.
  Stream<MusicDownloadTask> get updates => _updates.stream;

  /// All known tasks, in enqueue order.
  List<MusicDownloadTask> get tasks => List<MusicDownloadTask>.unmodifiable(_tasks.values);

  /// Tasks that reached a terminal status.
  List<MusicDownloadTask> get finished => _tasks.values.where((task) => task.isTerminal).toList(growable: false);

  /// Tasks still queued, paused or running.
  List<MusicDownloadTask> get pending => _tasks.values.where((task) => !task.isTerminal).toList(growable: false);

  /// Whether anything is queued or running.
  bool get isActive => pending.isNotEmpty;

  /// The underlying ffmpeg downloader.
  MusicDownloader get downloader => _downloader;

  /// The task with [id], or null.
  MusicDownloadTask? task(String id) => _tasks[id];

  /// Changes how many transfers may run at once.
  ///
  /// Raising it starts queued tasks at the next free slot; lowering it lets
  /// running transfers finish and holds the rest until one does.
  Future<void> setMaxConcurrent(int value) {
    maxConcurrent = value < 1 ? 1 : value;
    return _drain();
  }

  /// Enqueues [request].
  ///
  /// [resolve] is optional and only used for retries: pass a callback that
  /// re-resolves the track's URL when the host knows the URL is signed and
  /// short-lived. [dedupe] returns an existing non-terminal task instead of
  /// creating a second row for the same track, quality and container.
  MusicDownloadTask enqueue(
    MusicDownloadRequest request, {
    String? id,
    Future<MusicDownloadRequest> Function()? resolve,
    bool dedupe = false,
  }) {
    if (dedupe) {
      final existing = _findDuplicate(request);

      if (existing != null) {
        // The map holds the freshest immutable snapshot; the local reference
        // may still name the queued copy from before the transfer started.
        return _tasks[existing.id] ?? existing;
      }
    }

    final taskId = id ?? 'dl_${IdGenerator.timestamped()}';
    _paused.remove(taskId);
    _abandoned.remove(taskId);

    final task = MusicDownloadTask(id: taskId, request: request);

    _tasks[taskId] = task;

    if (resolve != null) {
      _resolvers[taskId] = resolve;
    }

    _emit(task);
    unawaited(_drain());

    return task;
  }

  /// Enqueues a track resolved by [source].
  ///
  /// The extra options are the post-processing half of lx-music's download
  /// settings: embed the cover/lyric, write a sidecar `.lrc`, group by list,
  /// and skip a file that is already there.
  MusicDownloadTask downloadTrack({
    required MusicTrack track,
    required TrackSource source,
    required String directory,
    String pattern = '{artist} - {title}',
    MusicDownloadFormat? format,
    int bitrateKbps = 320,
    MusicQuality? quality,
    String? listName,
    String? subdirectory,
    int? index,
    String? coverUrl,
    MusicLyricPayload? lyric,
    bool embedCover = false,
    bool embedLyric = false,
    bool writeLyricFile = false,
    bool skipExisting = false,
    LyricFileEncoding lyricEncoding = LyricFileEncoding.utf8Bom,
    bool includeTranslation = false,
    bool includeRomanization = false,
    bool includeWordTiming = false,
    bool includeAwlrc = false,
    Future<MusicDownloadRequest> Function()? resolve,
    bool dedupe = true,
  }) {
    return enqueue(
      MusicDownloadRequest.forTrack(
        track: track,
        source: source,
        directory: directory,
        pattern: pattern,
        format: format,
        bitrateKbps: bitrateKbps,
        quality: quality,
        listName: listName,
        subdirectory: subdirectory,
        index: index,
        coverUrl: coverUrl,
        lyric: lyric,
        embedCover: embedCover,
        embedLyric: embedLyric,
        writeLyricFile: writeLyricFile,
        skipExisting: skipExisting,
        lyricEncoding: lyricEncoding,
        includeTranslation: includeTranslation,
        includeRomanization: includeRomanization,
        includeWordTiming: includeWordTiming,
        includeAwlrc: includeAwlrc,
      ),
      resolve: resolve,
      dedupe: dedupe,
    );
  }

  /// Enqueues several requests; returns the tasks in the same order.
  List<MusicDownloadTask> enqueueAll(Iterable<MusicDownloadRequest> requests, {bool dedupe = true}) {
    return <MusicDownloadTask>[
      for (final request in requests) enqueue(request, dedupe: dedupe),
    ];
  }

  /// Suspends a task, keeping a direct transfer's partial file.
  ///
  /// A queued task is paused too: a viewer pressing pause in the moment before
  /// a slot frees up means it, and that moment is easy to hit with several
  /// downloads waiting.
  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];

    if (task == null || task.isTerminal || task.status == MusicDownloadStatus.paused) {
      return;
    }

    _paused.add(taskId);
    _emit(task.copyWith(status: MusicDownloadStatus.paused));

    if (!task.request.isDirectTransfer) {
      await _downloader.cancel(taskId);
    }
  }

  /// Pauses every non-terminal task.
  Future<void> pauseAll() async {
    for (final task in pending) {
      await pause(task.id);
    }
  }

  /// Continues a paused task.
  ///
  /// A paused direct transfer resumes from its partial file; an ffmpeg
  /// transfer restarts its own pass, and an HLS source reuses the segments its
  /// cache already holds.
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];

    if (task == null || task.isTerminal || task.status != MusicDownloadStatus.paused) {
      return;
    }

    // The previous attempt may still be appending its last chunk; starting a
    // resumed attempt underneath that append corrupts the partial file.
    final running = _running[taskId]?.future;

    if (running != null) {
      try {
        await running.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // The old attempt is blocked inside a network read and cannot observe
        // the pause yet. Starting a second writer would corrupt the partial
        // file; leave the task paused and let the caller retry later.
        return;
      }
    }

    _paused.remove(taskId);
    _abandoned.remove(taskId);
    _emit(task.copyWith(status: MusicDownloadStatus.queued, clearError: true));
    unawaited(_drain());
  }

  /// Resumes every paused task.
  Future<void> resumeAll() async {
    for (final task in pending.where((task) => task.status == MusicDownloadStatus.paused).toList(growable: false)) {
      await resume(task.id);
    }
  }

  /// Clears the retry budget and starts a failed or paused task again.
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];

    if (task == null || task.status.isRunning || (task.isTerminal && task.status != MusicDownloadStatus.failed)) {
      return;
    }

    _paused.remove(taskId);
    _abandoned.remove(taskId);
    _emit(task.copyWith(status: MusicDownloadStatus.queued, attempt: 1, clearError: true));
    unawaited(_drain());
  }

  /// Cancels a task, keeping the partial file.
  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];

    if (task == null || task.isTerminal) {
      return;
    }

    _abandoned.add(taskId);
    _paused.remove(taskId);
    _inFlight.remove(taskId);

    if (!task.request.isDirectTransfer) {
      await _downloader.cancel(taskId);
    }

    _emit(task.copyWith(status: MusicDownloadStatus.cancelled, finishedAt: DateTime.now()));
  }

  /// Forgets a task, optionally deleting its output and sidecar lyric.
  Future<void> remove(String taskId, {bool deleteFile = false}) async {
    final task = _tasks[taskId];

    if (task == null) {
      return;
    }

    await cancel(taskId);

    final running = _running[taskId]?.future;

    if (running != null) {
      await running.timeout(const Duration(seconds: 5), onTimeout: () {});
    }

    _tasks.remove(taskId);
    _resolvers.remove(taskId);
    _paused.remove(taskId);
    _abandoned.remove(taskId);
    _lastProgressAt.remove(taskId);
    _lastSpeedAt.remove(taskId);
    _lastSpeedBytes.remove(taskId);

    // The segment cache is scratch space for this task; removing the row makes
    // it unreachable, whether or not the viewer also asked to delete the file.
    if (_isHls(task.request)) {
      await _discardHlsCache(task.request);
    }

    if (deleteFile) {
      await _deleteIfExists(task.request.outputPath);

      final lyricPath = task.lyricPath ?? task.request.lyricPath;

      if (lyricPath != null) {
        await _deleteIfExists(lyricPath);
      }
    }

    unawaited(_drain());
  }

  /// Forgets terminal tasks.
  void clearFinished() {
    _tasks.removeWhere((id, task) {
      final remove = task.isTerminal;

      if (remove) {
        _resolvers.remove(id);
        _lastProgressAt.remove(id);
        _lastSpeedAt.remove(id);
        _lastSpeedBytes.remove(id);
      }

      return remove;
    });
  }

  /// Restores persisted tasks, marking unfinished ones paused.
  ///
  /// The process that was transferring them is gone; a restored "running" row
  /// would never make progress and could not be resumed by the viewer.
  void restore(Iterable<MusicDownloadTask> tasks) {
    for (final task in tasks) {
      final restored = task.isTerminal ? task : task.copyWith(status: MusicDownloadStatus.paused, clearError: true);

      _tasks[restored.id] = restored;
      _emit(restored);
    }
  }

  /// Runs one task to completion, retrying per [maxAttempts].
  Future<void> _run(String taskId) async {
    var task = _tasks[taskId];

    if (task == null) {
      return;
    }

    final token = Object();
    _inFlight[taskId] = token;

    try {
      while (_isActive(taskId, token)) {
        if (task!.isTerminal || task.status == MusicDownloadStatus.paused) {
          return;
        }

        task = task.copyWith(status: MusicDownloadStatus.running, startedAt: DateTime.now(), clearError: true);
        _emit(task);

        MusicDownloadTask outcome;

        try {
          outcome = task.request.isDirectTransfer
              ? await _runDirect(task, token)
              : await _runFfmpeg(task, token);
        } on Object catch (error) {
          if (!_isActive(taskId, token)) {
            return;
          }

          outcome = task.copyWith(
            status: MusicDownloadStatus.failed,
            error: error.toString(),
            finishedAt: DateTime.now(),
          );
          _emit(outcome);
        }

        if (!_isActive(taskId, token)) {
          return;
        }

        if (outcome.status == MusicDownloadStatus.completed) {
          // Both transfer paths end in "processing": the bytes are there but
          // cover art, tags and a sidecar lyric may still be pending.
          outcome = await _finalize(outcome);
          _emit(outcome);

          return;
        }

        if (outcome.status == MusicDownloadStatus.processing) {
          outcome = await _finalize(outcome);
          _emit(outcome);

          return;
        }

        if (outcome.status == MusicDownloadStatus.skipped) {
          _emit(outcome);

          return;
        }

        if (outcome.status == MusicDownloadStatus.cancelled) {
          return;
        }

        if (outcome.attempt >= maxAttempts) {
          // The ffmpeg path reports a failure by returning, not throwing; the
          // last attempt has to publish it or the row keeps its "running"
          // snapshot forever.
          _emit(outcome);

          return;
        }

        final nextAttempt = outcome.attempt + 1;

        if (retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
        }

        if (!_isActive(taskId, token)) {
          return;
        }

        var request = outcome.request;
        final resolver = _resolvers[taskId];

        if (resolver != null) {
          try {
            request = await resolver();
          } on Object catch (_) {
            // Resolution failed: keep the previous request and let the next
            // attempt report the download error.
          }
        }

        task = MusicDownloadTask(
          id: taskId,
          request: request,
          attempt: nextAttempt,
          error: outcome.error,
          bytesReceived: outcome.bytesReceived,
          bytesTotal: outcome.bytesTotal,
        );

        _emit(task);
      }
    } finally {
      if (identical(_inFlight[taskId], token)) {
        _inFlight.remove(taskId);
      }
    }
  }

  /// Fetches a finished container with resumable byte appends.
  Future<MusicDownloadTask> _runDirect(MusicDownloadTask task, Object token) async {
    final request = task.request;
    final path = request.outputPath;

    await _files.ensureParentDirectory(path);

    final existing = await _files.length(path);

    if (existing > 0 && request.skipExisting) {
      return task.copyWith(
        status: MusicDownloadStatus.skipped,
        bytesReceived: existing,
        bytesTotal: existing,
        finishedAt: DateTime.now(),
      );
    }

    // A partial file this task wrote is worth resuming; a file that was already
    // there before the download started is a previous version and is replaced.
    final keepPartial = existing > 0 && (task.attempt > 1 || task.bytesReceived > 0);

    if (existing > 0 && !keepPartial) {
      await _files.delete(path);
    }

    var resume = await _files.length(path) > 0;

    while (true) {
      try {
        final result = await _transferOnce(task, token, resume: resume);

        if (result == null) {
          // Paused/cancelled: the status the viewer's action published stands.
          return task.copyWith(status: MusicDownloadStatus.paused);
        }

        return task.copyWith(
          status: MusicDownloadStatus.processing,
          bytesReceived: result.received,
          bytesTotal: result.total > 0 ? result.total : result.received,
          startedAt: task.startedAt ?? DateTime.now(),
        );
      } on _ResumeMismatch {
        if (!resume) {
          rethrow;
        }

        await _files.truncate(path, 0);
        resume = false;
      }
    }
  }

  Future<({int received, int total})?> _transferOnce(
    MusicDownloadTask task,
    Object token, {
    required bool resume,
  }) async {
    final request = task.request;
    final path = request.outputPath;
    var startByte = 0;
    var verify = false;

    if (resume) {
      final plan = _resumePlanner.plan(
        localBytes: await _files.length(path),
        remoteBytes: null,
        serverAcceptsRanges: true,
      );

      switch (plan.decision) {
        case DownloadResumeDecision.restart:
        case DownloadResumeDecision.alreadyComplete:
          await _files.truncate(path, 0);
        case DownloadResumeDecision.resume:
          startByte = plan.startByte;
          verify = plan.verifyBytes > 0;
      }
    }

    DownloadResponse response;

    try {
      response = await _fetch(request, startByte);
    } on DownloadHttpException catch (error) {
      if (error.statusCode != 416 || startByte == 0) {
        rethrow;
      }

      // The remote no longer has the range the partial file claims; restarting
      // costs one file, while replaying the same range burns every attempt.
      await _files.truncate(path, 0);
      startByte = 0;
      verify = false;
      response = await _fetch(request, 0);
    }

    if (startByte > 0 && !response.isPartial) {
      // A server that ignores Range answers 200 with the whole body. Appending
      // it would duplicate everything already on disk.
      await _files.truncate(path, 0);
      startByte = 0;
      verify = false;
      response = await _fetch(request, 0);
    }

    final total = response.resolvedTotalBytes ?? -1;
    final head = <int>[];
    var received = startByte;

    await for (final chunk in response.byteStream) {
      if (!_isActive(task.id, token)) {
        return null;
      }

      if (chunk.isEmpty) {
        continue;
      }

      if (verify && head.length < _resumePlanner.config.verifyTailBytes) {
        head.addAll(chunk);

        if (head.length >= _resumePlanner.config.verifyTailBytes) {
          final expected = head.sublist(0, _resumePlanner.config.verifyTailBytes);
          final localTail = await _files.readTail(path, _resumePlanner.config.verifyTailBytes);

          if (!_resumePlanner.tailMatches(localTail: localTail, remoteTail: expected)) {
            await _files.truncate(path, 0);

            throw const _ResumeMismatch();
          }

          await _files.truncate(path, startByte);
          await _files.append(path, head);

          received = startByte + head.length;
          verify = false;

          _reportProgress(task, received, total, force: true);
        }

        continue;
      }

      await _files.append(path, chunk);
      received += chunk.length;

      _reportProgress(task, received, total);
    }

    if (verify) {
      // Fewer bytes than the verification window: nothing was proven.
      await _files.truncate(path, 0);

      throw const _ResumeMismatch();
    }

    if (total > 0 && received < total) {
      throw StateError('Transfer ended at $received of $total bytes.');
    }

    return (received: received, total: total);
  }

  Future<DownloadResponse> _fetch(MusicDownloadRequest request, int startByte) {
    return _transport.fetch(
      DownloadRequest(
        url: request.url,
        startByte: startByte,
        headers: request.headers,
        userAgent: request.userAgent,
        maxRedirects: 3,
      ),
    );
  }

  /// Runs an ffmpeg transfer (HLS, DASH, transcodes).
  ///
  /// An HLS playlist is first turned into a local segment cache: every segment
  /// is fetched on its own and renamed into place only once complete, so a
  /// retry or a resumed task skips what it already has instead of starting the
  /// whole song again (lx-music's segment cache rule). ffmpeg then reads the
  /// rewritten local playlist.
  Future<MusicDownloadTask> _runFfmpeg(MusicDownloadTask task, Object token) async {
    String? inputUrl;
    var cached = false;

    if (_isHls(task.request)) {
      final prepared = await _prepareHls(task, token);

      if (prepared == null) {
        return task.copyWith(status: MusicDownloadStatus.paused);
      }

      inputUrl = prepared.url;
      cached = prepared.cached;
    }

    final result = await _downloader.run(
      task,
      lyric: task.request.embedLyric ? _downloadLyricText(task.request) : null,
      inputUrl: inputUrl,
      onUpdate: (updated) {
        if (_isActive(task.id, token)) {
          _emit(updated);
        }
      },
    );

    if (!_isActive(task.id, token)) {
      return task.copyWith(status: MusicDownloadStatus.paused);
    }

    if (result.isCompleted) {
      if (cached) {
        await _discardHlsCache(task.request);
      }

      return result.copyWith(status: MusicDownloadStatus.processing);
    }

    return result;
  }

  /// Whether [request] points at an HLS playlist rather than a file.
  static bool _isHls(MusicDownloadRequest request) {
    final uri = Uri.tryParse(request.url);

    if (uri == null) {
      return false;
    }

    final path = uri.path.toLowerCase();

    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }

  /// Builds the local playlist ffmpeg reads, downloading whatever segments the
  /// cache is missing.
  ///
  /// Returns the URL ffmpeg should open — the rewritten local playlist, whose
  /// `cached` flag says the segment cache backs it — or the remote URL when the
  /// source cannot be cached (a live playlist's window moves, and a URL that
  /// answers with something other than a playlist is left to ffmpeg). Returns
  /// null when the task was paused or cancelled.
  Future<({String url, bool cached})?> _prepareHls(MusicDownloadTask task, Object token) async {
    final request = task.request;
    final remote = Uri.parse(request.url);

    var text = await _fetchPlaylistText(remote, task, token);

    if (text == null) {
      return null;
    }

    if (!text.contains('#EXTM3U')) {
      // Not a playlist, whatever the extension said: let ffmpeg have it.
      return (url: request.url, cached: false);
    }

    var base = remote;
    final master = HlsMasterPlaylist.parse(text, remote);

    if (master != null) {
      base = master.choose(request.qualityId).uri;
      final variant = await _fetchPlaylistText(base, task, token);

      if (variant == null) {
        return null;
      }

      text = variant;
    }

    final media = HlsMediaPlaylist.parse(text, base);

    if (media == null || media.isLive) {
      // A live window cannot be resumed from a cache; ffmpeg follows it.
      return (url: request.url, cached: false);
    }

    final directory = _hlsCacheDirectory(request);
    await Directory(directory).create(recursive: true);

    String? initPath;

    if (media.initUri != null) {
      initPath = initCachePath(directory, media.initUri!);

      if (!await _hasContent(initPath)) {
        final written = await _downloadHlsFile(
          media.initUri!,
          initPath,
          task,
          token,
          onBytes: (received) => _reportProgress(task, received, 0),
        );

        if (written == null) {
          return null;
        }
      }
    }

    final cached = await completedHlsSegments(directory, media.segments);
    var settled = 0;

    for (final index in cached) {
      settled += await _files.length(segmentCachePath(directory, index, media.segments[index].uri));
    }

    // A byte-range playlist names one resource from several `#EXT-X-BYTERANGE`
    // segments; caching it once keeps the ranges meaningful and the transfer
    // from fetching the same file per segment.
    final byUri = <String, String>{};
    final paths = <String>[];

    for (var index = 0; index < media.segments.length; index++) {
      final uri = media.segments[index].uri;
      final key = uri.toString();
      final known = byUri[key];

      if (known != null) {
        paths.add(known);
        continue;
      }

      final path = segmentCachePath(directory, index, uri);

      byUri[key] = path;
      paths.add(path);

      if (cached.contains(index)) {
        continue;
      }

      final written = await _downloadHlsFile(
        media.segments[index].uri,
        path,
        task,
        token,
        onBytes: (received) => _reportProgress(task, settled + received, 0),
      );

      if (written == null) {
        return null;
      }

      settled += written;
    }

    final playlistPath = '$directory/playlist.m3u8';
    final rewritten = rewriteHlsPlaylist(text, base: base, segmentPaths: paths, initPath: initPath);

    await File(playlistPath).writeAsString(rewritten, flush: true);

    return (url: Uri.file(playlistPath).toString(), cached: true);
  }

  /// Reads [uri] as text; null when the task was paused or cancelled.
  Future<String?> _fetchPlaylistText(Uri uri, MusicDownloadTask task, Object token) async {
    final request = task.request;
    final response = await _transport.fetch(
      DownloadRequest(
        url: uri.toString(),
        startByte: 0,
        headers: request.headers,
        userAgent: request.userAgent,
        maxRedirects: 3,
      ),
    );
    final builder = BytesBuilder(copy: false);

    await for (final chunk in response.byteStream) {
      if (!_isActive(task.id, token)) {
        return null;
      }

      builder.add(chunk);
    }

    final bytes = builder.takeBytes();

    if (bytes.isEmpty) {
      throw StateError('The HLS playlist at $uri is empty.');
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Downloads one segment (or the init segment) to [path].
  ///
  /// The bytes land in `<path>.part` first: a segment file only appears under
  /// its final name when it is complete, so [completedHlsSegments] can trust
  /// existence. [onBytes] reports the running size while it arrives. Returns
  /// the byte count, or null when the task was paused or cancelled.
  Future<int?> _downloadHlsFile(
    Uri uri,
    String path,
    MusicDownloadTask task,
    Object token, {
    required void Function(int received) onBytes,
  }) async {
    final request = task.request;
    final response = await _transport.fetch(
      DownloadRequest(
        url: uri.toString(),
        startByte: 0,
        headers: request.headers,
        userAgent: request.userAgent,
        maxRedirects: 3,
      ),
    );
    final partial = '$path.part';

    await _files.truncate(partial, 0);

    var received = 0;

    await for (final chunk in response.byteStream) {
      if (!_isActive(task.id, token)) {
        await _files.delete(partial);

        return null;
      }

      if (chunk.isEmpty) {
        continue;
      }

      await _files.append(partial, chunk);
      received += chunk.length;
      onBytes(received);
    }

    if (received == 0) {
      await _files.delete(partial);

      throw StateError('The HLS segment at $uri is empty.');
    }

    final target = File(path);

    if (target.existsSync()) {
      await target.delete();
    }

    await File(partial).rename(path);

    return received;
  }

  /// The scratch directory holding one task's segment cache.
  static String _hlsCacheDirectory(MusicDownloadRequest request) => '${request.outputPath}.parts';

  /// Deletes a task's segment cache.
  Future<void> _discardHlsCache(MusicDownloadRequest request) async {
    final directory = Directory(_hlsCacheDirectory(request));

    try {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    } on Object catch (error) {
      MediaCoreLog.warning(
        LogCategory.error,
        'music download cache cleanup failed: ${directory.path}',
        error: error,
      );
    }
  }

  static Future<bool> _hasContent(String path) async {
    try {
      return await File(path).length() > 0;
    } on Object {
      return false;
    }
  }

  /// The lyric text a download writes, for both the sidecar and the embedded
  /// tag: the source's lyric plus the translation, romanization, word timing
  /// or `[awlrc:…]` block the request asked for — lx-music's `buildLyrics`.
  String? _downloadLyricText(MusicDownloadRequest request) {
    final raw = request.lyric?.trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      final document = _lyricParser.parse(
        raw,
        format: request.lyricFormat,
        translation: request.lyricTranslation,
        romanization: request.lyricRomanization,
      );
      final text = _lyricExporter
          .build(
            document,
            options: LyricExportOptions(
              includeTranslation: request.includeTranslation,
              includeRomanization: request.includeRomanization,
              includeWordTiming: request.includeWordTiming,
              includeAwlrc: request.includeAwlrc,
            ),
          )
          .trim();

      return text.isEmpty ? null : text;
    } on Object {
      return raw;
    }
  }

  /// Writes tags and the sidecar lyric after the bytes are complete.
  Future<MusicDownloadTask> _finalize(MusicDownloadTask task) async {
    var updated = task.copyWith(status: MusicDownloadStatus.processing);
    _emit(updated);

    final request = updated.request;
    final downloadLyric = _downloadLyricText(request);
    String? lyricPath;

    if (request.writeLyricFile && request.lyricPath != null && downloadLyric != null) {
      try {
        lyricPath = await const LyricFileWriter().write(
          request.lyricPath!,
          downloadLyric,
          encoding: request.lyricEncoding,
        );
      } on Object catch (error) {
        MediaCoreLog.warning(
          LogCategory.error,
          'music lyric sidecar failed: ${request.lyricPath}',
          error: error,
        );
        updated = updated.copyWith(error: 'Lyric sidecar: $error');
      }
    }

    // The ffmpeg path already wrote tags in its single pass; only a direct
    // transfer needs the follow-up rewrite.
    if (request.isDirectTransfer && (request.embedCover || request.embedLyric)) {
      try {
        await _downloader.rewriteTags(request, lyric: downloadLyric);
      } on Object catch (error) {
        MediaCoreLog.warning(
          LogCategory.error,
          'music tag rewrite failed: ${request.outputPath}',
          error: error,
        );
        updated = updated.copyWith(error: 'Tags: $error');
      }
    }

    return updated.copyWith(
      status: MusicDownloadStatus.completed,
      finishedAt: DateTime.now(),
      lyricPath: lyricPath,
    );
  }

  /// Starts queued tasks while a slot is free.
  Future<void> _drain() async {
    if (_disposed) {
      return;
    }

    while (_running.length < maxConcurrent) {
      final next = _tasks.entries
          .where((entry) => entry.value.status == MusicDownloadStatus.queued && !_running.containsKey(entry.key))
          .map((entry) => entry.key)
          .firstOrNull;

      if (next == null) {
        return;
      }

      final completer = Completer<void>();

      _running[next] = completer;

      unawaited(
        _run(next).whenComplete(() {
          _running.remove(next);
          completer.complete();

          if (!_disposed) {
            unawaited(_drain());
          }
        }),
      );
    }
  }

  bool _isActive(String taskId, Object token) {
    return !_disposed &&
        !_paused.contains(taskId) &&
        !_abandoned.contains(taskId) &&
        identical(_inFlight[taskId], token);
  }

  MusicDownloadTask? _findDuplicate(MusicDownloadRequest request) {
    for (final task in _tasks.values) {
      if (!task.isTerminal && task.request.dedupeKey == request.dedupeKey) {
        return task;
      }
    }

    return null;
  }

  void _reportProgress(MusicDownloadTask task, int received, int total, {bool force = false}) {
    final current = _tasks[task.id];

    if (current == null || current.status != MusicDownloadStatus.running) {
      return;
    }

    final now = DateTime.now();
    final last = _lastProgressAt[task.id];

    if (!force && last != null && now.difference(last) < progressInterval) {
      return;
    }

    _lastProgressAt[task.id] = now;

    var speed = current.bytesPerSecond;
    final lastSpeedAt = _lastSpeedAt[task.id];
    final lastBytes = _lastSpeedBytes[task.id] ?? current.bytesReceived;

    if (lastSpeedAt == null) {
      _lastSpeedAt[task.id] = now;
      _lastSpeedBytes[task.id] = received;
    } else {
      final elapsed = now.difference(lastSpeedAt);

      if (elapsed.inMilliseconds >= 200) {
        speed = ((received - lastBytes) * 1000 / elapsed.inMilliseconds).round().clamp(0, 1 << 40);
        _lastSpeedAt[task.id] = now;
        _lastSpeedBytes[task.id] = received;
      }
    }

    _emit(
      current.copyWith(
        bytesReceived: received,
        bytesTotal: total > 0 ? total : current.bytesTotal,
        bytesPerSecond: speed,
      ),
    );
  }

  void _emit(MusicDownloadTask task) {
    if (_disposed) {
      return;
    }

    _tasks[task.id] = task;

    if (!_updates.isClosed) {
      _updates.add(task);
    }
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      await File(path).delete();
    } on Object catch (_) {
      // Nothing to delete is the common case; a failure here is not worth
      // failing the UI action that asked for it.
    }
  }

  /// Cancels everything and releases the downloader and transport.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    for (final task in pending) {
      _abandoned.add(task.id);
    }

    _disposed = true;

    for (final id in _running.keys.toList(growable: false)) {
      await _downloader.cancel(id);
    }

    _running.clear();
    _resolvers.clear();
    _inFlight.clear();
    _paused.clear();
    _abandoned.clear();

    await _downloader.dispose();
    await _transport.dispose();
    await _updates.close();
  }
}

/// A resumed file turned out not to be a prefix of the remote one.
final class _ResumeMismatch implements Exception {
  const _ResumeMismatch();

  @override
  String toString() => 'The partial file does not match the remote file.';
}
