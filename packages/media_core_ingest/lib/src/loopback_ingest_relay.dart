import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Rewrites an HLS manifest tree so every child is an absolute loopback URL.
///
/// The player then resolves nothing itself: it is handed
/// `http://127.0.0.1:<port>/<secret>/root.m3u8` and every playlist, segment, key
/// and map it reads from there is already absolute. That removes a whole class
/// of provider quirks - bare `media.95.mp4` children, absolute-path children,
/// per-child tokens, cookies handed out with the manifest - without teaching the
/// player or its FFmpeg about any of them.
///
/// The relay is deliberately small and per-source: one upstream origin, one
/// secret, one manifest tree. It keeps upstream TLS verification (Dart's trust
/// path) and answers a Range request by proxying it, so seeking into a finished
/// stream still works.
final class LoopbackIngestRelay {
  LoopbackIngestRelay._({
    required HttpServer server,
    required HttpClient client,
    required Uri upstream,
    required Map<String, String> headers,
    required String secret,
    required Duration manifestTimeout,
    required int maximumManifestBytes,
  }) : _server = server,
       _client = client,
       _headers = headers,
       _secret = secret,
       _manifestTimeout = manifestTimeout,
       _maximumManifestBytes = maximumManifestBytes {
    _children['root.m3u8'] = _Child(uri: upstream, manifest: true);
  }

  /// Starts a relay for [source]. The returned relay owns the port until
  /// [close]; callers hand [inputUri] to the player.
  static Future<LoopbackIngestRelay> start({
    required Uri source,
    Map<String, String> headers = const <String, String>{},
    Duration manifestTimeout = const Duration(seconds: 15),
    int maximumManifestBytes = 8 * 1024 * 1024,
  }) async {
    if (!const <String>{
          'http',
          'https',
        }.contains(source.scheme.toLowerCase()) ||
        source.host.isEmpty) {
      throw ArgumentError.value(
        source,
        'source',
        'Loopback ingest needs an http(s) source',
      );
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final relay = LoopbackIngestRelay._(
      server: server,
      client: HttpClient()..connectionTimeout = manifestTimeout,
      upstream: source,
      headers: Map<String, String>.unmodifiable(headers),
      secret: _newSecret(),
      manifestTimeout: manifestTimeout,
      maximumManifestBytes: maximumManifestBytes,
    );
    server.listen(relay._handle, onError: (Object _) {}, cancelOnError: false);
    return relay;
  }

  static final Random _random = Random.secure();
  static final RegExp _uriAttribute = RegExp(
    r'URI="([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _manifestPath = RegExp(
    r'(\.m3u8|/(master_)?playlist)$',
    caseSensitive: false,
  );

  final HttpServer _server;
  final HttpClient _client;
  final Map<String, String> _headers;
  final String _secret;
  final Duration _manifestTimeout;
  final int _maximumManifestBytes;

  final Map<String, _Child> _children = <String, _Child>{};

  /// Upstream URL -> the child name serving it, so a repeated URI is registered
  /// once and the playlist stays small.
  final Map<String, String> _byUpstream = <String, String>{};
  int _nextId = 0;
  bool _closed = false;

  /// The URL the player opens.
  Uri get inputUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: '/$_secret/root.m3u8',
  );

  /// Number of distinct children handed out so far (diagnostics/tests).
  int get childCount => _children.length - 1;

  /// Whether [close] has run; a closed relay is no longer a usable input.
  bool get isClosed => _closed;

