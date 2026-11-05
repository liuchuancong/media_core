import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_message_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_resource_registry.dart';
import 'package:media_core_cast_dlna/src/infrastructure/network/ip_address_selector.dart';

/// Serves the callback endpoint GENA devices NOTIFY against (§14.7).
///
/// Each subscription registers its own secret path
/// (`/gena/{token}`); the token is what gates access (§22.4), and the
/// subscriber additionally verifies the SID and sequence of every
/// event. The server parses the PropertySet and hands the decoded
/// notification to the route's handler — one broken request must not
/// take the listener down.
final class GenaCallbackServer {
  /// Creates a server.
  ///
  /// [addressSelector] overrides the LAN address used in callback URLs.
  GenaCallbackServer({Future<InternetAddress?> Function()? addressSelector})
    : _addressSelector = addressSelector ?? IpAddressSelector.bestLanAddress;

  final Future<InternetAddress?> Function() _addressSelector;

  HttpServer? _server;
  InternetAddress? _address;
  final Map<String, _GenaRoute> _routes = <String, _GenaRoute>{};
  bool _running = false;

  /// The start currently in flight, so concurrent subscribers join the
  /// same binding instead of the fast ones returning early and
  /// registering routes against a server that is not listening yet.
  Future<void>? _startFuture;

  /// Whether the server accepts NOTIFYs.
  bool get isRunning => _running;

  /// The bound port, once running.
  int? get boundPort => _server?.port;

  /// The LAN address callback URLs point at, once running.
  InternetAddress? get address => _address;

  /// How many callback routes are registered.
  int get routeCount => _routes.length;

  /// Starts the server. Idempotent, and single-flight: callers during a
  /// start await the one in progress.
  Future<void> start() {
    if (_running) {
      return Future<void>.value();
    }
    return _startFuture ??= _startNow();
  }

  Future<void> _startNow() async {
    try {
      _address = await _addressSelector();
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server = server;
      server.listen(
        _handle,
        onError: (Object _) {
          // Per-connection noise; the listening socket carries on.
        },
        cancelOnError: false,
      );
    } on Object {
      // Allow a later retry to run a fresh start.
      _startFuture = null;
      rethrow;
    }
    _running = true;
  }

  /// Registers a handler and returns the callback URL to put in the
  /// SUBSCRIBE's CALLBACK header.
  ///
  /// Throws [StateError] when the server is not running or no LAN
  /// address is known — a callback URL pointing nowhere produces
  /// subscriptions that silently never fire.
  Uri registerHandler(void Function(GenaNotification notification) onNotification) {
    if (!_running || _server == null || _address == null) {
      throw StateError('GENA callback server is not running');
    }
    final token = MediaRegistration.generateToken().substring(0, 16);
    _routes[token] = _GenaRoute(onNotification);
    return Uri.parse('http://${_address!.address}:${_server!.port}/gena/$token');
  }

  /// Unregisters a route; unknown URLs are ignored.
  void unregisterHandler(Uri callbackUrl) {
    final segments = callbackUrl.pathSegments;
    if (segments.length >= 2 && segments.first == 'gena') {
      _routes.remove(segments.last);
    }
  }

  /// Stops the server and drops every route.
  Future<void> stop() async {
    if (_startFuture != null && !_running) {
      try {
        await _startFuture;
      } on Object {
        // The start failed; there is nothing bound to stop.
      }
    }
    if (!_running) {
      return;
    }
    _running = false;
    _startFuture = null;
    _routes.clear();
    await _server?.close(force: true);
    _server = null;
    _address = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method.toUpperCase() != 'NOTIFY') {
        // §22.4: the callback endpoint accepts exactly one method.
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }
      final segments = request.uri.pathSegments;
      final route = segments.length == 2 && segments.first == 'gena' ? _routes[segments.last] : null;
      if (route == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final sid = request.headers.value('sid') ?? '';
      final seq = int.tryParse(request.headers.value('seq') ?? '') ?? -1;
      final body = await _readBounded(request);
      final notification = GenaNotification(sid: sid, seq: seq, variables: GenaMessageParser.parsePropertySet(body));

      if (seq <= route.lastSeq) {
        // §14.6: replayed or out-of-order events are acknowledged and
        // ignored — answering non-2xx would make some stacks retransmit
        // forever.
        await request.response.close();
        return;
      }
      route
        ..lastSeq = seq
        ..onNotification(notification);
      await request.response.close();
    } on Object {
      try {
        await request.response.close();
      } on Object {
        // The device vanished mid-NOTIFY; nothing further to do.
      }
    }
  }

  /// Reads the NOTIFY body with the package's response bound (§22.4):
  /// a device (or an impostor) that never finishes its answer cannot
  /// grow this process's heap.
  static Future<String> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length > maxCastResponseBodyBytes) {
        throw const FormatException('NOTIFY body exceeded the size limit');
      }
    }
    return utf8.decode(builder.toBytes(), allowMalformed: true);
  }
}

final class _GenaRoute {
  _GenaRoute(this.onNotification);

  final void Function(GenaNotification notification) onNotification;
  int lastSeq = -1;
}
