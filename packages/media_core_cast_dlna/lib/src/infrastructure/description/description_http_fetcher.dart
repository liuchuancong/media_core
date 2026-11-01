import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Largest response body this package will read, in bytes.
///
/// A device description is a few kilobytes and a SOAP reply is smaller;
/// the bound exists so a broken or hostile renderer cannot exhaust the
/// heap by never finishing its answer.
const int maxCastResponseBodyBytes = 1 << 20;

/// Reads [response] as UTF-8 text, refusing to read past [limit].
///
/// Throws [FormatException] when the bound is exceeded — the caller is
/// parsing a document, and a truncated one is not a document. [timeout] is a
/// budget for the whole read: a renderer that accepts the request and then
/// trickles bytes would otherwise stall the future forever, and a position
/// poll that never answers is worse than one that throws.
Future<String> readBoundedBody(HttpClientResponse response, {Duration? timeout, int limit = maxCastResponseBodyBytes}) {
  final read = () async {
    final builder = BytesBuilder(copy: false);

    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > limit) {
        // Throwing out of an `await for` cancels the subscription;
        // draining again would be a second listen on a
        // single-subscription stream.
        throw const FormatException('response body exceeded the cast response size limit');
      }
    }

    return utf8.decode(builder.toBytes(), allowMalformed: true);
  }();

  return timeout == null ? read : read.timeout(timeout);
}

/// Fetches a device description document.
///
/// Injectable so the discovery pipeline runs against canned XML in
/// tests; production uses [HttpDescriptionFetcher].
typedef DescriptionFetcher = Future<String> Function(String url);

/// [DescriptionFetcher] over `dart:io HttpClient`.
final class HttpDescriptionFetcher {
  /// Creates the fetcher.
  HttpDescriptionFetcher({HttpClient? client, Duration timeout = const Duration(seconds: 8)})
    : _client = client ?? HttpClient(),
      _timeout = timeout;

  final HttpClient _client;
  final Duration _timeout;

  /// GETs [url] as text.
  ///
  /// The URL comes out of an SSDP packet, so it is input from whatever
  /// device answered on the LAN: only `http`/`https` is fetched, a
  /// non-2xx status is a failure rather than a document, and the body is
  /// size-bounded. A renderer that answers a description request with an
  /// endless stream would otherwise grow this process's heap until it
  /// dies, and a 404 HTML page would otherwise be handed to the XML
  /// parser as if it were a device description.
  Future<String> call(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException(
        'device description location must be http or https, '
        'got "${uri.scheme}"',
        url,
      );
    }

    final request = await _client.getUrl(uri).timeout(_timeout);
    final response = await request.close().timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw FormatException('device description at $url answered ${response.statusCode}', url);
    }

    return await readBoundedBody(response, timeout: _timeout);
  }

  /// Closes pooled sockets.
  void close() => _client.close(force: true);
}
