import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/src/download/hls_playlist.dart';

const String _playlist = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:10
#EXT-X-MAP:URI="init.mp4?a=1"
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:9.5,
segment_0.ts
#EXTINF:10.0,
../audio/segment_1.aac
#EXT-X-ENDLIST
''';

void main() {
  group('HlsMediaPlaylist', () {
    test('resolves segments, durations and the init segment', () {
      final playlist = HlsMediaPlaylist.parse(_playlist, Uri.parse('https://cdn.example.com/music/list/index.m3u8'));

      expect(playlist, isNotNull);
      expect(playlist!.segments, hasLength(2));
      expect(playlist.segments.first.uri.toString(), 'https://cdn.example.com/music/list/segment_0.ts');
      expect(playlist.segments.first.duration, const Duration(milliseconds: 9500));
      expect(playlist.segments.last.uri.toString(), 'https://cdn.example.com/music/audio/segment_1.aac');
      expect(playlist.duration, const Duration(milliseconds: 19500));
      expect(playlist.isLive, isFalse);
      expect(playlist.initUri.toString(), 'https://cdn.example.com/music/list/init.mp4?a=1');
    });

    test('a playlist without ENDLIST is live', () {
      final playlist = HlsMediaPlaylist.parse(
        '#EXTM3U\n#EXTINF:4,\na.ts\n#EXTINF:4,\nb.ts\n',
        Uri.parse('https://cdn.example.com/live/index.m3u8'),
      );

      expect(playlist, isNotNull);
      expect(playlist!.isLive, isTrue);
    });

    test('rejects text with no segments', () {
      expect(HlsMediaPlaylist.parse('#EXTM3U\n#EXT-X-ENDLIST\n', Uri.parse('https://a/b.m3u8')), isNull);
    });
  });

  group('HlsMasterPlaylist', () {
    const master = '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"\n'
        'low/index.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=320000,CODECS="mp4a.40.2"\n'
        'high/index.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=999000,CODECS="flac"\n'
        'flac/index.m3u8\n';

    final base = Uri.parse('https://cdn.example.com/music/master.m3u8');

    test('reads variants in playlist order', () {
      final playlist = HlsMasterPlaylist.parse(master, base);

      expect(playlist, isNotNull);
      expect(playlist!.variants.map((variant) => variant.bandwidth), <int>[128000, 320000, 999000]);
      expect(playlist.variants.last.uri.toString(), 'https://cdn.example.com/music/flac/index.m3u8');
    });

    test('picks the smallest adequate variant for a quality', () {
      final playlist = HlsMasterPlaylist.parse(master, base)!;

      expect(playlist.choose('192k').bandwidth, 320000);
      expect(playlist.choose('320k').bandwidth, 320000);
      expect(playlist.choose('flac').bandwidth, 999000);
      expect(playlist.choose(null).bandwidth, 999000);
    });

    test('rejects text with no variants', () {
      expect(HlsMasterPlaylist.parse('#EXTM3U\n', base), isNull);
    });
  });

  group('rewriteHlsPlaylist', () {
    test('points segments and init at cached files and keeps other URIs absolute', () {
      final rewritten = rewriteHlsPlaylist(
        _playlist,
        base: Uri.parse('https://cdn.example.com/music/list/index.m3u8'),
        segmentPaths: <String>[r'C:\cache\seg_00000.ts', r'C:\cache\seg_00001.aac'],
        initPath: r'C:\cache\init.mp4',
      );

      expect(rewritten, contains(Uri.file(r'C:\cache\init.mp4').toString()));
      expect(rewritten, contains(Uri.file(r'C:\cache\seg_00000.ts').toString()));
      expect(rewritten, contains(Uri.file(r'C:\cache\seg_00001.aac').toString()));
      expect(rewritten, contains('URI="https://cdn.example.com/music/list/key.bin"'));
      expect(rewritten, isNot(contains('segment_0.ts')));
      expect(rewritten, contains('#EXT-X-ENDLIST'));
    });
  });

  group('completedHlsSegments', () {
    late Directory cache;

    setUp(() async {
      cache = await Directory.systemTemp.createTemp('hls_cache_');
    });

    tearDown(() async {
      if (cache.existsSync()) {
        await cache.delete(recursive: true);
      }
    });

    test('counts only segments whose final file exists and holds bytes', () async {
      final playlist = HlsMediaPlaylist.parse(_playlist, Uri.parse('https://cdn.example.com/music/list/index.m3u8'))!;

      await File(segmentCachePath(cache.path, 0, playlist.segments[0].uri)).writeAsBytes(<int>[1, 2, 3]);
      await File(segmentCachePath(cache.path, 1, playlist.segments[1].uri)).writeAsBytes(<int>[]);
      // A half-written segment lives under `.part` and must not count.
      await File('${segmentCachePath(cache.path, 1, playlist.segments[1].uri)}.part').writeAsBytes(<int>[9]);

      expect(await completedHlsSegments(cache.path, playlist.segments), <int>{0});
    });

    test('cache paths keep the segment extension', () {
      expect(
        segmentCachePath('/cache', 7, Uri.parse('https://cdn.example.com/a/seg.aac?sig=1')),
        '/cache/seg_00007.aac',
      );
      expect(
        segmentCachePath('/cache', 0, Uri.parse('https://cdn.example.com/a/seg')),
        '/cache/seg_00000.ts',
      );
      expect(initCachePath('/cache', Uri.parse('https://cdn.example.com/a/init.mp4')), '/cache/init.mp4');
    });
  });
}
