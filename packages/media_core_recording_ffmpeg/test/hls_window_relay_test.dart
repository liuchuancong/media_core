import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_recording_ffmpeg/src/relay/hls_window_relay.dart';

/// A media playlist naming `count` segments from `first` on.
String _mediaPlaylist(int first, int count, {int target = 2, bool endlist = false}) {
  final out = StringBuffer('#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:$target\n#EXT-X-MEDIA-SEQUENCE:$first\n');
  for (var sequence = first; sequence < first + count; sequence++) {
    out
      ..writeln('#EXTINF:2.0,')
      ..writeln('seg$sequence.ts');
  }
  if (endlist) out.writeln('#EXT-X-ENDLIST');
  return out.toString();
}

/// One body per segment path, so a test can tell whose bytes came back.
Uint8List _segmentBody(String path) => Uint8List.fromList(utf8.encode('body of $path'));

/// Answers one registered body per URL and counts every URL it was asked for.
HlsWindowFetch _fetcher(Map<String, List<int>> bodies, {List<Uri>? requests, int status = 200}) {
  return (url) async {
    requests?.add(url);
    final body = bodies['$url'];
    if (body == null) {
      return (status: 404, url: url, body: const Stream<List<int>>.empty());
    }
    return (status: status, url: url, body: Stream<List<int>>.value(body));
  };
}

/// Waits until [condition] holds, for tests that drive real async downloads.
Future<void> _waitUntil(bool Function() condition, {Duration limit = const Duration(seconds: 10)}) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < limit) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// A stand-in CDN: `.m3u8` paths answer [playlist] (a new window per playlist
/// request, counted in order), everything else answers [segment] or 404.
/// Every request path is recorded.
Future<(HttpServer, List<String>)> _upstreamServer({
  required String Function(int served) playlist,
  Uint8List Function(String path)? segment,
}) async {
  final requests = <String>[];
  var served = 0;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      requests.add(request.uri.path);
      final response = request.response;
      if (request.uri.path.endsWith('.m3u8')) {
        final body = utf8.encode(playlist(served++));
        response
          ..statusCode = HttpStatus.ok
          ..contentLength = body.length
          ..add(body);
        await response.close();
        return;
      }
      final body = segment?.call(request.uri.path);
      if (body == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response
        ..statusCode = HttpStatus.ok
        ..contentLength = body.length
        ..add(body);
      await response.close();
    } on Object {
      try {
        await request.response.close();
      } on Object {
        // The reader already hung up.
      }
    }
  });
  return (server, requests);
}

Future<void> _closeServer(HttpServer server) async {
  try {
    await server.close(force: true);
  } on Object {
    // Already closed.
  }
}

