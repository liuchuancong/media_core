import 'dart:io';

import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_http_range.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_resource_registry.dart';

/// Answers renderers' requests against a [MediaResourceRegistry].
///
/// The full grammar is HEAD, GET and single-segment byte-range GET for
/// registered resources; everything else is a 404 that does not
/// distinguish a wrong token from an unknown one. Bodies stream from
/// the file — a movie never enters memory — and a renderer that walks
/// away mid-stream cancels cleanly.
final class MediaHttpHandler {
  /// Creates a handler.
  const MediaHttpHandler(this._registry);

  final MediaResourceRegistry _registry;

  /// Serves one request; never throws — every failure becomes a
  /// status code, because a crashed handler kills the accept loop's
  /// isolation for every other renderer on the LAN.
  Future<void> handle(HttpRequest request) async {
    try {
      final key = _keyOf(request.requestedUri);
      final registration = key == null ? null : _registry.lookup(key);
      if (registration == null) {
        await _respondStatus(request, HttpStatus.notFound);
        return;
      }

      final size = registration.size;
      final outcome = HttpByteRange.parse(request.headers.value(HttpHeaders.rangeHeader), size);

      if (outcome.isUnsatisfiable) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
        await request.response.close();
        return;
      }

      final range = outcome.range;
      request.response.statusCode = range == null ? HttpStatus.ok : HttpStatus.partialContent;
      request.response.headers.contentType = ContentType.parse(registration.mimeType);
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (range != null) {
        request.response.headers.set(HttpHeaders.contentRangeHeader, range.contentRange(size));
        request.response.contentLength = range.length;
      } else {
        request.response.contentLength = size;
      }

      if (request.method.toUpperCase() == 'HEAD') {
        await request.response.close();
        return;
      }

      await request.response.addStream(registration.file.openRead(range?.sliceStart ?? 0, range?.sliceEnd ?? size));
      await request.response.close();
    } on Object {
      // The renderer went away mid-stream (a seek, a stop) or the
      // answer could not be framed; closing is all the cleanup an
      // HttpResponse takes, and the server carries on.
      try {
        await request.response.close();
      } on Object {
        // Nothing further to do with a dead socket.
      }
    }
  }

  Future<void> _respondStatus(HttpRequest request, int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }

  String? _keyOf(Uri url) {
    final segments = url.pathSegments;
    if (segments.length != 2) {
      return null;
    }
    return segments.join('/');
  }
}
