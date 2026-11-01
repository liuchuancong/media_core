/// The answer a [SoapTransport] POST produced.
final class SoapHttpResponse {
  /// Creates a response.
  const SoapHttpResponse({required this.statusCode, required this.body});

  /// HTTP status code.
  final int statusCode;

  /// Response body text.
  final String body;
}

/// Posts a prepared SOAP envelope to a device control endpoint.
///
/// The protocol layer owns the message shape; this contract owns the
/// wire. Production posts over `dart:io`, tests answer from a table —
/// neither may leak into the encoding or the fault mapping.
abstract interface class SoapTransport {
  /// POSTs [body] with [headers] to [url].
  Future<SoapHttpResponse> post(Uri url, Map<String, String> headers, String body);
}