/// GETs [url] and reads the whole answer back.
Future<({int statusCode, Uint8List body})> _get(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl('GET', url);
    final answer = await request.close();
    final builder = BytesBuilder();
    await answer.forEach(builder.add);
    return (statusCode: answer.statusCode, body: builder.takeBytes());
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('HlsRetainedWindow', () {
    final base = Uri.parse('http://up.test/live.m3u8');

    test('serves the playlist with its recording tags kept and low-latency tags dropped', () {
      final window = HlsRetainedWindow(source: base, fetch: _fetcher(const {}));
      const text = '''
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-TARGETDURATION:4
#EXT-X-MEDIA-SEQUENCE:10
#EXT-X-DISCONTINUITY-SEQUENCE:2
#EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES
#EXT-X-PART-INF:PART-TARGET=0.5
#EXT-X-CUSTOM:WHATEVER=YES
#EXT-X-MAP:URI="init.mp4"
#EXT-X-KEY:METHOD=AES-128,URI="keys/k1"
#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00Z
#EXTINF:4.0,
seg10.ts
#EXT-X-BITRATE:1200
#EXT-X-PART:DURATION=0.5,URI=part10.1.ts
#EXT-X-KEY:METHOD=AES-128,URI="keys/k2"
#EXT-X-KEY:METHOD=SAMPLE-AES,URI="keys/k2b",KEYFORMAT="com.apple"
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
seg11.ts
#EXTINF:4.0,
seg12.ts
''';

      final served = window.serve(text, base);

      expect(served, contains('#EXT-X-VERSION:6'));
      expect(served, contains('#EXT-X-INDEPENDENT-SEGMENTS'));
      expect(served, contains('#EXT-X-TARGETDURATION:4'));
      expect(served, contains('#EXT-X-MEDIA-SEQUENCE:10'));
      expect(served, contains('#EXT-X-DISCONTINUITY-SEQUENCE:2'));
      // References are absolute; keys and maps repeat only where they change.
      expect(served, contains('#EXT-X-MAP:URI="http://up.test/init.mp4"'));
      expect(served, contains('#EXT-X-KEY:METHOD=AES-128,URI="http://up.test/keys/k1"'));
      expect(served, contains('#EXT-X-KEY:METHOD=AES-128,URI="http://up.test/keys/k2"'));
      expect(served, contains('#EXT-X-KEY:METHOD=SAMPLE-AES,URI="http://up.test/keys/k2b",KEYFORMAT="com.apple"'));
      expect(served.indexOf('keys/k2'), lessThan(served.indexOf('seg11.ts')));
      expect(served, contains('#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00Z'));
      expect(served, contains('#EXT-X-BITRATE:1200'));
      // Unknown tags travel with their segment; low-latency parts are gone.
      expect(served, contains('#EXT-X-CUSTOM:WHATEVER=YES'));
      expect(served, contains('#EXT-X-DISCONTINUITY'));
      expect(served, contains('http://up.test/seg10.ts'));
      expect(served, contains('http://up.test/seg11.ts'));
      expect(served, contains('http://up.test/seg12.ts'));
      expect(served, isNot(contains('EXT-X-SERVER-CONTROL')));
      expect(served, isNot(contains('EXT-X-PART')));
    });

    test('a master playlist is not kept: it is served as it came', () {
      final window = HlsRetainedWindow(source: base, fetch: _fetcher(const {}));
      const master = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttp://up.test/v.m3u8\n';

      expect(window.serve(master, base), master);
      expect(window.prefetching, isFalse);
    });

    test('a delta playlist is not kept either', () {
      final window = HlsRetainedWindow(source: base, fetch: _fetcher(const {}));
      const delta = '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXT-X-SKIP:SKIPPED-SEGMENTS=3\n';

      expect(window.serve(delta, base), delta);
    });

    test('an expired segment the reader still needs stays listed', () async {
      final window = HlsRetainedWindow(source: base, fetch: _fetcher(const {}));
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        // Marks the segment delivered even though nothing was held yet.
        await window.take(Uri.parse('http://up.test/seg0.ts'));

        final served = window.serve(_mediaPlaylist(2, 4), base);

        // The upstream window starts at 2 now; the served one still starts
        // where the reader is, re-anchored.
        expect(served, contains('#EXT-X-MEDIA-SEQUENCE:0'));
        expect(served, contains('http://up.test/seg0.ts'));
        expect(served, contains('http://up.test/seg5.ts'));
        expect(served, isNot(contains('#EXT-X-ENDLIST')));
      } finally {
        window.close();
      }
    });

    test('segments the upstream window expired before the reader took them are marked as a gap', () async {
      final gaps = <HlsCoverageGap>[];
      final window = HlsRetainedWindow(
        limits: const HlsWindowLimits(maxSegments: 4),
        source: base,
        fetch: _fetcher(const {}),
        onCoverageGap: gaps.add,
      );
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        await window.take(Uri.parse('http://up.test/seg0.ts'));

        final served = window.serve(_mediaPlaylist(6, 4), base);

        expect(gaps, hasLength(1));
        expect(gaps.single.firstSequence, 1);
        expect(gaps.single.lastSequence, 3);
        expect(gaps.single.count, 3);
        expect(window.coverageGapSegments, 3);
        // And the served playlist jumps past the hole rather than hiding it.
        expect(served, contains('#EXT-X-MEDIA-SEQUENCE:6'));
        expect(served, isNot(contains('seg1.ts')));
      } finally {
        window.close();
      }
    });

    test('a sequence that goes back starts the window over', () {
      final window = HlsRetainedWindow(
        limits: const HlsWindowLimits(maxSegments: 4),
        source: base,
        fetch: _fetcher(const {}),
      );
      final expired = window.serve(_mediaPlaylist(100, 4), base);
      expect(expired, contains('#EXT-X-MEDIA-SEQUENCE:100'));

      final restarted = window.serve(_mediaPlaylist(0, 4), base);

      expect(window.knownSegments, 4);
      expect(restarted, contains('#EXT-X-MEDIA-SEQUENCE:0'));
      expect(restarted, isNot(contains('seg100.ts')));
    });

    test('keys are restated where the served window starts and closed where they end', () async {
      final window = HlsRetainedWindow(source: base, fetch: _fetcher(const {}));
      try {
        window.serve(
          '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:0\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="keys/k1"\n#EXTINF:2.0,\nseg0.ts\n',
          base,
        );
        await window.take(Uri.parse('http://up.test/seg0.ts'));

        final served = window.serve(_mediaPlaylist(1, 2), base);

        // The reader starts at the expired seg0: its key is restated there,
        // and the upstream playlist dropped the key after it, so the window
        // closes it for what follows.
        expect(served, contains('#EXT-X-MEDIA-SEQUENCE:0'));
        expect(served, contains('#EXT-X-KEY:METHOD=AES-128,URI="http://up.test/keys/k1"'));
        expect(served, contains('#EXT-X-KEY:METHOD=NONE'));
      } finally {
        window.close();
      }
    });

    test('prefetch downloads segments ahead of the reader and holds them', () async {
      final bodies = <String, List<int>>{};
      for (var sequence = 0; sequence < 8; sequence++) {
        bodies['http://up.test/seg$sequence.ts'] = _segmentBody('seg$sequence');
      }
      final requests = <Uri>[];
      final window = HlsRetainedWindow(
        source: base,
        fetch: _fetcher(bodies, requests: requests),
      );
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        expect(window.prefetching, isFalse, reason: 'a first read says nothing about a reader that stays');
        await window.take(Uri.parse('http://up.test/seg0.ts'));
        window.serve(_mediaPlaylist(0, 4), base);

        expect(window.prefetching, isTrue);
        await _waitUntil(() => window.heldSegments >= 3);

        final bytes = await window.take(Uri.parse('http://up.test/seg1.ts'));
        expect(bytes, _segmentBody('seg1'));
        expect(window.heldBytes, greaterThan(0));
        expect(requests.where((url) => '$url'.endsWith('seg1.ts')), hasLength(1), reason: 'one fetch, by the prefetch');
        expect(window.coverageGapSegments, 0);
      } finally {
        window.close();
      }
    });

    test('a byte budget spent stops the prefetch: the rest is left to the reader', () async {
      final bodies = <String, List<int>>{};
      for (var sequence = 0; sequence < 8; sequence++) {
        bodies['http://up.test/seg$sequence.ts'] = _segmentBody('seg$sequence');
      }
      final requests = <Uri>[];
      // One download at a time, so the budget is read between them.
      final window = HlsRetainedWindow(
        limits: const HlsWindowLimits(maxBytes: 8, concurrency: 1),
        source: base,
        fetch: _fetcher(bodies, requests: requests),
      );
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        await window.take(Uri.parse('http://up.test/seg0.ts'));
        window.serve(_mediaPlaylist(0, 4), base);

        // One segment fits the budget; the next would exceed it, so nothing
        // else is held while it stays undelivered.
        await _waitUntil(() => window.heldBytes >= _segmentBody('seg1').length);

        expect(window.heldSegments, 1);
        expect(
          requests.where((url) => '$url'.endsWith('seg2.ts')),
          isEmpty,
          reason: 'the engine fetches what the window does not hold',
        );
        expect(requests.where((url) => '$url'.endsWith('seg3.ts')), isEmpty);
        expect(
          await window.take(Uri.parse('http://up.test/seg1.ts')),
          isNotNull,
          reason: 'the held one is served from memory',
        );
      } finally {
        window.close();
      }
    });

    test('a segment larger than the per-segment cap is not held either', () async {
      final bodies = <String, List<int>>{
        'http://up.test/seg0.ts': _segmentBody('seg0'),
        'http://up.test/seg1.ts': Uint8List.fromList(List<int>.filled(64, 1)),
      };
      final requests = <Uri>[];
      final window = HlsRetainedWindow(
        limits: const HlsWindowLimits(maxSegmentBytes: 8),
        source: base,
        fetch: _fetcher(bodies, requests: requests),
      );
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        await window.take(Uri.parse('http://up.test/seg0.ts'));
        window.serve(_mediaPlaylist(0, 4), base);

        // take() waits for the in-flight download: the oversized one aborts
        // and the reader fetches it itself.
        expect(await window.take(Uri.parse('http://up.test/seg1.ts')), isNull);
        expect(window.heldBytes, 0);
        expect(requests.where((url) => '$url'.endsWith('seg1.ts')), hasLength(1));
      } finally {
        window.close();
      }
    });

    test('polls without a reader stop the prefetch', () async {
      final bodies = <String, List<int>>{};
      for (var sequence = 0; sequence < 8; sequence++) {
        bodies['http://up.test/seg$sequence.ts'] = _segmentBody('seg$sequence');
      }
      bodies['http://up.test/live.m3u8'] = utf8.encode(_mediaPlaylist(0, 4));
      final window = HlsRetainedWindow(
        limits: const HlsWindowLimits(idlePolls: 1),
        source: base,
        fetch: _fetcher(bodies),
      );
      try {
        window.serve(_mediaPlaylist(0, 4), base);
        await window.take(Uri.parse('http://up.test/seg0.ts'));
        window.serve(_mediaPlaylist(0, 4), base);

        expect(window.prefetching, isTrue);
        await _waitUntil(() => !window.prefetching, limit: const Duration(seconds: 15));

        // The held bodies went with it; the listing stays for a returning
        // reader.
        expect(window.heldBytes, 0);
        expect(window.knownSegments, greaterThan(0));
      } finally {
        window.close();
      }
    });
  });

  group('RecordingHlsWindowRelay', () {
    test('serves the playlist through the window and passes unheld segments upstream', () async {
      final (upstream, requests) = await _upstreamServer(playlist: (_) => _mediaPlaylist(0, 4), segment: _segmentBody);
      addTearDown(() => _closeServer(upstream));
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const <String, String>{'referer': 'https://room.test/'},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);

      final answer = await _get(r.localUrl);

      expect(answer.statusCode, 200);
      final text = utf8.decode(answer.body);
      expect(text, contains('#EXT-X-MEDIA-SEQUENCE:0'));
      expect(text, contains('#EXTINF:2.0,'));
      // Segment URLs point back here; the upstream names are gone from them.
      final segmentUrl = Uri.parse(text.split('\n').firstWhere((line) => line.endsWith('.ts')));
      expect(segmentUrl.host, '127.0.0.1');
      expect(segmentUrl.port, r.localUrl.port);
      expect(text, isNot(contains('seg0.ts')));

      final segmentAnswer = await _get(segmentUrl);
      expect(segmentAnswer.statusCode, 200);
      expect(segmentAnswer.body, _segmentBody('/seg0.ts'));
      expect(requests.where((path) => path.endsWith('/seg0.ts')), hasLength(1), reason: 'one pass-through upstream');
    });

    test('a segment the window holds is answered from memory', () async {
      final (upstream, _) = await _upstreamServer(playlist: (_) => _mediaPlaylist(0, 4), segment: _segmentBody);
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const {},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);
      addTearDown(() => _closeServer(upstream));

      await _get(r.localUrl);
      final playlist = utf8.decode((await _get(r.localUrl)).body);
      final first = Uri.parse(playlist.split('\n').firstWhere((line) => line.endsWith('.ts')));
      await _get(first);
      await _get(r.localUrl);

      // The reader reloaded after taking a segment, so the window prefetches
      // the rest of the upstream window.
      await _waitUntil(() => r.heldSegments >= 3);
      await _closeServer(upstream);

      // With the CDN gone, only a held segment can still be answered.
      final last = Uri.parse(playlist.split('\n').lastWhere((line) => line.endsWith('.ts')));
      final answer = await _get(last);
      expect(answer.statusCode, 200, reason: 'a held segment needs no upstream');
      expect(answer.body, _segmentBody('/seg3.ts'));
      expect(r.heldBytes, greaterThan(0));
    });

    test('a window that slid past untaken segments is reported as a coverage gap', () async {
      final (upstream, _) = await _upstreamServer(playlist: (served) => _mediaPlaylist(served * 8, 4));
      addTearDown(() => _closeServer(upstream));
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const {},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);

      // Nine windows eight segments apart, none of them read: the retention
      // cap is passed early on, and the gaps are counted, not lost silently.
      for (var round = 0; round < 9; round++) {
        expect((await _get(r.localUrl)).statusCode, 200);
      }

      expect(r.coverageGaps, greaterThan(0));
    });

    test('after closeInput the playlist ends and held segments stay servable', () async {
      final (upstream, _) = await _upstreamServer(playlist: (_) => _mediaPlaylist(0, 4), segment: _segmentBody);
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const {},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);
      addTearDown(() => _closeServer(upstream));

      await _get(r.localUrl);
      await _get(r.localUrl);
      final first = Uri.parse(
        utf8.decode((await _get(r.localUrl)).body).split('\n').firstWhere((line) => line.endsWith('.ts')),
      );
      await _get(first);
      await _get(r.localUrl);
      await _waitUntil(() => r.heldSegments >= 3);
      await _closeServer(upstream);

      await r.closeInput();

      final answer = await _get(r.localUrl);
      expect(answer.statusCode, 200);
      final text = utf8.decode(answer.body);
      expect(text, endsWith('#EXT-X-ENDLIST\n'));
      expect(
        text,
        contains('#EXT-X-MEDIA-SEQUENCE:0'),
        reason: 'the last window served is what the reader drains through',
      );
      // A reload that comes again is answered with the same end.
      expect((await _get(r.localUrl)).statusCode, 200);

      final last = Uri.parse(text.split('\n').lastWhere((line) => line.endsWith('.ts')));
      final segmentAnswer = await _get(last);
      expect(segmentAnswer.statusCode, 200, reason: 'a held segment stays servable through the drain');
      expect(segmentAnswer.body, _segmentBody('/seg3.ts'));
    });

    test('a master playlist is answered as it came', () async {
      const master = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttp://upstream.test/v.m3u8\n';
      final (upstream, _) = await _upstreamServer(playlist: (_) => master);
      addTearDown(() => _closeServer(upstream));
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const {},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);

      final answer = await _get(r.localUrl);

      expect(answer.statusCode, 200);
      expect(utf8.decode(answer.body), master);
    });

    test('a segment the playlist never named is refused', () async {
      final (upstream, _) = await _upstreamServer(playlist: (_) => _mediaPlaylist(0, 4), segment: _segmentBody);
      addTearDown(() => _closeServer(upstream));
      final relay = await RecordingHlsWindowRelay.start(
        upstream: Uri.parse('http://127.0.0.1:${upstream.port}/live.m3u8'),
        headers: const {},
      );
      expect(relay, isNotNull);
      final r = relay!;
      addTearDown(r.stop);

      final answer = await _get(r.localUrl.resolve('guess.ts'));

      expect(answer.statusCode, 404, reason: 'the relay is not an open proxy');
    });
  });
}
