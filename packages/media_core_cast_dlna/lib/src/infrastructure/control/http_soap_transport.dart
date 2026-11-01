import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:media_core_cast_dlna/src/domain/contracts/soap_transport.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';

/// [SoapTransport] over `dart:io HttpClient`.
final class HttpSoapTransport implements SoapTransport {
  /// Creates a transport with its own [client].
  HttpSoapTransport({HttpClient? client, Duration timeout = const Duration(seconds: 8)})
    : _client = client ?? HttpClient()
        ..connectionTimeout = timeout,
      _timeout = timeout;

  final HttpClient _client;
  final Duration _timeout;

  @override
  Future<SoapHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    final request = await _client.postUrl(url).timeout(_timeout);
    headers.forEach(request.headers.set);
    request.add(utf8.encode(body));

    final response = await request.close().timeout(_timeout);
    final text = await readBoundedBody(response, timeout: _timeout);
    return SoapHttpResponse(statusCode: response.statusCode, body: text);
  }

  /// Closes pooled sockets.
  void close() => _client.close(force: true);
}
