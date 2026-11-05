import 'dart:async';
import 'dart:io';

import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_http_handler.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_resource_registry.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/remote_proxy_handler.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/remote_proxy_registry.dart';
import 'package:media_core_cast_dlna/src/infrastructure/network/ip_address_selector.dart';
import 'package:media_core_logging/media_core_logging.dart';

/// Where a media server is in its lifecycle.
enum MediaServerState {
  /// Created, never started.
  idle,

  /// [MediaHttpServer.start] is running.
  starting,

  /// Accepting requests.
  running,

  /// [MediaHttpServer.stop] is running.
  stopping,

  /// Stopped; every resource dropped.
  stopped,

  /// Start failed; no socket is bound.
  error,
}

/// Serves registered local media to renderers over HTTP.
///
/// This is not a web server: it answers HEAD, GET and byte-range GET
/// for exactly the resources the host registered, and nothing else.
/// The guarantees renderers rely on: `Accept-Ranges`, correct
/// `Content-Length`/`Content-Range`, streamed file bodies, and access
/// gated by a random per-resource token so the filesystem itself is
/// never exposed (§22.3).
///
/// The server is shared infrastructure (§23.3): several cast sessions
/// can hold resources on it, and one session stopping unregisters that
/// session's resources, not the server.
final class MediaHttpServer {
  /// Creates a server.
  ///
  /// [addressSelector] overrides the LAN address used in generated
  /// URLs; [port] pins a port instead of letting the OS pick one.
  MediaHttpServer({Future<InternetAddress?> Function()? addressSelector, this.port})
    : _addressSelector = addressSelector ?? IpAddressSelector.bestLanAddress,
      _registry = MediaResourceRegistry();

  /// A fixed port to bind, when the host requires one; otherwise the
  /// OS assigns a free port.
  final int? port;

  final Future<InternetAddress?> Function() _addressSelector;
  final MediaResourceRegistry _registry;
  final RemoteProxyRegistry _remoteRegistry = RemoteProxyRegistry();
  late final RemoteProxyHandler _remoteHandler = RemoteProxyHandler(_remoteRegistry);

  HttpServer? _server;
  Timer? _sweepTimer;
  MediaHttpHandler? _handler;

  MediaServerState _state = MediaServerState.idle;

  /// Where this server is in its lifecycle.
  MediaServerState get state => _state;

  /// Whether the server accepts requests.
  bool get isRunning => _state == MediaServerState.running;

  /// The bound port, once running.
  int? get boundPort => _server?.port;

  /// The LAN address generated URLs point at, once running.
  InternetAddress? get address => _address;

  /// How many resources are currently registered (files + remote).
  int get resourceCount => _registry.length + _remoteRegistry.length;

  InternetAddress? _address;

  /// Starts the server. Idempotent.
  Future<void> start() async {
    if (isRunning || _state == MediaServerState.starting) {
      return;
    }
    _state = MediaServerState.starting;
    try {
      _address = await _addressSelector();
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port ?? 0);
      _server = server;
      _handler = MediaHttpHandler(_registry);
      server.listen(
        (request) =>
            request.uri.pathSegments.firstOrNull == 'r' ? _remoteHandler.handle(request) : _handler!.handle(request),
        onError: (Object _) {
          // Per-connection errors surface here; the listening socket
          // must survive one broken client.
        },
        cancelOnError: false,
      );
    } on Object catch (error) {
      _state = MediaServerState.error;
      MediaCoreLog.error(LogCategory.network, 'media server failed to start', error: error);
      throw MediaServerException('media server could not start', cause: error);
    }
    _state = MediaServerState.running;
    MediaCoreLog.info(
      LogCategory.network,
      'media server started',
      fields: <String, Object?>{'port': boundPort, 'address': _address?.address},
    );
  }

  /// Registers a local file and returns the URL a renderer fetches.
  ///
  /// [mimeType] defaults to the file's extension; [ttl] expires the
  /// registration after that lifetime, null keeps it until
  /// [unregister].
  ///
  /// Throws [MediaServerException] when the server is not running or
  /// no LAN address is known — a URL pointing nowhere is worse than a
  /// refused cast.
  Future<Uri> registerFile(File file, {String? mimeType, Duration? ttl}) async {
    if (!isRunning) {
      throw const MediaServerException('media server is not running');
    }
    final address = _address;
    final server = _server;
    if (address == null || server == null) {
      throw const MediaServerException('no LAN address is known; the media URL would be unreachable');
    }
    final registration = _registry.register(file, mimeType: mimeType, ttl: ttl);
    _ensureSweep();
    return Uri.parse('http://${address.address}:${server.port}/${registration.token}/${registration.id}');
  }

  /// Registers a remote URL for proxy streaming and returns the URL a
  /// renderer fetches. [upstreamHeaders] are attached to every upstream
  /// fetch (Referer/Cookie/UA — the reason the TV cannot fetch the URL
  /// itself); [isPlaylist] marks an HLS manifest whose child references
  /// are rewritten into proxy URLs.
  Future<Uri> registerRemote(
    Uri upstream, {
    Map<String, String> upstreamHeaders = const <String, String>{},
    String? mimeType,
    Duration? ttl,
    bool isPlaylist = false,
  }) async {
    if (!isRunning) {
      throw const MediaServerException('media server is not running');
    }
    final address = _address;
    final server = _server;
    if (address == null || server == null) {
      throw const MediaServerException('no LAN address is known; the media URL would be unreachable');
    }
    final registration = _remoteRegistry.register(
      upstream,
      upstreamHeaders: upstreamHeaders,
      mimeType: mimeType,
      ttl: ttl,
      isPlaylist: isPlaylist,
    );
    _ensureSweep();
    return Uri.parse('http://${address.address}:${server.port}/r/${registration.token}');
  }

  /// Unregisters a remote resource by the URL [registerRemote] returned.
  void unregisterRemote(Uri url) => _remoteRegistry.unregisterUrl(url);

  /// Unregisters a resource by the URL [registerFile] returned.
  void unregister(Uri url) => _registry.unregisterUrl(url);

  /// Drops every registration; the server keeps running.
  void clear() => _registry.clear();

  /// Stops the server and drops every registration.
  Future<void> stop() async {
    if (!isRunning && _state != MediaServerState.error) {
      return;
    }
    _state = MediaServerState.stopping;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _registry.clear();
    _remoteRegistry.clear();
    await _server?.close(force: true);
    _server = null;
    _address = null;
    _handler = null;
    _state = MediaServerState.stopped;
    MediaCoreLog.info(LogCategory.network, 'media server stopped');
  }

  void _ensureSweep() {
    if (_sweepTimer != null || !_registry.anyExpiring) {
      return;
    }
    _sweepTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _registry.sweepExpired();
      _remoteRegistry.sweepExpired();
      if (!_registry.anyExpiring && !_remoteRegistry.anyExpiring) {
        _sweepTimer?.cancel();
        _sweepTimer = null;
      }
    });
  }
}

/// The media server could not do its one job.
final class MediaServerException implements Exception {
  /// Creates an exception.
  const MediaServerException(this.message, {this.cause});

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'MediaServerException: $message';
}
