import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:media_core_ingest/src/relay/flv_splice.dart';
import 'package:media_core_logging/media_core_logging.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// One upstream address as the relay opens it: the signed URL, the request
/// headers minted with it and when its lease comes due.
///
/// Providers hand out the URL, its headers and an expiry as one bundle and a
/// renewal mints a new bundle, so the relay carries them together instead of
/// letting a renewed URL keep stale headers.
final class FlvUpstreamAddress {
  /// Creates the address; a null [refreshAt] means it does not expire alone.
  const FlvUpstreamAddress({required this.uri, this.headers = const <String, String>{}, this.refreshAt});

  /// The URL to open.
  final Uri uri;

  /// The request headers minted with [uri].
  final Map<String, String> headers;

  /// When the address's lease comes due and a renewal should be prepared.
  ///
  /// Null means the address does not cut its connection on its own; the relay
  /// then renews only when the connection dies early.
  final DateTime? refreshAt;
}

/// Fetches the successor of [current] when its lease comes due: a fresh
/// [FlvUpstreamAddress] for the same stream.
///
/// Throwing (or letting [FlvRelayTimings.renewTimeout] win) marks the attempt
/// failed; the relay keeps the old connection streaming and tries again after
/// [FlvRelayTimings.retryDelay].
typedef FlvUpstreamRenewer = Future<FlvUpstreamAddress> Function(FlvUpstreamAddress current);

/// The relay's lifecycle limits; the defaults follow the reference behaviour
/// of a 12 s renewal wait, 15 s connects and keyframe searches, a 10 s
/// handover, a 10 s renewal retry and a 15 s upstream idle gap.
final class FlvRelayTimings {
  /// Creates the limits.
  const FlvRelayTimings({
    this.renewTimeout = const Duration(seconds: 12),
    this.connectTimeout = const Duration(seconds: 15),
    this.keyframeSearch = const Duration(seconds: 15),
    this.handoverWait = const Duration(seconds: 10),
    this.retryDelay = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 15),
  });

  /// Longest wait for the renewal callback.
  final Duration renewTimeout;

  /// Longest wait for a new upstream's connect and its header.
  final Duration connectTimeout;

  /// Longest search for a usable keyframe on a renewed connection.
  final Duration keyframeSearch;

  /// Longest wait at an armed splice point: for the old stream to reach the
  /// new keyframe once the plan is armed, and for a held old keyframe while
  /// the renewal is still hunting for its own.
  final Duration handoverWait;

  /// Wait before another renewal attempt while the old connection streams.
  final Duration retryDelay;

  /// How long an upstream may go without a byte before it counts as ended.
  final Duration idleTimeout;
}

/// Something the relay did while serving one stream.
sealed class FlvRelayEvent {
  /// Creates the event.
  const FlvRelayEvent();
}

/// The output continued on a renewed address.
final class FlvRelaySwitched extends FlvRelayEvent {
  /// Creates the event.
  const FlvRelaySwitched({required this.address, required this.switchAt, required this.shifted});

  /// The address now streaming.
  final FlvUpstreamAddress address;

  /// Output timestamp of the first keyframe of the new connection, in ms.
  final int switchAt;

  /// Whether the new connection sat on another timeline and was shifted.
  final bool shifted;

  @override
  String toString() => 'switched to ${address.uri.host} at ${switchAt}ms${shifted ? ' (shifted)' : ''}';
}

/// A renewal attempt failed; the old connection keeps streaming.
final class FlvRelayRenewalFailed extends FlvRelayEvent {
  /// Creates the event.
  const FlvRelayRenewalFailed(this.error);

  /// What failed.
  final Object error;

  @override
  String toString() => 'renewal failed: $error';
}

/// The spliced output ended: the upstream died without a successor, an
/// upstream failed outright, or [FlvLoopbackRelay.close] ran.
final class FlvRelayEnded extends FlvRelayEvent {
  /// Creates the event.
  const FlvRelayEnded(this.reason);

  /// Why.
  final String reason;

