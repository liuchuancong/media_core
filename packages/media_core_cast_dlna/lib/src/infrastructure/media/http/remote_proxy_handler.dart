import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:media_core_cast_dlna/src/infrastructure/media/http/remote_proxy_registry.dart';
import 'package:media_core_logging/media_core_logging.dart';

/// Serves proxied remote resources to renderers.
///
/// Two shapes live under `/r/`:
///
/// - `/r/{token}` — the registered upstream, streamed through with the
///   registration's headers attached (the token-gated URL the TV cannot
///   fetch itself);
/// - `/r/{token}/{childId}` — a rewritten HLS child: the playlist proxy
///   resolves segment/key URIs against the upstream base and hands the
///   TV proxy URLs, and each child fetch relays the upstream answer.
///
/// Byte ranges are forwarded to the upstream verbatim and its status
/// and headers are relayed — the proxy never invents lengths it did not
/// see. Everything is streamed; nothing upstream-sized enters memory
/// except a rewritten playlist text.
final class RemoteProxyHandler {
  /// Creates a handler.
  const RemoteProxyHandler(this._registry);

  final RemoteProxyRegistry _registry;

  /// Serves one request; never throws into the accept loop.
  Future<void> handle(HttpRequest request) async {
    HttpClient? upstreamClient;
    Uri? upstreamUrl;
    try {
      final segments = request.uri.pathSegments;
      if (segments.length < 2 || segments.first != 'r') {
        await _respond(request, HttpStatus.notFound);
        return;
      }
      final registration = _registry.lookup(segments[1]);
      if (registration == null) {
        await _respond(request, HttpStatus.notFound);
        return;
      }

      if (segments.length == 2 && registration.isPlaylist) {
        upstreamClient = HttpClient();
        upstreamUrl = registration.upstream;
        await _servePlaylist(request, registration, upstreamClient);
        return;
      }

      final upstream = segments.length == 2 ? registration.upstream : _registry.childOf(registration, segments[2]);
      if (upstream == null) {
        await _respond(request, HttpStatus.notFound);
        return;
      }
      upstreamClient = HttpClient();
      upstreamUrl = upstream;
      await _streamUpstream(request, upstream, registration.upstreamHeaders, upstreamClient);
    } on Object catch (error) {
      MediaCoreLog.warning(
        LogCategory.network,
        'proxy upstream failed',
        error: error,
        fields: <String, Object?>{'host': upstreamUrl?.host ?? ''},
      );
      try {
        await request.response.close();
      } on Object {
        // The renderer vanished mid-answer; nothing further to do.
      }
    } finally {
      upstreamClient?.close(force: true);
    }
  }

  /// Fetches the HLS manifest and rewrites every child reference into a
  /// proxy URL. The rewritten text is served whole — playlists are
  /// small, and a live manifest refresh simply rewrites again.
  Future<void> _servePlaylist(HttpRequest request, RemoteProxyRegistration registration, HttpClient client) async {
    final upstreamRequest = await client.openUrl('GET', registration.upstream).timeout(const Duration(seconds: 10));
    registration.upstreamHeaders.forEach(upstreamRequest.headers.set);
    final upstreamResponse = await upstreamRequest.close().timeout(const Duration(seconds: 10));
    if (upstreamResponse.statusCode != HttpStatus.ok) {
      request.response.statusCode = HttpStatus.badGateway;
      await upstreamResponse.drain<void>().catchError((Object error) {
        MediaCoreLog.debug(LogCategory.network, 'upstream drain failed', error: error);
      });
      await request.response.close();
      return;
    }
    final text = await utf8.decodeStream(upstreamResponse);
    final rewritten = _rewritePlaylist(text, registration, request.requestedUri);
    request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
    request.response.add(utf8.encode(rewritten));
    await request.response.close();
  }

  /// Rewrites segment, variant and attribute URIs into proxy children.
  String _rewritePlaylist(String text, RemoteProxyRegistration registration, Uri proxyBase) {
    final playlistUrl = registration.upstream;
    final output = <String>[];
    for (final rawLine in LineSplitter.split(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        output.add('');
        continue;
      }
      if (line.startsWith('#')) {
        output.add(
          line.replaceAllMapped(RegExp('URI="([^"]+)"'), (match) {
            final absolute = registration.childUri(match.group(1)!, playlistUrl);
            return 'URI="${_proxyUrl(playlistUrl, registration.pathForChild(absolute))}"';
          }),
        );
        continue;
      }
      final absolute = registration.childUri(line, playlistUrl);
      output.add(_proxyUrl(proxyBase, registration.pathForChild(absolute)));
    }
    return output.join('\n');
  }

  String _proxyUrl(Uri base, String path) =>
      '${base.scheme}://${base.host}${base.port == 0 ? '' : ':${base.port}'}$path';

  /// Relays an upstream answer: method, Range header and the
  /// registration's headers go up; status, content headers and the body
  /// stream come back.
  Future<void> _streamUpstream(
    HttpRequest request,
    Uri url,
    Map<String, String> upstreamHeaders,
    HttpClient client,
  ) async {
    final isHead = request.method.toUpperCase() == 'HEAD';
    final upstreamRequest = await client
        .openUrl(isHead ? 'HEAD' : request.method, url)
        .timeout(const Duration(seconds: 15));
    upstreamHeaders.forEach(upstreamRequest.headers.set);
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range);
    }
    final upstreamResponse = await upstreamRequest.close().timeout(const Duration(seconds: 20));

    request.response.statusCode = upstreamResponse.statusCode;
    _relayHeader(upstreamResponse, request.response, HttpHeaders.contentTypeHeader);
    _relayHeader(upstreamResponse, request.response, HttpHeaders.contentRangeHeader);
    _relayHeader(upstreamResponse, request.response, HttpHeaders.acceptRangesHeader);
    final length = upstreamResponse.contentLength;
    if (length >= 0) {
      request.response.contentLength = length;
    }

    if (isHead) {
      await upstreamResponse.drain<void>().catchError((Object error) {
        MediaCoreLog.debug(LogCategory.network, 'upstream drain failed', error: error);
      });
      await request.response.close();
      return;
    }
    await request.response.addStream(upstreamResponse);
    await request.response.close();
  }

  Future<void> _respond(HttpRequest request, int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }

  void _relayHeader(HttpClientResponse from, HttpResponse to, String name) {
    final value = from.headers.value(name);
    if (value != null) {
      to.headers.set(name, value);
    }
  }
}
