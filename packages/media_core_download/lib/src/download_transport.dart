import 'dart:async';
import 'dart:io' as io;

import 'download_config.dart';

/// One ranged request.
final class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.startByte,
    this.endByte,
    this.headers = const <String, String>{},
    this.userAgent,
    this.timeout = const Duration(seconds: 20),
    this.maxRedirects = 2,
  });

  final String url;

  /// First byte to fetch.
  final int startByte;

  /// Last byte to fetch, inclusive; `null` means "to the end".
  final int? endByte;

  final Map<String, String> headers;
  final String? userAgent;
  final Duration timeout;
  final int maxRedirects;

  /// Whether this request is a plain full-file fetch.
  bool get isFullFile => startByte == 0 && endByte == null;

  /// `Range` header value, or `null` for a full fetch.
  String? get rangeHeader => isFullFile ? null : 'bytes=$startByte-${endByte ?? ''}';
}

/// A server's answer.
final class DownloadResponse {
  const DownloadResponse({
    required this.statusCode,
    required this.byteStream,
    this.contentLength = -1,
    this.totalBytes = -1,
    this.acceptsRanges = false,
  });

  final int statusCode;

  /// Body bytes, already positioned at the requested offset.
  final Stream<List<int>> byteStream;

  /// Length of *this* response, or `-1` when not sent.
  final int contentLength;

  /// Length of the whole file, or `-1` when the server did not say.
  ///
  /// Taken from `Content-Range` for a partial response and from
  /// `Content-Length` for a full one; the distinction matters because a ranged
  /// response's own length is not the file's size.
  final int totalBytes;

  /// Whether the server advertised byte-range support.
  final bool acceptsRanges;

  /// Whether the server answered a ranged request with a partial body.
  bool get isPartial => statusCode == 206;

  /// The file's size as reported by this response, or `null` when unknown.
  int? get resolvedTotalBytes {
    if (totalBytes > 0) {
      return totalBytes;
    }
    return !isPartial && contentLength > 0 ? contentLength : null;
  }

  @override
  String toString() {
    final total = resolvedTotalBytes;
    return 'DownloadResponse($statusCode, ${total == null ? 'unknown size' : '$total B'}, ranges: $acceptsRanges)';
  }
}

/// Fetches bytes over the network.
///
/// The seam exists so the queue's policy — concurrency, retry, resume
/// verification, progress — is testable without a server, and so a host can
/// route downloads through its own client (a proxy, a platform downloader, a
/// test double).
abstract interface class DownloadTransport {
  /// Fetches [request].
  ///
  /// Implementations must throw on a non-success status rather than return it,
  /// so retry policy has one failure shape to reason about.
  Future<DownloadResponse> fetch(DownloadRequest request);

  /// Releases any pooled connection resources.
  Future<void> dispose();
}

/// Thrown when a server answers with a status the transfer cannot use.
final class DownloadHttpException implements Exception {
  const DownloadHttpException(this.statusCode, this.url);

  final int statusCode;
  final String url;

  @override
  String toString() => 'DownloadHttpException($statusCode for $url)';
}

/// [DownloadTransport] backed by `dart:io`'s HTTP client.
///
/// Deliberately dependency-free: a download is a GET, a range header and a byte
/// stream, and pulling an HTTP package in for that would put the queue's
/// timeout and redirect behaviour at the mercy of another library.
final class HttpDownloadTransport implements DownloadTransport {
  HttpDownloadTransport({io.HttpClient? client, DownloadConfig config = DownloadConfig.defaults})
    : _client = client ?? io.HttpClient(),
      _config = config;

  io.HttpClient _client;
  DownloadConfig _config;

  /// Applies a new configuration to subsequent requests.
  void updateConfig(DownloadConfig config) => _config = config;

  @override
  Future<DownloadResponse> fetch(DownloadRequest request) async {
    final uri = Uri.parse(request.url);
    var redirects = 0;
    var current = uri;

    while (true) {
      final httpRequest = await _client.getUrl(current).timeout(request.timeout);
      httpRequest.followRedirects = false;
      httpRequest.headers.set(io.HttpHeaders.userAgentHeader, request.userAgent ?? _config.userAgent);
      applyHeaders(httpRequest, request.headers);
      final rangeHeader = request.rangeHeader;
      if (rangeHeader != null) {
        httpRequest.headers.set(io.HttpHeaders.rangeHeader, rangeHeader);
      }

      final response = await httpRequest.close().timeout(request.timeout);

      if (response.isRedirect) {
        if (redirects >= request.maxRedirects) {
          throw DownloadHttpException(response.statusCode, current.toString());
        }
        redirects++;
        final location = response.headers.value(io.HttpHeaders.locationHeader);
        if (location == null || location.isEmpty) {
          throw DownloadHttpException(response.statusCode, current.toString());
        }
        current = current.resolve(location);
        await response.drain<void>();
        continue;
      }

      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.drain<void>();
        throw DownloadHttpException(response.statusCode, current.toString());
      }

      final contentRange = response.headers.value(io.HttpHeaders.contentRangeHeader);
      final contentLength = response.contentLength;
      final fullBody = response.statusCode == 200 && contentLength > 0;

      return DownloadResponse(
        statusCode: response.statusCode,
        byteStream: response,
        contentLength: contentLength,
        totalBytes: totalFromContentRange(contentRange) ?? (fullBody ? contentLength : -1),
        acceptsRanges: response.headers.value(io.HttpHeaders.acceptRangesHeader) != null,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _client.close(force: true);
    _client = io.HttpClient();
  }

  /// Applies caller headers, dropping anything that would forge another header.
  ///
  /// Header values reach a native parser; a name with a colon or a value with a
  /// newline is an injection, not a header.
  static void applyHeaders(io.HttpClientRequest request, Map<String, String> headers) {
    headers.forEach((name, value) {
      final safeName = name.trim().toLowerCase();
      if (safeName.isEmpty || safeName.contains(RegExp(r'[\r\n:]'))) {
        return;
      }
      try {
        request.headers.set(safeName, value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' '));
      } catch (_) {
        // A header this client refuses is dropped rather than failing the
        // whole transfer.
      }
    });
  }

  /// Parses the total from `Content-Range: bytes start-end/total`.
  ///
  /// Returns null when the header is absent or does not carry a total (`*`).
  static int? totalFromContentRange(String? contentRange) {
    if (contentRange == null) {
      return null;
    }
    final slash = contentRange.lastIndexOf('/');
    if (slash < 0) {
      return null;
    }
    final total = int.tryParse(contentRange.substring(slash + 1).trim());
    return total != null && total > 0 ? total : null;
  }
}