  static String _newSecret() {
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      24,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> _handle(HttpRequest request) async {
    final String prefix = '/$_secret/';
    final String path = request.uri.path;
    if (_closed || !path.startsWith(prefix)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final String name = path.substring(prefix.length);
    final _Child? child = _children[name];
    if (child == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      if (child.manifest) {
        await _serveManifest(request, child.uri);
      } else {
        await _proxyChild(request, child.uri);
      }
    } catch (_) {
      // A failed child is the player's error to report: closing the response
      // with a status keeps it from waiting forever.
      await _fail(request, HttpStatus.badGateway);
    }
  }

  Future<void> _serveManifest(HttpRequest request, Uri manifest) async {
    final HttpClientResponse upstream = await _open(
      request.method == 'HEAD' ? 'GET' : 'GET',
      manifest,
    );
    if (upstream.statusCode != HttpStatus.ok) {
      await upstream.drain<void>();
      await _fail(request, upstream.statusCode);
      return;
    }
    final String body = await _readManifest(upstream);
    if (_closed) return;
    final String rewritten = _rewrite(body, manifest);
    final HttpResponse response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(rewritten);
    await response.close();
  }

  Future<String> _readManifest(HttpClientResponse upstream) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in upstream.timeout(_manifestTimeout)) {
      builder.add(chunk);
      if (builder.length > _maximumManifestBytes) {
        throw const FormatException('Ingest manifest exceeds the relay budget');
      }
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  /// Rewrites every URI in [body] to an absolute loopback URL.
  ///
  /// Attribute URIs (`#EXT-X-KEY:URI="..."`, `#EXT-X-MAP:URI="..."`) and plain
  /// child lines are both resolved against [manifest], which is the part a
  /// native resolver gets wrong when it no longer knows the manifest URL.
  String _rewrite(String body, Uri manifest) {
    final bool hadTrailingNewline = body.endsWith('\n');
    final List<String> output = <String>[];
    for (final String rawLine in const LineSplitter().convert(body)) {
      final String line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        output.add('');
      } else if (trimmed.startsWith('#')) {
        output.add(
          line.replaceAllMapped(_uriAttribute, (Match match) {
            final String? local = _localUrl(manifest, match.group(1)!);
            return local == null ? match.group(0)! : 'URI="$local"';
          }),
        );
      } else {
        output.add(_localUrl(manifest, trimmed) ?? line);
      }
    }
    final String value = output.join('\n');
    return hadTrailingNewline ? '$value\n' : value;
  }

  /// Registers [raw] (resolved against [manifest]) and returns its loopback URL.
  String? _localUrl(Uri manifest, String raw) {
    final Uri? resolved = Uri.tryParse(raw) == null
        ? null
        : manifest.resolve(raw);
    if (resolved == null ||
        !const <String>{
          'http',
          'https',
        }.contains(resolved.scheme.toLowerCase()) ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    final bool isManifest = _manifestPath.hasMatch(resolved.path);
    final String key = resolved.toString();
    String? name = _byUpstream[key];
    if (name == null) {
      final String id = 'r${(_nextId++).toRadixString(36)}';
      name = '$id${isManifest ? '.m3u8' : _extensionOf(resolved)}';
      _children[name] = _Child(uri: resolved, manifest: isManifest);
      _byUpstream[key] = name;
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server.port,
      path: '/$_secret/$name',
    ).toString();
  }

  static String _extensionOf(Uri uri) {
    final String last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final int dot = last.lastIndexOf('.');
    if (dot <= 0 || dot == last.length - 1) return '';
    return last.substring(dot).toLowerCase();
  }

  Future<void> _proxyChild(HttpRequest request, Uri upstream) async {
    final HttpClientResponse response = await _open(
      request.method,
      upstream,
      range: request.headers.value(HttpHeaders.rangeHeader),
    );
    if (_closed) {
      await response.drain<void>();
      return;
    }
    final HttpResponse target = request.response;
    target.statusCode = response.statusCode;
    target.headers.contentType = response.headers.contentType;
    for (final String header in const <String>[
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.lastModifiedHeader,
    ]) {
      final String? value = response.headers.value(header);
      if (value != null) target.headers.set(header, value);
    }
    await target.addStream(response);
    await target.close();
  }

  Future<HttpClientResponse> _open(
    String method,
    Uri uri, {
    String? range,
  }) async {
    final HttpClientRequest request = await _client.openUrl(method, uri);
    _headers.forEach(request.headers.set);
    if (range != null && range.isNotEmpty) {
      request.headers.set(HttpHeaders.rangeHeader, range);
    }
    return request.close();
  }

  Future<void> _fail(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      await request.response.close();
    } catch (_) {
      // The player closed the connection first; nothing left to answer.
    }
  }

  /// Stops the relay: port, in-flight upstream sockets and the child registry.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _children.clear();
    _byUpstream.clear();
    _client.close(force: true);
    await _server.close(force: true);
  }
}

final class _Child {
  const _Child({required this.uri, required this.manifest});

  final Uri uri;
  final bool manifest;
}
