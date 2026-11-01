import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

void main() {
  group('HttpByteRange', () {
    const size = 1000;

    test('bytes=0-9 resolves to the first ten bytes', () {
      final outcome = HttpByteRange.parse('bytes=0-9', size);

      final range = outcome.range!;
      expect(range.start, 0);
      expect(range.end, 9);
      expect(range.length, 10);
      expect(range.contentRange(size), 'bytes 0-9/1000');
      expect(range.sliceStart, 0);
      expect(range.sliceEnd, 10, reason: 'openRead takes an exclusive end');
    });

    test('bytes=990- clamps to the resource end', () {
      final range = HttpByteRange.parse('bytes=990-', size).range!;

      expect(range.start, 990);
      expect(range.end, 999);
    });

    test('bytes=-5 asks for the last five bytes', () {
      final range = HttpByteRange.parse('bytes=-5', size).range!;

      expect(range.start, 995);
      expect(range.end, 999);
    });

    test('an oversized end clamps to the last byte', () {
      final range = HttpByteRange.parse('bytes=10-99999', size).range!;

      expect(range.end, 999);
    });

    test('a start past the resource is unsatisfiable', () {
      expect(HttpByteRange.parse('bytes=1000-', size).isUnsatisfiable, isTrue);
      expect(HttpByteRange.parse('bytes=-0', size).isUnsatisfiable, isTrue);
      expect(HttpByteRange.parse('bytes=-0', size).range, isNull);
    });

    test('no header, foreign units and multipart ranges mean "serve all"', () {
      expect(HttpByteRange.parse(null, size).isAbsent, isTrue);
      expect(HttpByteRange.parse('items=0-5', size).isAbsent, isTrue);
      expect(HttpByteRange.parse('bytes=0-9,20-29', size).isAbsent, isTrue);
      expect(HttpByteRange.parse('bytes=abc-def', size).isAbsent, isTrue);
    });
  });

  group('MimeType', () {
    test('maps common media extensions and falls back to octet-stream', () {
      expect(MimeType.forPath('C:/Movies/第五集.MP4'), 'video/mp4');
      expect(MimeType.forPath('http://x/a.mkv?token=1'), 'video/x-matroska');
      expect(MimeType.forPath('/music/song.flac'), 'audio/flac');
      expect(MimeType.forPath('/unknown.zzz'), 'application/octet-stream');
      expect(MimeType.forPath('/no-extension'), 'application/octet-stream');
    });
  });

  group('MediaHttpServer', () {
    late MediaHttpServer server;
    late File file;
    final bytes = List<int>.generate(1000, (i) => i % 251);

    Future<HttpClientResponse> get(Uri url, {String? range, String method = 'GET'}) async {
      final client = HttpClient();
      final request = await client.openUrl(method, url);
      if (range != null) {
        request.headers.set(HttpHeaders.rangeHeader, range);
      }
      final response = await request.close();
      // Detach the client from the response so a test may read it
      // lazily; closing the pooled client later keeps sockets tidy.
      Future<void>.delayed(const Duration(seconds: 5), client.close);
      return response;
    }

    setUpAll(() async {
      file = File(
        '${Directory.systemTemp.path}/media_core_cast_dlna_test_${DateTime.now().microsecondsSinceEpoch}.bin',
      );
      await file.writeAsBytes(bytes);
    });

    tearDownAll(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    setUp(() async {
      server = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);
      await server.start();
    });

    tearDown(() => server.stop());

    test('lifecycle: start is idempotent, stop releases the port', () async {
      expect(server.state, MediaServerState.running);
      final port = server.boundPort;
      expect(port, isNotNull);
      expect(server.address, InternetAddress.loopbackIPv4);

      await server.start();
      expect(server.boundPort, port, reason: 'a second start must not rebind');

      await server.stop();
      expect(server.state, MediaServerState.stopped);
      expect(server.boundPort, isNull);

      await server.stop();
      expect(server.state, MediaServerState.stopped);
    });

    test('a registered file is served whole, with range headers', () async {
      final url = await server.registerFile(file);
      expect(url.host, '127.0.0.1');
      expect(url.port, server.boundPort);
      expect(url.pathSegments, hasLength(2), reason: 'token/id, nothing else');

      final response = await get(url);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(response.headers.contentType?.mimeType, 'application/octet-stream');
      expect(await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b)), bytes);
    });

    test('registered MIME type wins over the extension guess', () async {
      final url = await server.registerFile(file, mimeType: 'video/mp4');

      final response = await get(url);

      expect(response.headers.contentType?.mimeType, 'video/mp4');
    });

    test('byte ranges come back as 206 with the exact slice', () async {
      final url = await server.registerFile(file);

      final head = await get(url, range: 'bytes=100-109');
      expect(head.statusCode, HttpStatus.partialContent);
      expect(head.headers.value(HttpHeaders.contentRangeHeader), 'bytes 100-109/1000');
      expect(head.headers.contentLength, 10);
      final slice = await head.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(slice, bytes.sublist(100, 110));

      final tail = await get(url, range: 'bytes=990-');
      final tailBytes = await tail.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(tailBytes, bytes.sublist(990));

      final suffix = await get(url, range: 'bytes=-5');
      final suffixBytes = await suffix.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(suffixBytes, bytes.sublist(995));
    });

    test('a start past the file answers 416 with the size', () async {
      final url = await server.registerFile(file);

      final response = await get(url, range: 'bytes=1000-');

      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.headers.value(HttpHeaders.contentRangeHeader), 'bytes */1000');
    });

    test('HEAD carries the headers without a body', () async {
      final url = await server.registerFile(file);

      final response = await get(url, method: 'HEAD');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentLength, 1000);
      expect(await response.fold<int>(0, (sum, chunk) => sum + chunk.length), 0);
    });

    test('a wrong token, a wrong id and a stray path all 404 identically', () async {
      final url = await server.registerFile(file);
      final segments = url.pathSegments;

      final wrongToken = url.replace(pathSegments: <String>['0' * 32, segments.last]);
      final wrongId = url.replace(pathSegments: <String>[segments.first, 'deadbeef']);
      final stray = url.replace(pathSegments: <String>['..', 'etc', 'passwd']);

      for (final candidate in <Uri>[wrongToken, wrongId, stray]) {
        final response = await get(candidate);
        expect(response.statusCode, HttpStatus.notFound, reason: '$candidate must 404');
      }
    });

    test('an expired registration stops being served', () async {
      final url = await server.registerFile(file, ttl: const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final response = await get(url);

      expect(response.statusCode, HttpStatus.notFound);
      expect(server.resourceCount, 0, reason: 'the lookup sweeps the expired registration');
    });

    test('unregister is idempotent and unknown urls are ignored', () async {
      final url = await server.registerFile(file);

      server
        ..unregister(url)
        ..unregister(url);
      expect(server.resourceCount, 0);

      final response = await get(url);
      expect(response.statusCode, HttpStatus.notFound);
    });

    test('several renderers can pull ranges concurrently', () async {
      final url = await server.registerFile(file);

      final responses = await Future.wait(<Future<HttpClientResponse>>[
        get(url, range: 'bytes=0-99'),
        get(url, range: 'bytes=100-199'),
        get(url, range: 'bytes=200-299'),
      ]);
      final slices = await Future.wait(responses.map((r) => r.fold<List<int>>(<int>[], (a, b) => a..addAll(b))));

      expect(slices[0], bytes.sublist(0, 100));
      expect(slices[1], bytes.sublist(100, 200));
      expect(slices[2], bytes.sublist(200, 300));
    });

    test('a client that walks away mid-stream does not hurt the next one', () async {
      final url = await server.registerFile(file);

      // Start reading and slam the connection shut mid-stream.
      final first = await get(url, range: 'bytes=0-999');
      final subscription = first.listen((_) {});
      await subscription.cancel();

      final second = await get(url, range: 'bytes=0-9');
      expect(second.statusCode, HttpStatus.partialContent);
      final body = await second.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(body, hasLength(10));
    });

    test('commands before start are refused, not silently broken', () async {
      final idle = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);

      await expectLater(idle.registerFile(file), throwsA(isA<MediaServerException>()));
      await idle.stop();
    });
  });
}