  @override
  String toString() => 'ended: $reason';
}

/// Splits an upstream FLV byte stream into packets: the file header (with its
/// PreviousTagSize0) first, then one complete tag per packet, per the Adobe
/// FLV specification v10.1 annex E.
final class _FlvFramer {
  var _buffer = Uint8List(64 * 1024);
  var _start = 0;
  var _end = 0;
  var _headerDone = false;

  /// Adds [chunk] and answers every packet it completed. Throws
  /// [FormatException] when the stream is not FLV or a tag type is invalid.
  List<Uint8List> add(List<int> chunk) {
    _append(chunk);
    final packets = <Uint8List>[];
    while (true) {
      final available = _end - _start;
      if (!_headerDone) {
        if (available < 9) break;
        if (_buffer[_start] != 0x46 || _buffer[_start + 1] != 0x4C || _buffer[_start + 2] != 0x56) {
          throw const FormatException('Not an FLV stream');
        }
        final dataOffset = ByteData.sublistView(_buffer, _start + 5, _start + 9).getUint32(0);
        if (dataOffset < 9 || dataOffset > 1024) {
          throw FormatException('Bad FLV header length $dataOffset');
        }
        if (available < dataOffset + 4) break;
        packets.add(Uint8List.fromList(Uint8List.sublistView(_buffer, _start, _start + dataOffset + 4)));
        _start += dataOffset + 4;
        _headerDone = true;
        continue;
      }
      if (available < FlvTagProbe.headerLength) break;
      final type = _buffer[_start] & 0x1f;
      if (type != FlvTagProbe.audio && type != FlvTagProbe.video && type != FlvTagProbe.script) {
        throw FormatException('Bad FLV tag type $type');
      }
      final size = (_buffer[_start + 1] << 16) | (_buffer[_start + 2] << 8) | _buffer[_start + 3];
      final total = FlvTagProbe.headerLength + size + 4;
      if (available < total) break;
      packets.add(Uint8List.fromList(Uint8List.sublistView(_buffer, _start, _start + total)));
      _start += total;
    }
    if (_start == _end) {
      _start = 0;
      _end = 0;
    }
    return packets;
  }

  void _append(List<int> chunk) {
    final needed = _end + chunk.length;
    if (needed > _buffer.length) {
      final live = _end - _start;
      if (live + chunk.length <= _buffer.length && _start > 0) {
        _buffer.setRange(0, live, _buffer, _start);
      } else {
        var capacity = _buffer.length;
        while (capacity < live + chunk.length) {
          capacity *= 2;
        }
        final grown = Uint8List(capacity)..setRange(0, live, _buffer, _start);
        _buffer = grown;
      }
      _start = 0;
      _end = live;
    }
    _buffer.setRange(_end, _end + chunk.length, chunk);
    _end += chunk.length;
  }
}

/// One upstream FLV connection as packets: the file header first, then tags.
///
/// `next` answers null once the connection ended (clean close, reset, an
/// [FlvRelayTimings.idleTimeout] gap or a framing error); the pump decides
/// what follows. `cancel` is safe on an already-dead connection.
abstract interface class _FlvUpstreamSource {
  /// The next packet, or null once the connection ended.
  Future<Uint8List?> next();

  /// Drops the connection.
  Future<void> cancel();
}

/// A non-200 answer from an upstream FLV request.
final class _FlvUpstreamStatusException implements Exception {
  const _FlvUpstreamStatusException(this.status, this.url);

  final int status;
  final Uri url;

  @override
  String toString() => 'Upstream answered HTTP $status for ${url.host}';
}

