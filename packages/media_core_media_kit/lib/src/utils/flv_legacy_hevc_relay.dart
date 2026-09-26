import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Rewrites legacy "codec id 12" HEVC FLV video tags into Enhanced FLV.
///
/// Several CDNs extended classic FLV with HEVC as codec id 12 before Enhanced
/// RTMP existed. FFmpeg only learned that id in 8.0; the FFmpeg 7.1.3 inside
/// media_kit's bundled libmpv drops the stream and plays audio only. Enhanced
/// FLV (`hvc1` FourCC) is understood since FFmpeg 6.1, so only the tag header
/// changes: NAL payloads and the HEVCDecoderConfigurationRecord are copied.
class FlvLegacyHevcTagRewriter {
  static const int _legacyHevcCodecId = 12;
  static const List<int> _hvc1 = <int>[0x68, 0x76, 0x63, 0x31];

  int _rewrittenTags = 0;

  /// Number of tags converted so far, for diagnostics.
  int get rewrittenTags => _rewrittenTags;

  /// [tag] is one complete FLV tag including its trailing PreviousTagSize, as
  /// produced by [FlvTagFramer]. Anything else is returned unchanged.
  Uint8List rewrite(Uint8List tag) {
    if (tag.length < 11 + 5 + 4 || (tag[0] & 0x1f) != 9) return tag;
    final flags = tag[11];
    if ((flags & 0x80) != 0 || (flags & 0x0f) != _legacyHevcCodecId) return tag;
    final dataSize = (tag[1] << 16) | (tag[2] << 8) | tag[3];
    if (dataSize < 5 || 11 + dataSize + 4 != tag.length) return tag;
    final frameType = (flags >> 4) & 0x07;
    final packetType = tag[12];
    // Legacy: flags, AVCPacketType, CompositionTime(3), data.
    // Enhanced: flags|packetType, FourCC, [CompositionTime(3) for coded frames], data.
    final List<int> prefix;
    final int payloadStart;
    switch (packetType) {
      case 0: // Sequence header -> SequenceStart.
        prefix = <int>[0x80 | (frameType << 4), ..._hvc1];
        payloadStart = 16;
      case 1: // NALUs -> CodedFrames (keeps the composition time).
        prefix = <int>[0x80 | (frameType << 4) | 1, ..._hvc1, tag[13], tag[14], tag[15]];
        payloadStart = 16;
      case 2: // End of sequence -> SequenceEnd.
        prefix = <int>[0x80 | (frameType << 4) | 2, ..._hvc1];
        payloadStart = 11 + dataSize;
      default:
        return tag;
    }
    final payloadLength = 11 + dataSize - payloadStart;
    final newDataSize = prefix.length + payloadLength;
    if (newDataSize > 0xffffff) return tag;
    final out = Uint8List(11 + newDataSize + 4);
    out.setRange(0, 11, tag);
    out[1] = (newDataSize >> 16) & 0xff;
    out[2] = (newDataSize >> 8) & 0xff;
    out[3] = newDataSize & 0xff;
    out.setRange(11, 11 + prefix.length, prefix);
    out.setRange(11 + prefix.length, 11 + newDataSize, tag, payloadStart);
    ByteData.sublistView(out).setUint32(11 + newDataSize, 11 + newDataSize);
    _rewrittenTags++;
    return out;
  }
}

/// Splits an FLV byte stream into complete tags.
///
/// The stream is framed by DataSize rather than by the trailing
/// PreviousTagSize, which several FLV producers write incorrectly. The FLV
/// header and its initial zero-size field are yielded unchanged.
class FlvTagFramer {
  final BytesBuilder _pending = BytesBuilder(copy: false);
  int _expected = 9;
  int _phase = 0;

  /// Bytes held back until the next complete tag arrives.
  int get pendingBytes => _pending.length;

  /// Feeds [source] and yields every complete record it completes.
  ///
  /// Throws [FormatException] when the stream is not FLV.
  Iterable<Uint8List> add(List<int> source) sync* {
    final bytes = source is Uint8List ? source : Uint8List.fromList(source);
    var offset = 0;
    while (offset < bytes.length) {
      final take = min(_expected - _pending.length, bytes.length - offset);
      _pending.add(Uint8List.sublistView(bytes, offset, offset + take));
      offset += take;
      if (_pending.length != _expected) continue;
      final packet = _pending.takeBytes();
      if (_phase == 0) {
        if (packet[0] != 0x46 || packet[1] != 0x4c || packet[2] != 0x56 || packet[3] != 1) {
          throw const FormatException('Invalid FLV header');
        }
        final headerSize = ByteData.sublistView(packet).getUint32(5);
        if (headerSize < 9 || headerSize > 65536) throw const FormatException('Invalid FLV header size');
        _expected = headerSize + 4;
        _pending.add(packet);
        _phase = 1;
      } else if (_phase == 1) {
        if (ByteData.sublistView(packet).getUint32(packet.length - 4) != 0) {
          throw const FormatException('Invalid FLV initial tag size');
        }
        _expected = 11;
        _phase = 2;
        yield packet;
      } else if (_phase == 2) {
        final dataSize = (packet[1] << 16) | (packet[2] << 8) | packet[3];
        _expected = 11 + dataSize + 4;
        _pending.add(packet);
        _phase = 3;
      } else {
        // PreviousTagSize is unreliable in some FLV producers FFmpeg accepts.
        // DataSize defines the boundary; the trailing field is preserved.
        _expected = 11;
        _phase = 2;
        yield packet;
      }
    }
  }
}

