import 'dart:async';
import 'dart:io';

import 'package:media_core/media_core.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// A loopback byte relay between FFmpeg and the live source.
///
/// FFmpeg reads the recording from `http://127.0.0.1:<port>/<secret>/stream`
/// while the relay fetches the real address and pipes the bytes through. The
/// reason is the stop: ending the upstream connection is a clean end — FFmpeg
/// sees EOF, drains what it buffered and writes complete segments — where a
/// killed process cuts the muxer mid packet. A direct FFmpeg→CDN connection
/// cannot be ended from Dart; a relayed one is the relay's own socket.
///
/// One relay serves one capture: every FFmpeg attempt (a re-open included)
/// gets a fresh relay for its own address, because the address and the
/// headers it was minted with change together. Progressive sources only — an
/// HLS capture lets FFmpeg do its own manifest and segment reads, and a byte
/// relay would stand between them.
final class RecordingInputRelay {
  RecordingInputRelay._({
    required HttpServer server,
    required HttpClient client,
    required Uri upstream,
    required Map<String, String> headers,
    required String secret,
  }) : _server = server,
       _client = client,
       _upstream = upstream,
       _headers = headers,
       _secret = secret;

  /// Starts a relay for [upstream]; null when the loopback server could not
  /// be started (the caller captures directly, and only loses the clean stop).
  static Future<RecordingInputRelay?> start({
    required Uri upstream,
    required Map<String, String> headers,
    String? proxy,
  }) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final relay = RecordingInputRelay._(
        server: server,
        client: _clientOf(proxy),
        upstream: upstream,
        headers: headers,
        secret: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      );
      server.listen(relay._serve, onError: (Object error) {
        _log.debug('the recording relay stopped serving', error: error);
      });
      return relay;
    } on Object catch (error) {
      try {
        await server?.close(force: true);
      } on Object {
        // A server that never bound has nothing to close.
      }
      _log.warning('the recording relay could not start; capturing directly', error: error);
      return null;
    }
  }

  static HttpClient _clientOf(String? proxy) {
    final client = HttpClient();
    if (proxy != null && proxy.trim().isNotEmpty) {
      client.findProxy = (uri) => 'PROXY ${proxy.trim()}';
    }
    // A live capture runs for hours; a CDN that stops answering mid capture
    // must not hold the pipe open for the default's minutes.
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }

  final HttpServer _server;
  final HttpClient _client;
  final Uri _upstream;
  final Map<String, String> _headers;
  final String _secret;

  HttpClientRequest? _upstreamRequest;

  /// The address FFmpeg reads instead of the real one.
  Uri get localUrl => Uri.parse('http://127.0.0.1:${_server.port}/$_secret/stream');

  /// Whether the upstream is connected right now.
  bool get isActive => _upstreamRequest != null;

  Future<void> _serve(HttpRequest request) async {
    // The relay speaks to exactly one client: the FFmpeg this capture started.
    // Anything else on the loopback port is not ours.
    if (!request.uri.path.endsWith('/$_secret/stream')) {
      await request.response.close();
      return;
    }
    try {
      final upstream = await _client.openUrl('GET', _upstream);
      _headers.forEach(upstream.headers.set);
      final response = await upstream.close();
      _upstreamRequest = upstream;
      request.response.bufferOutput = false;
      // A response the CDN ended (or the relay stopped) ends FFmpeg's read:
      // that is the clean stop's whole point, and also how an upstream death
      // reaches the capture.
      await response.pipe(request.response);
    } on Object catch (error) {
      _log.debug('the recording relay lost its upstream', error: error, fields: <String, Object?>{
        'upstream': _upstream.host,
      });
      try {
        await request.response.close();
      } on Object {
        // A client already gone has nothing to answer.
      }
    } finally {
      _upstreamRequest = null;
    }
  }

  /// Ends the upstream connection: FFmpeg drains and finishes on its own.
  ///
  /// Returns once no upstream request is in flight.
  Future<void> closeInput() async {
    final request = _upstreamRequest;
    if (request == null) return;
    try {
      request.abort();
    } on Object {
      // An already-dead connection has nothing to abort.
    }
    _upstreamRequest = null;
  }

  /// Stops the relay for good.
  Future<void> stop() async {
    await closeInput();
    _client.close(force: true);
    try {
      await _server.close(force: true);
    } on Object {
      // A server that already died has nothing to close.
    }
  }
}
