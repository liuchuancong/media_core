import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart';

/// In-memory destination file store.
final class _MemorySink implements DownloadFileSink {
  final Map<String, List<int>> files = <String, List<int>>{};

  @override
  Future<void> append(String path, List<int> bytes) async {
    files.putIfAbsent(path, () => <int>[]).addAll(bytes);
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> ensureParentDirectory(String path) async {}

  @override
  Future<int> length(String path) async => files[path]?.length ?? 0;

  @override
  Future<List<int>> readTail(String path, int count) async {
    final bytes = files[path] ?? const <int>[];

    if (count <= 0 || bytes.length < count) {
      return const <int>[];
    }

    return bytes.sublist(bytes.length - count);
  }

  @override
  Future<void> truncate(String path, int length) async {
    final bytes = files[path] ?? const <int>[];

    files[path] = bytes.take(length).toList();
  }
}

/// Serves in-memory bytes, optionally pausing between the first and second
/// chunk so a test can freeze a transfer mid-file.
final class _MemoryTransport implements DownloadTransport {
  _MemoryTransport(this.bytes, {this.gate});

  final List<int> bytes;
  final Completer<void>? gate;
  static const int chunkSize = 12;
  final List<DownloadRequest> requests = <DownloadRequest>[];

  @override
  Future<DownloadResponse> fetch(DownloadRequest request) async {
    requests.add(request);
    final start = request.startByte;
    final body = start == 0 ? bytes : bytes.sublist(start);

    return DownloadResponse(
      statusCode: start == 0 ? 200 : 206,
      byteStream: _stream(body),
      contentLength: body.length,
      totalBytes: bytes.length,
      acceptsRanges: true,
    );
  }