/// Opens [FlvUpstreamAddress.uri] over `dart:io` and frames the body.
final class _HttpFlvSource implements _FlvUpstreamSource {
  _HttpFlvSource._(this._client, Stream<List<int>> body, this._idleTimeout) {
    _subscription = body.listen(
      _onChunk,
      onError: (Object error, StackTrace _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
  }

  /// Opens [uri] as an FLV source. The client is the connection's own: open
  /// failures and [cancel] close it, so a dead upstream leaves nothing behind.
  static Future<_FlvUpstreamSource> open({
    required Uri uri,
    required Map<String, String> headers,
    required Duration connectTimeout,
    required Duration idleTimeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      // A CDN answering gzip on the media request would corrupt the framing;
      // live FLV travels identity-encoded, so negotiation stays off.
      ..autoUncompress = false;
    try {
      final request = await client.getUrl(uri).timeout(connectTimeout);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(connectTimeout);
      if (response.statusCode != HttpStatus.ok) {
        unawaited(response.drain<void>().catchError((Object _) {}));
        throw _FlvUpstreamStatusException(response.statusCode, uri);
      }
      return _HttpFlvSource._(client, response, idleTimeout);
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }

  static const _pauseAbove = 2048;
  static const _resumeBelow = 512;

  final HttpClient _client;
  final Duration _idleTimeout;
  final _framer = _FlvFramer();
  final _queue = ListQueue<Uint8List>();
  late final StreamSubscription<List<int>> _subscription;
  Completer<void>? _waiter;
  Timer? _idle;
  var _done = false;

  void _onChunk(List<int> chunk) {
    try {
      _queue.addAll(_framer.add(chunk));
    } on FormatException {
      _finish();
      unawaited(_subscription.cancel());
      return;
    }
    _wake();
    if (_queue.length > _pauseAbove && !_subscription.isPaused) _subscription.pause();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _idle?.cancel();
    _wake();
  }

  void _wake() {
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  @override
  Future<Uint8List?> next() async {
    while (_queue.isEmpty) {
      if (_done) return null;
      if (_subscription.isPaused) _subscription.resume();
      _idle ??= Timer(_idleTimeout, () {
        _finish();
        unawaited(_subscription.cancel());
        _client.close(force: true);
      });
      await (_waiter ??= Completer<void>()).future;
      _idle?.cancel();
      _idle = null;
    }
    final packet = _queue.removeFirst();
    if (_queue.length < _resumeBelow && _subscription.isPaused && !_done) _subscription.resume();
    return packet;
  }

  @override
  Future<void> cancel() async {
    _finish();
    _queue.clear();
    _client.close(force: true);
    try {
      await _subscription.cancel();
    } on Object {
      // Already failed.
    }
  }
}

/// A renewal found and armed: the new connection past its header, its usable
/// keyframe and what must travel with the cut.
final class _Candidate {
  _Candidate({
    required this.source,
    required this.address,
    required this.plan,
    required this.keyframe,
    required this.videoConfig,
    required this.audioConfig,
    required this.audioBefore,
  });

  final _FlvUpstreamSource source;
  final FlvUpstreamAddress address;

  /// Where the connection joins the output; from the pure decision layer.
  final FlvSplicePlan plan;

  /// The first usable keyframe of the connection.
  final Uint8List keyframe;

  /// The connection's codec configurations, when it sent any before its
  /// keyframe; re-sent at the cut only when the payload changed.
  final Uint8List? videoConfig;
  final Uint8List? audioConfig;

  /// Audio delivered before the keyframe, so the splice does not open an
  /// audio gap; capped, because a connection that never reaches a keyframe
  /// must not buffer forever.
  final ListQueue<Uint8List> audioBefore;

  /// When the candidate became ready; the handover deadline runs from here.
  DateTime? readyAt;
}

/// Serves one continuous FLV byte stream on the loopback while its upstream
/// address expires underneath it.
///
/// A live FLV source signs its URL for a short lease: the connection is cut
/// mid-stream and the reader would have to recover on its own. The relay takes
/// that cut over. It hands the reader `http://127.0.0.1:<port>/<secret>/live.flv`
/// and keeps the byte stream alive across renewals: when the lease's
/// `refreshAt` comes due it asks the [FlvUpstreamRenewer] for a fresh address,
/// opens the new connection while the old one keeps streaming, and applies the
/// pure splice decisions (`FlvSplicePolicy`, `FlvSplicePlan`,
/// `FlvSpliceTimeline`) to move over at the first keyframe the output has not
/// delivered - timestamps shifted to stay monotonic, the script tag sent once,
/// codec configurations re-sent only when the payload changes. A connection on
/// another timeline (beyond the policy's alignment window) is shifted to
/// continue the delivered one. A failed renewal keeps the old connection and
/// retries after [FlvRelayTimings.retryDelay]; an old stream that ends brings
/// its successor in at once, and without one the output ends.
///
/// The relay is deliberately small and per-source, like the package's other
/// relays: one upstream bundle, one secret, one byte stream. It binds to
/// 127.0.0.1 only and answers nothing but the secret path - anything else
/// gets a bare 404.
///
/// `close` ends the served responses with a clean body end rather than an
/// ending tag: FLV has no end-of-stream marker to write, and completing the
/// HTTP body is what lets a reader drain what it buffered and finish
/// gracefully - the same reason ending the upstream ends a recording's FFmpeg
/// read cleanly.
final class FlvLoopbackRelay {
  FlvLoopbackRelay._({
    required HttpServer server,
    required FlvUpstreamAddress current,
    required FlvUpstreamRenewer? renew,
    required FlvSplicePolicy policy,
    required FlvRelayTimings timings,
    required String secret,
    required void Function(FlvRelayEvent event)? onEvent,
  }) : _server = server,
       _port = server.port,
       _current = current,
       _renew = renew,
       _policy = policy,
       _timings = timings,
       _secret = secret,
       _onEvent = onEvent;

  /// Starts the relay for [upstream]. The returned relay owns the port until
  /// [close]; callers hand [inputUri] to the reader.
  ///
  /// [refreshAt] schedules the first renewal ([renew] then answers the fresh
  /// [FlvUpstreamAddress]); leaving it null means the address does not expire
  /// alone and the relay never renews proactively - with a [renew] present it
  /// still renews when the connection dies early. [proxy] is an optional
  /// `host:port` the upstream requests go through.
  static Future<FlvLoopbackRelay> start({
    required Uri upstream,
    Map<String, String> headers = const <String, String>{},
    DateTime? refreshAt,
    FlvUpstreamRenewer? renew,
    String? proxy,
    FlvSplicePolicy policy = const FlvSplicePolicy(),
    FlvRelayTimings timings = const FlvRelayTimings(),
    void Function(FlvRelayEvent event)? onEvent,
  }) async {
    if (!const <String>{'http', 'https'}.contains(upstream.scheme.toLowerCase()) || upstream.host.isEmpty) {
      throw ArgumentError.value(upstream, 'upstream', 'The FLV relay needs an http(s) upstream');
    }
    if (renew == null && refreshAt != null) {
      throw ArgumentError('An expiring address needs a renew callback');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = FlvLoopbackRelay._(
      server: server,
      current: FlvUpstreamAddress(
        uri: upstream,
        headers: Map<String, String>.unmodifiable(headers),
        refreshAt: refreshAt,
      ),
      renew: renew,
      policy: policy,
      timings: timings,
      secret: _newSecret(),
      onEvent: onEvent,
    );
    server.listen(
      relay._handle,
      onError: (Object error) {
        // Server-socket errors are mostly reader disconnects while the relay
        // closes; they never kill the relay.
        _log.debug('flv relay server error', fields: <String, Object?>{'port': server.port, 'error': error.toString()});
      },
      cancelOnError: false,
    );
    return relay;
  }

  static final Random _random = Random.secure();

  static String _newSecret() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(24, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }

  final HttpServer _server;

  /// Captured at start: a closed [HttpServer] no longer reports its port, and
  /// [inputUri] stays meaningful for diagnostics after [close].
  final int _port;
  FlvUpstreamAddress _current;
  final FlvUpstreamRenewer? _renew;
  final FlvSplicePolicy _policy;
  final FlvRelayTimings _timings;
  final String _secret;
  final void Function(FlvRelayEvent event)? _onEvent;
  final Set<_FlvSplicePump> _pumps = <_FlvSplicePump>{};
  final Set<Future<void>> _serving = <Future<void>>{};
  Future<FlvUpstreamAddress>? _renewing;
  var _closed = false;

  /// The URL the reader opens.
  Uri get inputUri =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _port, path: '/$_secret/live.flv');

  /// Whether [close] has run; a closed relay is no longer a usable input.
  bool get isClosed => _closed;

  Future<void> _handle(HttpRequest request) async {
    if (!_closed && request.method == 'GET' && request.uri.path == '/$_secret/live.flv') {
      final serving = _serve(request);
      _serving.add(serving);
      unawaited(serving.whenComplete(() => _serving.remove(serving)));
      await serving;
      return;
    }
    // Anything else on the port is not ours: a probe gets a bare 404 and no
    // echo of the secret's shape.
    try {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } on Object {
      // The peer went away.
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    var started = false;
    final pump = _FlvSplicePump(
      address: _current,
      open: _openUpstream,
      renew: _renew == null ? null : _renewShared,
      policy: _policy,
      timings: _timings,
      emit: (packet) {
        if (!started) {
          started = true;
          response
            ..statusCode = HttpStatus.ok
            ..bufferOutput = false
            ..headers.contentType = ContentType('video', 'x-flv')
            ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        }
        response.add(packet);
      },
      onEvent: _handlePumpEvent,
    );
    _pumps.add(pump);
    // The reader hanging up ends this pump; every other exit path closes the
    // response, which lands here too.
    unawaited(response.done.then((_) {}, onError: (Object _) {}).whenComplete(pump.cancel));
    try {
      await pump.run();
    } on Object catch (error) {
      _log.warning('flv relay lost its stream', error: error, fields: <String, Object?>{'upstream': _current.uri.host});
      _onEvent?.call(FlvRelayEnded('upstream failed: $error'));
      if (!started) {
        try {
          response.statusCode = HttpStatus.badGateway;
        } on Object {
          // Headers already sent.
        }
      }
    } finally {
      _pumps.remove(pump);
      try {
        await response.close();
      } on Object {
        // The reader already went away.
      }
    }
  }

  void _handlePumpEvent(FlvRelayEvent event) {
    final switched = event is FlvRelaySwitched ? event : null;
    if (switched != null) {
      _current = switched.address;
      _log.info(
        'flv relay switched upstream',
        fields: <String, Object?>{
          'upstream': switched.address.uri.host,
          'switchAt': switched.switchAt,
          'shifted': switched.shifted,
        },
      );
    }
    _onEvent?.call(event);
  }

  /// One renewal per lease for concurrent readers: a reader that asks with a
  /// stale address is handed the current one instead of calling out again.
  Future<FlvUpstreamAddress> _renewShared(FlvUpstreamAddress current) {
    final renew = _renew!;
    if (current.uri != _current.uri) {
      return Future<FlvUpstreamAddress>.value(_current);
    }
    return _renewing ??= renew(current).whenComplete(() => _renewing = null);
  }

  Future<_FlvUpstreamSource> _openUpstream(FlvUpstreamAddress address) => _HttpFlvSource.open(
    uri: address.uri,
    headers: address.headers,
    connectTimeout: _timings.connectTimeout,
    idleTimeout: _timings.idleTimeout,
  );

  /// Stops the relay: every served response ends (see the class doc for why a
  /// clean body end is the ending), every upstream connection drops and the
  /// port closes.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(<Future<void>>[for (final pump in _pumps.toList()) pump.cancel()]);
    // The pumps stop before the served responses do: give them the moment
    // they need to write their clean body end, or closing the port with
    // `force` would tear the last bytes off the wire.
    if (_serving.isNotEmpty) {
      await Future.wait(<Future<void>>[for (final serving in _serving.toList()) serving.catchError((Object _) {})]);
    }
    try {
      await _server.close(force: true);
    } on Object {
      // A server that already died has nothing to close.
    }
  }
}

/// One served connection: pumps the spliced byte stream into one response.
///
/// The pump owns lifecycle and byte moving only. Every decision - where a
/// renewed connection joins, whether an old tag is already delivered, which
/// tags survive the cut - comes from `FlvSplicePolicy`, `FlvSplicePlan` and
/// `FlvSpliceTimeline`; the pump wires their answers to sockets and timers.
final class _FlvSplicePump {
  _FlvSplicePump({
    required FlvUpstreamAddress address,
    required Future<_FlvUpstreamSource> Function(FlvUpstreamAddress address) open,
    required Future<FlvUpstreamAddress> Function(FlvUpstreamAddress address)? renew,
    required FlvSplicePolicy policy,
    required FlvRelayTimings timings,
    required void Function(Uint8List packet) emit,
    required void Function(FlvRelayEvent event) onEvent,
  }) : _address = address,
       _open = open,
       _renew = renew,
       _policy = policy,
       _timings = timings,
       _emit = emit,
       _onEvent = onEvent;

  FlvUpstreamAddress _address;
  final Future<_FlvUpstreamSource> Function(FlvUpstreamAddress address) _open;
  final Future<FlvUpstreamAddress> Function(FlvUpstreamAddress address)? _renew;
  final FlvSplicePolicy _policy;
  final FlvRelayTimings _timings;
  final void Function(Uint8List packet) _emit;
  final void Function(FlvRelayEvent event) _onEvent;

  /// The delivered output's ledger; owns offsets, monotonicity, script-once
  /// and the codec configurations.
  final FlvSpliceTimeline _timeline = FlvSpliceTimeline();

  _FlvUpstreamSource? _source;
  Future<Uint8List?>? _pending;
  _Candidate? _ready;
  Future<_Candidate?>? _preparing;
  var _scanning = false;
  var _oldEnded = false;
  var _cancelled = false;

  Timer? _renewTimer;
  Timer? _handoverTimer;
  Timer? _holdTimer;
  DateTime? _holdUntil;
  var _holdUsed = false;
  Uint8List? _held;
  Completer<void>? _wake;
  final Object _woken = Object();

  bool get _holdExpired {
    final until = _holdUntil;
    return until == null || !DateTime.now().isBefore(until);
  }

  /// Pumps until the output ends: [cancel] or the reader going away stops it,
  /// an upstream that ends without a successor ends it, and a first
  /// connection that cannot be opened throws to the caller (the response
  /// answers 502).
  Future<void> run() async {
    try {
      final first = await _open(_address);
      if (_cancelled) {
        await first.cancel();
        return;
      }
      _source = first;
      final header = await first.next();
      if (header == null) {
        throw const FormatException('Empty FLV upstream');
      }
      _emit(header);
      _scheduleRenewal();
      while (!_cancelled) {
        final ready = _ready;
        if (ready != null && (!ready.plan.isSameTimeline || _handoverExpired(ready))) {
          await _switchTo(ready);
          continue;
        }
        final Uint8List tag;
        final held = _held;
        if (held != null) {
          if (ready == null && _preparing != null && !_holdExpired) {
            await (_wake ??= Completer<void>()).future;
            continue;
          }
          _held = null;
          _holdTimer?.cancel();
          tag = held;
        } else {
          final packet = await _nextOrWake();
          if (_cancelled) break;
          if (identical(packet, _woken)) continue;
          if (packet == null) {
            final successor = await _afterOldEnded();
            if (successor == null) {
              _onEvent(const FlvRelayEnded('upstream ended without a successor'));
              return;
            }
            await _switchTo(successor);
            continue;
          }
          tag = packet as Uint8List;
          if (_ready == null && _scanning && !_holdUsed && FlvTagProbe.isVideoKeyframe(tag)) {
            // Both connections sit at the live edge, so the old one would
            // usually deliver the shared keyframe first and push the switch
            // to a later GOP. Hold the old stream just before its keyframe
            // until the new connection reaches it, or the handover expires.
            _held = tag;
            _holdUsed = true;
            _holdUntil = DateTime.now().add(_timings.handoverWait);
            _holdTimer = Timer(_timings.handoverWait, _signal);
            continue;
          }
        }
        final current = _ready;
        if (current != null && current.plan.isSameTimeline) {
          final action = current.plan.judgeOldTag(tag);
          if (action == FlvSpliceOldTagAction.switchNow) {
            await _switchTo(current);
            continue;
          }
          if (action == FlvSpliceOldTagAction.drop) continue;
        }
        _forward(tag);
      }
    } finally {
      await _teardown();
    }
  }

  /// Stops the output and drops every connection; safe to run twice.
  Future<void> cancel() async {
    _cancelled = true;
    _signal();
    await _teardown();
  }

  void _signal() {
    final wake = _wake;
    _wake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Reads the old stream while staying interruptible by timers and by a
  /// renewal settling.
  Future<Object?> _nextOrWake() async {
    final source = _source!;
    final pending = _pending ??= source.next();
    final wake = _wake ??= Completer<void>();
    final result = await Future.any<Object?>([pending, wake.future.then((_) => _woken)]);
    if (!identical(result, _woken)) {
      _pending = null;
      if (identical(_wake, wake)) _wake = null;
    }
    return result;
  }

  void _scheduleRenewal() {
    _renewTimer?.cancel();
    final refreshAt = _address.refreshAt;
    if (refreshAt == null || _renew == null) return;
    var delay = refreshAt.difference(DateTime.now());
    if (delay < Duration.zero) delay = Duration.zero;
    _renewTimer = Timer(delay, _startPreparing);
  }

  void _startPreparing() {
    if (_cancelled || _renew == null || _preparing != null || _ready != null) return;
    _holdUsed = false;
    final attempt = _prepare();
    _preparing = attempt;
    unawaited(
      attempt.then((candidate) {
        if (!identical(_preparing, attempt)) return;
        _preparing = null;
        _scanning = false;
        if (_cancelled) {
          if (candidate != null) unawaited(candidate.source.cancel());
          return;
        }
        if (candidate != null) {
          candidate.readyAt = DateTime.now();
          _ready = candidate;
          if (candidate.plan.isSameTimeline) {
            _handoverTimer?.cancel();
            _handoverTimer = Timer(_timings.handoverWait, _signal);
          }
        } else if (!_oldEnded) {
          _renewTimer?.cancel();
          _renewTimer = Timer(_timings.retryDelay, _startPreparing);
        }
        _signal();
      }),
    );
  }

  /// The old stream ended: an armed candidate takes over at once, otherwise a
  /// renewal is started now (a lease not yet due included - the address died
  /// early), and with no successor the output ends.
  Future<_Candidate?> _afterOldEnded() async {
    _oldEnded = true;
    final ready = _ready;
    if (ready != null) return ready;
    var preparing = _preparing;
    if (preparing == null) {
      _renewTimer?.cancel();
      _startPreparing();
      preparing = _preparing;
    }
    if (preparing == null) return null;
    await preparing;
    return _ready;
  }

  /// One renewal attempt: fresh address, new connection, keyframe search. The
  /// search judges every keyframe candidate through the decision layer - a
  /// plan at or behind what the old stream already delivered keeps the search
  /// going, the first usable one arms the splice.
  Future<_Candidate?> _prepare() async {
    _FlvUpstreamSource? source;
    try {
      final next = await _renew!(_address).timeout(_timings.renewTimeout);
      if (_cancelled) return null;
      source = await _open(next).timeout(_timings.connectTimeout);
      if (_cancelled) {
        await source.cancel();
        return null;
      }
      if (await source.next().timeout(_timings.connectTimeout) == null) {
        throw const FormatException('Empty FLV upstream');
      }
      _scanning = true;
      final searchEnd = DateTime.now().add(_timings.keyframeSearch);
      Uint8List? videoConfig;
      Uint8List? audioConfig;
      final audioBefore = ListQueue<Uint8List>();
      while (true) {
        final remaining = searchEnd.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('No keyframe on the new connection');
        }
        final tag = await source.next().timeout(remaining);
        if (_cancelled) {
          await source.cancel();
          return null;
        }
        if (tag == null) {
          throw const FormatException('New connection ended before a keyframe');
        }
        final type = FlvTagProbe.type(tag);
        if (FlvTagProbe.isVideoConfig(tag)) {
          videoConfig = tag;
          continue;
        }
        if (FlvTagProbe.isAudioConfig(tag)) {
          audioConfig = tag;
          continue;
        }
        if (type == FlvTagProbe.audio) {
          audioBefore.add(tag);
          if (audioBefore.length > 256) audioBefore.removeFirst();
          continue;
        }
        if (type != FlvTagProbe.video || !FlvTagProbe.isVideoKeyframe(tag)) continue;
        final plan = _policy.planConnection(
          keyframeTimestamp: FlvTagProbe.timestamp(tag),
          deliveredLastVideo: _timeline.deliveredLastVideo,
          deliveredOffset: _timeline.outputOffset,
        );
        if (plan.isAlreadyDelivered(deliveredLastVideo: _timeline.deliveredLastVideo)) continue;
        return _Candidate(
          source: source,
          address: next,
          plan: plan,
          keyframe: tag,
          videoConfig: videoConfig,
          audioConfig: audioConfig,
          audioBefore: audioBefore,
        );
      }
    } on Object catch (error) {
      if (source != null) unawaited(source.cancel());
      if (!_cancelled) {
        _log.debug('flv relay renewal attempt failed', error: error);
        _onEvent(FlvRelayRenewalFailed(error));
      }
      return null;
    }
  }

  bool _handoverExpired(_Candidate candidate) {
    final readyAt = candidate.readyAt;
    return readyAt != null && DateTime.now().difference(readyAt) >= _timings.handoverWait;
  }

  /// Moves the output onto [candidate]: the old connection drops, the ledger
  /// adopts the plan, and the cut travels with the keyframe - the connection's
  /// configurations (only when the payload changed), its pre-keyframe audio
  /// and then the keyframe itself, all through the ledger.
  Future<void> _switchTo(_Candidate candidate) async {
    _ready = null;
    _handoverTimer?.cancel();
    // The held tag belongs to the old connection; once switched it must not
    // surface on the new timeline.
    _held = null;
    _holdTimer?.cancel();
    final old = _source;
    _pending?.ignore();
    _pending = null;
    _source = candidate.source;
    if (old != null) unawaited(old.cancel());
    _oldEnded = false;

    final plan = candidate.plan;
    _timeline.adopt(plan);
    _address = candidate.address;

    final keyframe = candidate.keyframe;
    final keyRaw = FlvTagProbe.timestamp(keyframe);
    final videoConfig = candidate.videoConfig;
    if (videoConfig != null && _timeline.needsVideoConfig(videoConfig)) {
      _forward(FlvTagProbe.withTimestamp(videoConfig, keyRaw));
    }
    final audioBefore = candidate.audioBefore;
    final firstAudio = audioBefore.isEmpty ? keyRaw : FlvTagProbe.timestamp(audioBefore.first);
    final audioConfig = candidate.audioConfig;
    if (audioConfig != null && _timeline.needsAudioConfig(audioConfig)) {
      _forward(FlvTagProbe.withTimestamp(audioConfig, firstAudio));
    }
    audioBefore.forEach(_forward);
    _forward(keyframe);
    _onEvent(FlvRelaySwitched(address: candidate.address, switchAt: plan.switchAt, shifted: !plan.isSameTimeline));
    _scheduleRenewal();
  }

  void _forward(Uint8List tag) {
    final out = _timeline.accept(tag);
    if (out != null) _emit(out);
  }

  Future<void> _teardown() async {
    _renewTimer?.cancel();
    _handoverTimer?.cancel();
    _holdTimer?.cancel();
    _held = null;
    final ready = _ready;
    _ready = null;
    final source = _source;
    _source = null;
    _pending?.ignore();
    _pending = null;
    _signal();
    await Future.wait(<Future<void>>[?ready?.source.cancel(), ?source?.cancel()]);
  }
}
