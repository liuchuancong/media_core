import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

Future<HttpServer> _serve(FutureOr<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await handler(request);
  }, onError: (Object _) {});
  return server;
}

void main() {
  group('HttpDescriptionFetcher', () {
    test('refuses a location that is not http or https', () {
      // The LOCATION comes out of an SSDP packet, so it is input from
      // whatever answered on the LAN. Fetching anything else would let a
      // rogue device point this process at a local or embedded resource.
      final fetcher = HttpDescriptionFetcher();

      expect(() => fetcher('file:///etc/passwd'), throwsA(isA<FormatException>()));
      expect(() => fetcher('data:text/xml,<root/>'), throwsA(isA<FormatException>()));
    });

    test('reads a served document', () async {
      final server = await _serve((request) async {
        request.response.write('<?xml version="1.0"?><root/>');
        await request.response.close();
      });

      final fetcher = HttpDescriptionFetcher();
      final body = await fetcher('http://127.0.0.1:${server.port}/desc.xml');

      expect(body, contains('<root/>'));

      await server.close(force: true);
      fetcher.close();
    });

    test('a non-2xx answer is a failure, not a document', () async {
      final server = await _serve((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final fetcher = HttpDescriptionFetcher();

      await expectLater(fetcher('http://127.0.0.1:${server.port}/desc.xml'), throwsA(isA<FormatException>()));

      await server.close(force: true);
      fetcher.close();
    });

    test('an endless body is cut off at the size bound', () async {
      final server = await _serve((request) async {
        // Serve well past the package's 1 MiB bound.
        final chunk = List.filled(64 * 1024, 'x').join();
        for (var i = 0; i < 32; i++) {
          request.response.write(chunk);
        }
        await request.response.close();
      });

      final fetcher = HttpDescriptionFetcher();

      await expectLater(fetcher('http://127.0.0.1:${server.port}/desc.xml'), throwsA(isA<FormatException>()));

      await server.close(force: true);
      fetcher.close();
    });
  });
}