  Stream<List<int>> _stream(List<int> body) async* {
    for (var offset = 0; offset < body.length; offset += chunkSize) {
      if (offset > 0 && gate != null) {
        await gate!.future;
      }

      yield body.sublist(offset, (offset + chunkSize).clamp(0, body.length));
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('MusicDownloadRequest', () {
    final source = TrackSource(uri: Uri.parse('https://cdn.example.com/song.mp3'));
    const track = MusicTrack(id: 't1', sourceId: 'qq', title: '夜曲', artist: '周杰伦', album: '十一月的萧邦');

    test('copies a finished container and keeps its extension', () {
      final request = MusicDownloadRequest.forTrack(
        track: track,
        source: source,
        directory: '/music',
        quality: MusicQuality.k320,
      );

      expect(request.format, MusicDownloadFormat.copy);
      expect(request.extension, 'mp3');
      expect(request.outputPath, '/music/周杰伦 - 夜曲.mp3');
      expect(request.isDirectTransfer, isTrue);
    });

    test('uses the quality hint when the source is a stream', () {
      final request = MusicDownloadRequest.forTrack(
        track: track,
        source: TrackSource(uri: Uri.parse('https://cdn.example.com/song.m3u8')),
        directory: '/music',
        quality: MusicQuality.flac,
      );

      expect(request.format, MusicDownloadFormat.flac);
      expect(request.extension, 'flac');
      expect(request.isDirectTransfer, isFalse);
    });

    test('supports list folders, placeholders and path traversal defence', () {
      final request = MusicDownloadRequest.forTrack(
        track: track,
        source: source,
        directory: '/music',
        subdirectory: '../我的歌单',
        pattern: '{list}/{index} {artist} - {title}',
        listName: '收藏',
        index: 3,
      );

      expect(request.outputPath, '/music/我的歌单/收藏_03 周杰伦 - 夜曲.mp3');
    });

    test('survives a JSON round trip', () {
      final request = MusicDownloadRequest.forTrack(
        track: track,
        source: source,
        directory: '/music',
        writeLyricFile: true,
        lyric: const MusicLyricPayload(lyric: '[00:01.00]hello'),
      );

      final restored = MusicDownloadRequest.fromJson(request.toJson());

      expect(restored.outputPath, request.outputPath);
      expect(restored.lyric, '[00:01.00]hello');
      expect(restored.writeLyricFile, isTrue);
      expect(restored.dedupeKey, request.dedupeKey);
    });
  });

  test('an unfinished task is restored as paused', () {
    final task = MusicDownloadTask(
      id: 'task',
      request: _request(),
      status: MusicDownloadStatus.running,
      bytesReceived: 5,
      bytesTotal: 10,
      attempt: 2,
    );

    final restored = MusicDownloadTask.fromJson(task.toJson());

    expect(restored.id, 'task');
    expect(restored.status, MusicDownloadStatus.paused);
    expect(restored.bytesReceived, 5);
    expect(restored.bytesTotal, 10);
    expect(restored.attempt, 2);
    expect(restored.request.dedupeKey, task.request.dedupeKey);
  });

  group('MusicDownloader tags', () {
    test('builds attached-cover and lyric arguments without touching the audio codec', () {
      const request = MusicDownloadRequest(
        url: 'https://cdn.example.com/a.mp3',
        outputPath: '/music/a.mp3',
        extension: 'mp3',
        title: 'A',
        artist: 'B',
        album: 'C',
        coverUrl: 'https://cdn.example.com/a.jpg',
        lyric: '[00:01.00]hello',
        embedCover: true,
        embedLyric: true,
      );

      final arguments = MusicDownloader().buildTagArguments(
        request,
        inputPath: '/music/a.mp3',
        outputPath: '/music/a.tmp.mp3',
      );

      expect(arguments, containsAllInOrder(<String>['-i', '/music/a.mp3']));
      expect(arguments, contains('https://cdn.example.com/a.jpg'));
      expect(arguments, contains('attached_pic'));
      expect(arguments, contains('lyrics=[00:01.00]hello'));
      expect(arguments, containsAllInOrder(<String>['-c:a', 'copy']));
    });
  });

  group('MusicDownloadQueue', () {
    final bytes = List<int>.generate(24, (index) => index);

    test('downloads a direct file to completion', () async {
      final sink = _MemorySink();
      final transport = _MemoryTransport(bytes);
      final queue = MusicDownloadQueue(transport: transport, files: sink);

      try {
        final task = queue.enqueue(_request());

        await _until(() => queue.task(task.id)?.isCompleted ?? false);

        expect(sink.files['/music/song.mp3'], bytes);
        expect(queue.task(task.id)?.progress, 1);
        expect(transport.requests.single.startByte, 0);
      } finally {
        await queue.dispose();
      }
    });

    test('skips an existing file instead of transferring over it', () async {
      final sink = _MemorySink()..files['/music/song.mp3'] = List<int>.filled(24, 7);
      final transport = _MemoryTransport(bytes);
      final queue = MusicDownloadQueue(transport: transport, files: sink);

      try {
        final task = queue.enqueue(_request(skipExisting: true));

        await _until(() => queue.task(task.id)?.isTerminal ?? false);

        expect(queue.task(task.id)?.status, MusicDownloadStatus.skipped);
        expect(transport.requests, isEmpty);
        expect(sink.files['/music/song.mp3'], List<int>.filled(24, 7));
      } finally {
        await queue.dispose();
      }
    });

    test('deduplicates the same track, quality and container', () async {
      final sink = _MemorySink();
      final queue = MusicDownloadQueue(transport: _MemoryTransport(bytes), files: sink);

      try {
        final first = queue.enqueue(_request(), dedupe: true);
        final second = queue.enqueue(_request(), dedupe: true);

        expect(first.isTerminal, isFalse);
        expect(second.request.dedupeKey, first.request.dedupeKey);
        expect(second.id, first.id);
        expect(queue.tasks, hasLength(1));

        await _until(() => queue.task(first.id)?.isTerminal ?? false);
      } finally {
        await queue.dispose();
      }
    });

    test('resumes a partial file after verifying its tail', () async {
      final sink = _MemorySink()..files['/music/song.mp3'] = bytes.sublist(0, 12);
      final transport = _MemoryTransport(bytes);
      final queue = MusicDownloadQueue(transport: transport, files: sink);

      try {
        queue.restore(<MusicDownloadTask>[
          MusicDownloadTask(
            id: 'resume',
            request: _request(),
            status: MusicDownloadStatus.paused,
            bytesReceived: 12,
          ),
        ]);

        await queue.resume('resume');
        await _until(() => queue.task('resume')?.isTerminal ?? false);

        // The tail check re-fetches the last 10 bytes of the partial file.
        expect(transport.requests.single.startByte, 2);
        expect(queue.task('resume')?.status, MusicDownloadStatus.completed);
        expect(sink.files['/music/song.mp3'], bytes);
      } finally {
        await queue.dispose();
      }
    });

    test('writes the sidecar lyric with translation after the transfer', () async {
      final directory = await Directory.systemTemp.createTemp('music-download-');
      final transport = _MemoryTransport(bytes);
      final queue = MusicDownloadQueue(transport: transport);

      try {
        final request = MusicDownloadRequest(
          url: 'https://cdn.example.com/song.mp3',
          outputPath: '${directory.path}/song.mp3',
          extension: 'mp3',
          writeLyricFile: true,
          lyric: '[00:01.00]hello\n[00:02.00]world',
          lyricTranslation: '[00:01.00]你好\n[00:02.00]世界',
          includeTranslation: true,
        );
        final task = queue.enqueue(request);

        await _until(() => queue.task(task.id)?.isTerminal ?? false);

        final lyricFile = File('${directory.path}/song.lrc');
        final text = utf8.decode((await lyricFile.readAsBytes()).skip(3).toList());

        expect(queue.task(task.id)?.status, MusicDownloadStatus.completed);
        expect(queue.task(task.id)?.lyricPath, lyricFile.path);
        expect(text, contains('[00:01.00]hello'));
        expect(text, contains('[00:01.00]你好'));
      } finally {
        await queue.dispose();
        await directory.delete(recursive: true);
      }
    });

    test('pause keeps the partial file and resume finishes it', () async {
      final sink = _MemorySink();
      final gate = Completer<void>();
      final transport = _MemoryTransport(bytes, gate: gate);
      final queue = MusicDownloadQueue(transport: transport, files: sink);

      try {
        final task = queue.enqueue(_request());

        await _until(() => (queue.task(task.id)?.bytesReceived ?? 0) >= 12);
        await queue.pause(task.id);

        expect(queue.task(task.id)?.status, MusicDownloadStatus.paused);
        expect(sink.files['/music/song.mp3'], bytes.sublist(0, 12));

        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await queue.resume(task.id);
        await _until(() => queue.task(task.id)?.isTerminal ?? false);

        expect(queue.task(task.id)?.status, MusicDownloadStatus.completed);
        expect(sink.files['/music/song.mp3'], bytes);
      } finally {
        await queue.dispose();
      }
    });
  });
}

MusicDownloadRequest _request({bool skipExisting = false}) {
  return MusicDownloadRequest(
    url: 'https://cdn.example.com/song.mp3',
    outputPath: '/music/song.mp3',
    extension: 'mp3',
    title: 'Song',
    artist: 'Artist',
    sourceId: 'qq',
    trackId: 't1',
    qualityId: '320k',
    skipExisting: skipExisting,
  );
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 400; attempt++) {
    if (condition()) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  fail('condition was not met');
}
