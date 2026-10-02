import 'dart:convert';
import 'dart:io';

/// One UPnP control response.
class SoapResponse {
  /// Creates a response.
  const SoapResponse({required this.statusCode, required this.body});

  /// HTTP status.
  final int statusCode;

  /// Response body text.
  final String body;
}

/// Posts SOAP envelopes to a control URL.
///
/// Injectable so the SOAP codec, the argument parsing and the fault
/// handling are unit-testable without a TV on the network: a test
/// hands it a closure that returns canned envelopes, and production
/// uses the [HttpSoapTransport] default.
typedef SoapPoster = Future<SoapResponse> Function(
  String url,
  String action,
  Map<String, String> headers,
  String body,
);

/// [SoapPoster] over `dart:io HttpClient`.
class HttpSoapTransport {
  /// Creates a transport with its own [client].
  HttpSoapTransport({HttpClient? client, Duration timeout = const Duration(seconds: 8)})
    : _client = client ?? HttpClient()..connectionTimeout = timeout,
      _timeout = timeout;

  final HttpClient _client;
  final Duration _timeout;

  /// Sends one control request.
  Future<SoapResponse> call(
    String url,
    String action,
    Map<String, String> headers,
    String body,
  ) async {
    final request = await _client.postUrl(Uri.parse(url)).timeout(_timeout);
    headers.forEach((name, value) => request.headers.set(name, value));
    request.add(utf8.encode(body));

    final response = await request.close().timeout(_timeout);
    final text = await response.transform(utf8.decoder).join();
    return SoapResponse(statusCode: response.statusCode, body: text);
  }

  /// Closes pooled sockets.
  void close() => _client.close(force: true);
}

/// Fetches a device description document.
typedef DescriptionFetcher = Future<String> Function(String url);

/// [DescriptionFetcher] over `dart:io HttpClient`.
class HttpDescriptionFetcher {
  /// Creates the fetcher.
  HttpDescriptionFetcher({HttpClient? client, Duration timeout = const Duration(seconds: 8)})
    : _client = client ?? HttpClient(),
      _timeout = timeout;

  final HttpClient _client;
  final Duration _timeout;

  /// GETs [url] as text.
  Future<String> call(String url) async {
    final request = await _client.getUrl(Uri.parse(url)).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    return response.transform(utf8.decoder).join();
  }

  /// Closes pooled sockets.
  void close() => _client.close(force: true);
}