/// Playback-only loopback relay that applies [FlvLegacyHevcTagRewriter].
///
/// Only hosts known to serve codec-id-12 HEVC are routed here, so ordinary FLV
/// keeps its direct native connection. Every local request opens its own
/// upstream connection, which keeps libmpv's own reconnect behaviour intact.
///
/// The relay is a normal HTTP server on loopback; the native player must reach
/// it directly, so a consumer that also configures a proxy has to exempt the
/// loopback URI from it.
class FlvLegacyHevcRelay {
  FlvLegacyHevcRelay._(this._server, this._upstream, this._headers, this._findProxy, this._secret);

  /// CDNs where codec-id-12 HEVC has been observed. On 17LIVE it depends on
  /// the broadcaster's encoder; AVC tags pass through the relay unchanged.
  static const Set<String> _hostSuffixes = <String>{
    '.livetech.shopee.co.id',
    '.livestream.shopee.co.id',
    '.17app.co',
  };

  final HttpServer _server;
  final Uri _upstream;
  final Map<String, String> _headers;
  final String Function(Uri) _findProxy;
  final String _secret;
  final Set<HttpClient> _clients = <HttpClient>{};
  final Set<Future<void>> _serving = <Future<void>>{};
  StreamSubscription<HttpRequest>? _requests;
  Future<void>? _closing;
  bool _closed = false;

  /// Whether the relay has been closed and must not be handed out again.
  bool get isClosed => _closed;

  /// The loopback URI the native player should open.
  Uri get inputUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: '/$_secret/live.flv');

  /// Whether [url] is a plain FLV from a CDN that serves legacy HEVC.
  static bool appliesTo(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase())) return false;
    if (!uri.path.toLowerCase().endsWith('.flv')) return false;
    final host = uri.host.toLowerCase();
    return _hostSuffixes.any(host.endsWith);
  }

  /// Binds the loopback server for [url].
  ///
  /// [findProxy] resolves the upstream connection exactly like the player
  /// would have, so a configured proxy keeps applying to the CDN request.
  static Future<FlvLegacyHevcRelay> start(
    String url,
    Map<String, String> headers, {
    required String Function(Uri) findProxy,
  }) async {
    if (!appliesTo(url)) throw const FormatException('Expected a legacy HEVC FLV input');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    final random = Random.secure();
    final secret = base64UrlEncode(List<int>.generate(18, (_) => random.nextInt(256))).replaceAll('=', '');
    final relay = FlvLegacyHevcRelay._(server, Uri.parse(url), Map<String, String>.unmodifiable(headers), findProxy, secret);
    relay._requests = server.listen((request) {
      if (request.method != 'GET' || request.uri.path != relay.inputUri.path || relay._closed) {
        unawaited(_reject(request, HttpStatus.notFound));
        return;
      }
      late final Future<void> serving;
      serving = relay._serve(request).whenComplete(() => relay._serving.remove(serving));
      relay._serving.add(serving);
    });
    return relay;
  }

  Future<void> _serve(HttpRequest downstream) async {
    final client = HttpClient()
      ..findProxy = _findProxy
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = true;
    _clients.add(client);
    var sent = false;
    try {
      final request = await client.getUrl(_upstream);
      _headers.forEach((name, value) => request.headers.set(name, value));
      final upstream = await request.close().timeout(const Duration(seconds: 20));
      if (upstream.statusCode != HttpStatus.ok) {
        downstream.response.statusCode = upstream.statusCode;
        return;
      }
      downstream.response.headers.contentType = ContentType('video', 'x-flv');
      downstream.response.headers.set('cache-control', 'no-store');
      downstream.response.bufferOutput = false;
      final framer = FlvTagFramer();
      final rewriter = FlvLegacyHevcTagRewriter();
      await for (final chunk in upstream) {
        if (_closed) break;
        for (final packet in framer.add(chunk)) {
          downstream.response.add(rewriter.rewrite(packet));
          sent = true;
        }
        await downstream.response.flush();
      }
    } catch (_) {
      if (!sent) {
        try {
          downstream.response.statusCode = HttpStatus.badGateway;
        } on StateError {
          /* Headers already sent. */
        }
      }
    } finally {
      try {
        await downstream.response.close();
      } on Object {
        /* The native reader may already have gone. */
      }
      _clients.remove(client);
      client.close(force: true);
    }
  }

  /// Closes the server and every upstream connection. Idempotent.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    await _server.close(force: true);
    await _requests?.cancel();
    await Future.wait(_serving.toList());
  }

  static Future<void> _reject(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      await request.response.close();
    } on Object {
      /* Peer closed its request. */
    }
  }
}
