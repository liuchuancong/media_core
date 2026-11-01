import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

void main() {
  late HttpServer upstream;
  late MediaHttpServer server;
  final upstreamRequests = <({String method, String? range, Map<String, String> headers, String path})>[];

  /// The upstream "origin": serves [payload] with [status], records
  /// every request, and answers Range with 206 + Content-Range.
  void serveOrigin({
    int status = 200,
    String contentType = 'video/mp4',
    List<int> payload = const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    bool honorRange = true,
  }) {
    upstreamRequests.clear();
    upstream.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      upstreamRequests.add((
        method: request.method,
        range: range,
        headers: <String, String>{
          'user-agent': request.headers.value('user-agent') ?? '',
          'referer': request.headers.value('referer') ?? '',
        },
        path: request.uri.path,
      ));
      if (status != 200 && status != 206) {
        request.response.statusCode = status;
        await request.response.close();
        return;
      }
      if (range != null && honorRange) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final end = match.group(2)!.isEmpty ? payload.length - 1 : int.parse(match.group(2)!);
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${payload.length}');
          request.response.add(payload.sublist(start, end + 1));
          await request.response.close();
          return;
        }
      }
      request.response.headers.contentType = ContentType.parse(contentType);
      request.response.add(payload);
      await request.response.close();
    }, onError: (Object _) {});
  }

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);
    await server.start();
  });

  tearDown(() async {
    await upstream.close(force: true);
    await server.stop();
  });

  test('a remote registration streams through with headers and range', () async {
    serveOrigin();
    final upstreamUri = Uri.parse('http://127.0.0.1:${upstream.port}/video/stream.mp4');
    final proxyUrl = await server.registerRemote(
      upstreamUri,
      upstreamHeaders: const {'User-Agent': 'pure_live/1.0', 'Referer': 'https://live.example/'},
    );

    final client = HttpClient();
    final request = await client.getUrl(proxyUrl);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=2-5');
    final response = await request.close();

    expect(response.statusCode, HttpStatus.partialContent);
    final body = await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    expect(body, <int>[2, 3, 4, 5]);

    // The upstream saw the forwarded Range and the registered headers.
    expect(upstreamRequests.single.range, 'bytes=2-5');
    expect(upstreamRequests.single.headers['user-agent'], 'pure_live/1.0');
    expect(upstreamRequests.single.headers['referer'], 'https://live.example/');
    client.close(force: true);
  });

  test('an upstream failure is relayed, not swallowed', () async {
    serveOrigin(status: 403);
    final upstreamUri = Uri.parse('http://127.0.0.1:${upstream.port}/gated');
    final proxyUrl = await server.registerRemote(upstreamUri);

    final client = HttpClient();
    final response = await client.getUrl(proxyUrl).then((request) => request.close());
    expect(response.statusCode, 403, reason: 'the TV sees the honest refusal');
    await response.drain<void>();
    client.close(force: true);
  });

  test('unregister closes the route', () async {
    serveOrigin();
    final proxyUrl = await server.registerRemote(Uri.parse('http://127.0.0.1:${upstream.port}/v.mp4'));

    server.unregisterRemote(proxyUrl);
    final client = HttpClient();
    final response = await client.getUrl(proxyUrl).then((request) => request.close());
    expect(response.statusCode, HttpStatus.notFound);
    await response.drain<void>();
    client.close(force: true);
  });

  test('an HLS playlist is rewritten so children loop back through the proxy', () async {
    const playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-KEY:METHOD=AES-128,URI="key.php?token=abc"
#EXTINF:4.0,
seg0.ts
#EXTINF:4.0,
/chunks/seg1.ts
''';
    upstream.listen((request) async {
      upstreamRequests.add((
        method: request.method,
        range: null,
        headers: <String, String>{'referer': request.headers.value('referer') ?? ''},
        path: request.uri.path,
      ));
      if (request.uri.path.endsWith('.m3u8')) {
        request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        request.response.add(utf8.encode(playlist));
        await request.response.close();
        return;
      }
      request.response.add(utf8.encode('segment:${request.uri.path}'));
      await request.response.close();
    }, onError: (Object _) {});

    final origin = Uri.parse('http://127.0.0.1:${upstream.port}/live/index.m3u8');
    final proxyUrl = await server.registerRemote(
      origin,
      upstreamHeaders: const {'Referer': 'https://live.example/'},
      isPlaylist: true,
    );

    final client = HttpClient();
    final response = await client.getUrl(proxyUrl).then((request) => request.close());
    final text = await utf8.decodeStream(response);
    expect(text, contains('#EXTM3U'));
    // Every child reference now points at the proxy host, never at the
    // origin — the TV never needs (and never gets) the origin address.
    expect(
      text,
      contains('http://127.0.0.1:${server.boundPort}/r/'),
      reason: 'children must point at the proxy, never at the origin',
    );

    // The rewritten key line resolves: fetching it proxies upstream
    // with the registration's headers attached.
    final keyMatch = RegExp('URI="([^"]+)"').firstMatch(text)!;
    final keyResponse = await client.getUrl(Uri.parse(keyMatch.group(1)!)).then((r) => r.close());
    expect(keyResponse.statusCode, HttpStatus.ok);
    final segmentLine = text
        .split('\n')
        .firstWhere((line) => line.startsWith('http://127.0.0.1') && line.contains('/r/'));
    final segResponse = await client.getUrl(Uri.parse(segmentLine)).then((r) => r.close());
    final segBody = await segResponse.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    expect(segBody, isNotEmpty);
    client.close(force: true);
  });
}
