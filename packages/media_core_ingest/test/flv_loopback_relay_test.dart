import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_ingest/media_core_ingest.dart';

// Minimal legal FLV bytes, handwritten per the Adobe FLV specification annex
// E: a 13-byte file header and complete tags (11-byte header, payload,
// PreviousTagSize). The video tags carry an AVC-shaped first payload byte, so
// the decision layer's probe reads them as configs, keyframes and interframes.

const int _audio = 8;
const int _video = 9;
const int _script = 18;

const List<int> _videoConfigV1 = <int>[0x17, 0x00, 0x00, 0x00, 0x00, 1, 2, 3, 4];
const List<int> _videoConfigV2 = <int>[0x17, 0x00, 0x00, 0x00, 0x00, 9, 9, 9, 9];
const List<int> _audioConfigA1 = <int>[0xA0, 0x00, 0x12, 0x10];
const List<int> _audioConfigA2 = <int>[0xA0, 0x00, 0x13, 0x10];

Uint8List _fileHeader() => Uint8List.fromList(const <int>[0x46, 0x4C, 0x56, 1, 5, 0, 0, 0, 9, 0, 0, 0, 0]);

Uint8List _tag(int type, int timestamp, List<int> data) {
  final tag = Uint8List(11 + data.length + 4);
  final value = timestamp & 0xffffffff;
  tag
    ..[0] = type
    ..[1] = (data.length >> 16) & 0xff
    ..[2] = (data.length >> 8) & 0xff
    ..[3] = data.length & 0xff
    ..[4] = (value >> 16) & 0xff
    ..[5] = (value >> 8) & 0xff
    ..[6] = value & 0xff
    ..[7] = (value >> 24) & 0xff
    ..setRange(11, 11 + data.length, data);
  ByteData.sublistView(tag).setUint32(11 + data.length, 11 + data.length);
  return tag;
}

Uint8List _scriptTag(int timestamp) => _tag(_script, timestamp, const <int>[0x02, 0x6F, 0x6E]);

Uint8List _videoConfigTag(int timestamp, List<int> payload) => _tag(_video, timestamp, payload);

Uint8List _videoTag(int timestamp, {bool key = false}) =>
    _tag(_video, timestamp, <int>[if (key) 0x17 else 0x27, 0x01, 0x00, 0x00, 0x00, 5, 6, 7, 8]);

Uint8List _audioConfigTag(int timestamp, List<int> payload) => _tag(_audio, timestamp, payload);

Uint8List _audioTag(int timestamp) => _tag(_audio, timestamp, const <int>[0xAF, 0x01, 9, 9]);

(int, int) _pair(Uint8List tag) => (tag[0] & 0x1f, (tag[7] << 24) | (tag[4] << 16) | (tag[5] << 8) | tag[6]);

/// Lifecycle limits tuned for tests: everything is fast on the loopback, so
/// only the waits the tests exercise are kept long enough to be readable.
const _timings = FlvRelayTimings(
  renewTimeout: Duration(seconds: 5),
  connectTimeout: Duration(seconds: 5),
  keyframeSearch: Duration(seconds: 5),
  handoverWait: Duration(milliseconds: 500),
  retryDelay: Duration(milliseconds: 200),
  idleTimeout: Duration(seconds: 30),
);

/// The same, with a handover wait long enough that the old stream (not the
/// deadline) decides when the cut happens.
const _patientHandover = FlvRelayTimings(
  renewTimeout: Duration(seconds: 5),
  connectTimeout: Duration(seconds: 5),
  keyframeSearch: Duration(seconds: 5),
  handoverWait: Duration(seconds: 2),
  retryDelay: Duration(milliseconds: 200),
  idleTimeout: Duration(seconds: 30),
);

/// A fake FLV origin: every registered path is one controllable byte stream.
/// Events added before the relay connects are buffered, closing the
/// controller ends the stream, and leaving it open with no events stalls the
/// relay's upstream - which is how the tests script gates and stalls.
final class _FakeUpstream {
  _FakeUpstream._(this._server);

  static Future<_FakeUpstream> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final upstream = _FakeUpstream._(server);
    server.listen(upstream._handle, onError: (Object _) {});
    return upstream;
  }

  final HttpServer _server;
  final Map<String, (StreamController<List<int>>, int)> _routes = <String, (StreamController<List<int>>, int)>{};

  /// Requested paths, in order.
  final List<String> paths = <String>[];

  /// Selected request headers per request, aligned with [paths].
  final List<Map<String, String>> headers = <Map<String, String>>[];

  Uri get base => Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _server.port);
  Uri url(String path) => base.replace(path: path);

  void serve(String path, StreamController<List<int>> stream, {int status = HttpStatus.ok}) =>
      _routes[path] = (stream, status);

  Future<void> _handle(HttpRequest request) async {
    paths.add(request.uri.path);
    headers.add(<String, String>{
      for (final name in const <String>['referer', 'authorization'])
        if (request.headers.value(name) != null) name: request.headers.value(name)!,
    });
    final route = _routes[request.uri.path];
    if (route == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final (stream, status) = route;
    if (status != HttpStatus.ok) {
      request.response.statusCode = status;
      await request.response.close();
      return;
    }
    // A live FLV origin streams: without this, dart:io buffers the body and
    // an open controller would never deliver a byte.
    request.response.bufferOutput = false;
    try {
      await request.response.addStream(stream.stream);
      await request.response.close();
    } on Object {
      // The relay dropped the connection: a splice switch, or close.
    }
  }

  Future<void> close() => _server.close(force: true);
}

/// One parsed FLV tag as the reader saw it.
final class _Parsed {
  const _Parsed(this.type, this.timestamp, this.payload);

  final int type;
  final int timestamp;
  final List<int> payload;
}

/// Reads the relayed stream and parses it back into tags, so the tests assert
/// on what a player would receive.
final class _RelayReader {
  _RelayReader._(this._client, Stream<List<int>> body) {
    _subscription = body.listen(
      _onData,
      onError: (Object error) {
        // The cleanup's own force close surfaces here when the test ends with
        // the stream still open; nobody is waiting for that.
        if (_closing) return;
        if (!_done.isCompleted) _done.completeError(error);
        _client.close(force: true);
      },
      onDone: () {
        _drain();
        if (!_done.isCompleted) _done.complete();
        _client.close(force: true);
      },
    );
  }

  final HttpClient _client;
  late final StreamSubscription<List<int>> _subscription;
  final Completer<void> _done = Completer<void>();
  final List<int> _buffer = <int>[];
  var _headerDone = false;
  var _closing = false;

  /// Parsed tags in arrival order; the file header is not included.
  final List<_Parsed> tags = <_Parsed>[];

  /// Completes when the relayed stream ends; errors when it breaks.
  Future<void> get done => _done.future;

  static Future<_RelayReader> open(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      expect(response.statusCode, HttpStatus.ok, reason: 'the relay must answer 200 on the secret path');
      expect(response.headers.contentType?.mimeType, ContentType('video', 'x-flv').mimeType);
      final reader = _RelayReader._(client, response);
      addTearDown(reader.close);
      return reader;
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }

  /// Stops reading: the test's own cleanup, or the relay ending the stream
  /// first.
  void close() {
    _closing = true;
    unawaited(_subscription.cancel());
    _client.close(force: true);
  }

  /// Waits until [count] tags arrived; fails the test when the stream ends or
  /// the [timeout] wins first.
  Future<void> waitFor(int count, {Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (tags.length < count) {
      if (_done.isCompleted) fail('the relayed stream ended after ${tags.length} tags, wanted $count');
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for tag $count (have ${tags.length})');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    _drain();
  }

  void _drain() {
    while (true) {
      if (!_headerDone) {
        if (_buffer.length < 13) return;
        _headerDone = true;
        _buffer.removeRange(0, 13);
        continue;
      }
      if (_buffer.length < 11) return;
      final size = (_buffer[1] << 16) | (_buffer[2] << 8) | _buffer[3];
      final total = 11 + size + 4;
      if (_buffer.length < total) return;
      final timestamp = (_buffer[7] << 24) | (_buffer[4] << 16) | (_buffer[5] << 8) | _buffer[6];
      tags.add(_Parsed(_buffer[0] & 0x1f, timestamp, List<int>.of(_buffer.getRange(11, 11 + size))));
      _buffer.removeRange(0, total);
    }
  }
}

/// Puts [tags] on the fake upstream's [sink]; the relay reads them as they
/// come.
void _feed(StreamController<List<int>> sink, Iterable<Uint8List> tags) => tags.forEach(sink.add);

Future<(int, List<int>)> _probe(Uri uri, {String method = 'GET'}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    final response = await request.close();
    final body = await response.fold<BytesBuilder>(BytesBuilder(), (builder, chunk) => builder..add(chunk));
    return (response.statusCode, body.takeBytes());
  } finally {
    client.close(force: true);
  }
}

Future<void> _until(bool Function() condition, String message) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting: $message');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

StreamController<List<int>> _stream() {
  final controller = StreamController<List<int>>();
  // Never awaited: a controller nobody connected to would hold the close
  // future (and the teardown) open forever.
  addTearDown(() => unawaited(controller.close()));
  return controller;
}

int _countPayload(_RelayReader reader, List<int> payload) =>
    reader.tags.where((tag) => _listEquals(tag.payload, payload)).length;

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  late _FakeUpstream upstream;

  setUp(() async => upstream = await _FakeUpstream.start());
  tearDown(() => upstream.close());

  test('a plain upstream is forwarded untouched and ends with it', () async {
    final stream = _stream();
    upstream.serve('/a.flv', stream);
    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      headers: const <String, String>{'Referer': 'https://example.test/'},
    );
    addTearDown(relay.close);

    _feed(stream, <Uint8List>[
      _fileHeader(),
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _audioConfigTag(0, _audioConfigA1),
      _videoTag(0, key: true),
      _audioTag(10),
      _videoTag(40),
      _videoTag(80),
    ]);
    // Ending the upstream is what ends the relayed stream; the close future
    // only completes once the relay has connected and drained, so it is not
    // awaited here.
    unawaited(stream.close());

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.done.timeout(const Duration(seconds: 10));

    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), const <(int, int)>[
      (_script, 0),
      (_video, 0),
      (_audio, 0),
      (_video, 0),
      (_audio, 10),
      (_video, 40),
      (_video, 80),
    ]);
    expect(upstream.headers.single['referer'], 'https://example.test/');
  });

  test('a stranger on the port is refused', () async {
    final stream = _stream();
    upstream.serve('/a.flv', stream);
    final relay = await FlvLoopbackRelay.start(upstream: upstream.url('/a.flv'));
    addTearDown(relay.close);

    final wrongPath = await _probe(relay.inputUri.replace(path: '/nope'));
    expect(wrongPath.$1, HttpStatus.notFound);

    final root = await _probe(relay.inputUri.replace(path: '/'));
    expect(root.$1, HttpStatus.notFound);

    final post = await _probe(relay.inputUri, method: 'POST');
    expect(post.$1, HttpStatus.notFound);
  });

  test('a failing upstream becomes a 502 before any byte', () async {
    final stream = _stream();
    upstream.serve('/a.flv', stream, status: HttpStatus.forbidden);
    final relay = await FlvLoopbackRelay.start(upstream: upstream.url('/a.flv'));
    addTearDown(relay.close);

    final (status, body) = await _probe(relay.inputUri);

    expect(status, HttpStatus.badGateway);
    expect(body, isEmpty);
  });

  test('a renewed address splices at the shared keyframe without repeating tags', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    final renewed = <Uri>[];
    final events = <FlvRelayEvent>[];

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      headers: const <String, String>{'Referer': 'https://a.test/'},
      refreshAt: DateTime.now(),
      renew: (current) {
        renewed.add(current.uri);
        return Future.value(
          FlvUpstreamAddress(
            uri: upstream.url('/b.flv'),
            headers: const <String, String>{'Referer': 'https://b.test/'},
          ),
        );
      },
      onEvent: events.add,
      timings: _patientHandover,
    );
    addTearDown(relay.close);

    // The old stream runs ahead of the new one by a GOP or two. It stops at
    // the gate so the renewed connection arms its splice point first; the
    // shared keyframe at 1000 ms is the cut.
    final aBeforeGate = <Uint8List>[
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _audioConfigTag(0, _audioConfigA1),
      _audioTag(0),
      _videoTag(0, key: true),
      _audioTag(10),
      _videoTag(40),
      _videoTag(80),
      _videoTag(120),
      _audioTag(130),
      _videoTag(160, key: true),
      _audioTag(170),
      _videoTag(200),
      _videoTag(240),
      _audioTag(250),
      _videoTag(280),
      _videoTag(320, key: true),
      _audioTag(330),
      _videoTag(360),
      _videoTag(400),
      _audioTag(410),
      _videoTag(440),
      _videoTag(480, key: true),
      _audioTag(490),
      _videoTag(520),
      _videoTag(560),
      _audioTag(570),
      _videoTag(600),
    ];
    final aAfterGate = <Uint8List>[
      _videoTag(640, key: true),
      _audioTag(650),
      _videoTag(680),
      _videoTag(720),
      _audioTag(730),
      _videoTag(760),
      _videoTag(800, key: true),
      _audioTag(810),
      _videoTag(840),
      _videoTag(880),
      _audioTag(890),
      _videoTag(920),
      _videoTag(1000, key: true),
      // Past the cut: must never surface.
      _videoTag(1040),
      _audioTag(1010),
    ];
    final bTags = <Uint8List>[
      _scriptTag(1000),
      _videoConfigTag(1000, _videoConfigV1),
      _audioConfigTag(1000, _audioConfigA1),
      _audioTag(1000),
      _videoTag(1000, key: true),
      _audioTag(1010),
      _videoTag(1040),
      _videoTag(1080),
      _audioTag(1090),
      _videoTag(1120),
      _audioTag(1130),
    ];

    _feed(a, <Uint8List>[_fileHeader(), ...aBeforeGate]);
    _feed(b, <Uint8List>[_fileHeader(), ...bTags]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(aBeforeGate.length);
    _feed(a, aAfterGate);
    await reader.waitFor(aBeforeGate.length + 12 + 8);

    final expected = <(int, int)>[
      ...aBeforeGate.map(_pair),
      ...aAfterGate.take(12).map(_pair),
      // The renewed connection: its pre-keyframe audio first, then its
      // keyframe on the same timeline (no shift); its script and its
      // unchanged codec configurations dropped.
      ...const <(int, int)>[
        (_audio, 1000),
        (_video, 1000),
        (_audio, 1010),
        (_video, 1040),
        (_video, 1080),
        (_audio, 1090),
        (_video, 1120),
        (_audio, 1130),
      ],
    ];
    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), expected);

    // Script once, configs only when the payload changes.
    expect(reader.tags.where((tag) => tag.type == _script), hasLength(1));
    expect(_countPayload(reader, _videoConfigV1), 1);
    expect(_countPayload(reader, _audioConfigA1), 1);

    expect(renewed, <Uri>[upstream.url('/a.flv')]);
    final switched = events.whereType<FlvRelaySwitched>().toList();
    expect(switched, hasLength(1));
    expect(switched.single.shifted, isFalse);
    expect(switched.single.switchAt, 1000);

    // The renewal's own headers go to the new upstream.
    final bHeaders = upstream.headers[upstream.paths.indexOf('/b.flv')];
    expect(bHeaders['referer'], 'https://b.test/');
  });

  test('a failed renewal keeps the old stream and retries', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    var calls = 0;
    final events = <FlvRelayEvent>[];

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      refreshAt: DateTime.now(),
      renew: (current) async {
        calls++;
        if (calls == 1) {
          throw Exception('renewal failed');
        }
        return FlvUpstreamAddress(uri: upstream.url('/b.flv'));
      },
      onEvent: events.add,
      timings: _patientHandover,
    );
    addTearDown(relay.close);

    final aTags = <Uint8List>[
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _videoTag(0, key: true),
      _videoTag(40),
      _videoTag(80),
      _videoTag(120),
      _videoTag(160),
      _videoTag(200, key: true),
      _videoTag(240),
    ];
    final bTags = <Uint8List>[
      _videoConfigTag(200, _videoConfigV1),
      _videoTag(200, key: true),
      _videoTag(240),
      _videoTag(280),
    ];

    _feed(a, <Uint8List>[_fileHeader(), ...aTags.take(5)]);
    _feed(b, <Uint8List>[_fileHeader(), ...bTags]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(5);

    // The old stream keeps flowing while the first attempt has already failed.
    _feed(a, aTags.skip(5).take(2));
    await reader.waitFor(7);
    expect(events.whereType<FlvRelayRenewalFailed>(), hasLength(1));

    // Give the retry time to arm its splice point (its upstream request is
    // the observable), then let the old stream reach the shared keyframe.
    await _until(() => upstream.paths.contains('/b.flv'), 'the retry to reach the new upstream');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _feed(a, aTags.skip(7));
    await reader.waitFor(10);

    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), <(int, int)>[
      // The old stream through 160 ms; its own keyframe at 200 ms is the cut
      // and is dropped with everything behind it.
      ...aTags.take(7).map(_pair),
      ...const <(int, int)>[(_video, 200), (_video, 240), (_video, 280)],
    ]);
    expect(calls, 2);
    final switched = events.whereType<FlvRelaySwitched>().toList();
    expect(switched, hasLength(1));
    expect(switched.single.switchAt, 200);
    expect(_countPayload(reader, _videoConfigV1), 1);
  });

  test('a connection on another timeline is shifted to continue the output', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    final events = <FlvRelayEvent>[];

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      // The renewal must see a delivered ledger to judge the alignment
      // against, so it comes due once the old stream's tags have flowed.
      refreshAt: DateTime.now().add(const Duration(milliseconds: 400)),
      renew: (current) => Future.value(FlvUpstreamAddress(uri: upstream.url('/b.flv'))),
      onEvent: events.add,
      timings: _timings,
    );
    addTearDown(relay.close);

    // The old connection stalls at 120 ms; the renewed one lives 100 s ahead,
    // beyond the alignment window, so it takes over at once and is shifted.
    _feed(a, <Uint8List>[
      _fileHeader(),
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _audioConfigTag(0, _audioConfigA1),
      _videoTag(0, key: true),
      _videoTag(40),
      _videoTag(80),
      _videoTag(120),
    ]);
    _feed(b, <Uint8List>[
      _fileHeader(),
      _scriptTag(100000),
      _videoConfigTag(100000, _videoConfigV2),
      _audioConfigTag(100000, _audioConfigA1),
      _audioTag(100000),
      _videoTag(100000, key: true),
      _audioTag(100010),
      _videoTag(100040),
      _videoTag(100080),
    ]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(13);

    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), const <(int, int)>[
      (_script, 0),
      (_video, 0),
      (_audio, 0),
      (_video, 0),
      (_video, 40),
      (_video, 80),
      (_video, 120),
      // The shift: 40 ms after the last delivered video, continuing it.
      (_video, 160),
      (_audio, 160),
      (_video, 160),
      (_audio, 170),
      (_video, 200),
      (_video, 240),
    ]);
    // The changed video configuration travels with the cut; the unchanged
    // audio configuration does not; the script is not repeated.
    expect(_countPayload(reader, _videoConfigV2), 1);
    expect(_countPayload(reader, _videoConfigV1), 1);
    expect(_countPayload(reader, _audioConfigA1), 1);
    expect(_countPayload(reader, _audioConfigA2), 0);
    expect(reader.tags.where((tag) => tag.type == _script), hasLength(1));

    final switched = events.whereType<FlvRelaySwitched>().toList();
    expect(switched, hasLength(1));
    expect(switched.single.shifted, isTrue);
    expect(switched.single.switchAt, 160);
  });

  test('an old stream that ends brings its successor in at once', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    var renewals = 0;

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      // The lease is far away; the early end is what triggers the renewal.
      refreshAt: DateTime.now().add(const Duration(hours: 1)),
      renew: (current) async {
        renewals++;
        return FlvUpstreamAddress(uri: upstream.url('/b.flv'));
      },
      timings: _timings,
    );
    addTearDown(relay.close);

    _feed(a, <Uint8List>[
      _fileHeader(),
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _videoTag(0, key: true),
      _videoTag(40),
      _videoTag(80),
    ]);
    // Same as above: the end is queued; the relay sees it once it connects.
    unawaited(a.close());
    _feed(b, <Uint8List>[
      _fileHeader(),
      _videoConfigTag(120, _videoConfigV1),
      _videoTag(120, key: true),
      _videoTag(160),
    ]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(7);

    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), const <(int, int)>[
      (_script, 0),
      (_video, 0),
      (_video, 0),
      (_video, 40),
      (_video, 80),
      (_video, 120),
      (_video, 160),
    ]);
    expect(renewals, 1);
  });

  test('a held keyframe waits for the new keyframe no longer than the handover', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    var calls = 0;
    final events = <FlvRelayEvent>[];

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      refreshAt: DateTime.now(),
      renew: (current) async {
        calls++;
        if (calls == 1) {
          // Connected but silent: the search hunts for a keyframe that never
          // comes until the keyframe search gives up.
          return FlvUpstreamAddress(uri: upstream.url('/b.flv'));
        }
        throw Exception('renewal failed');
      },
      onEvent: events.add,
      timings: const FlvRelayTimings(
        renewTimeout: Duration(seconds: 5),
        connectTimeout: Duration(seconds: 5),
        keyframeSearch: Duration(seconds: 1),
        handoverWait: Duration(milliseconds: 500),
        retryDelay: Duration(milliseconds: 300),
        idleTimeout: Duration(seconds: 30),
      ),
    );
    addTearDown(relay.close);

    _feed(a, <Uint8List>[
      _fileHeader(),
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _videoTag(0, key: true),
      _videoTag(40),
    ]);
    _feed(b, <Uint8List>[_fileHeader()]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(4);

    // Wait until the renewal is past the new connection's header (the search
    // is running), so the keyframe below is provably held.
    await _until(() => upstream.paths.contains('/b.flv'), 'the renewal to reach the new upstream');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The old stream's next keyframe is held while the renewal hunts for its
    // own; it must surface once the handover wait is up, not stay buried.
    final gateAt = DateTime.now();
    _feed(a, <Uint8List>[_videoTag(80, key: true), _videoTag(120), _videoTag(160)]);
    await reader.waitFor(7);
    expect(DateTime.now().difference(gateAt).inMilliseconds, greaterThanOrEqualTo(350));

    // The search failed, retries keep firing, and the old stream keeps
    // flowing through all of it.
    await _until(() => calls >= 2, 'the first retry to fire');
    a.add(_videoTag(200));
    await reader.waitFor(8);
    expect(calls, greaterThanOrEqualTo(2));
    expect(events.whereType<FlvRelayRenewalFailed>(), isNotEmpty);
    expect(events.whereType<FlvRelaySwitched>(), isEmpty);
  });

  test('a stalled old stream hands over after the wait', () async {
    final a = _stream();
    final b = _stream();
    upstream
      ..serve('/a.flv', a)
      ..serve('/b.flv', b);
    final events = <FlvRelayEvent>[];

    final relay = await FlvLoopbackRelay.start(
      upstream: upstream.url('/a.flv'),
      refreshAt: DateTime.now(),
      renew: (current) => Future.value(FlvUpstreamAddress(uri: upstream.url('/b.flv'))),
      onEvent: events.add,
      timings: _timings,
    );
    addTearDown(relay.close);

    // The old stream stalls at 120 ms, short of the new connection's keyframe
    // at 200 ms; the handover wait is what moves the output over.
    _feed(a, <Uint8List>[
      _fileHeader(),
      _scriptTag(0),
      _videoConfigTag(0, _videoConfigV1),
      _videoTag(0, key: true),
      _videoTag(40),
      _videoTag(80),
      _videoTag(120),
    ]);
    _feed(b, <Uint8List>[
      _fileHeader(),
      _videoConfigTag(200, _videoConfigV1),
      _audioTag(200),
      _videoTag(200, key: true),
      _videoTag(240),
      _videoTag(280),
    ]);

    final openedAt = DateTime.now();
    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(10);

    expect(DateTime.now().difference(openedAt).inMilliseconds, greaterThanOrEqualTo(400));
    expect(reader.tags.map((tag) => (tag.type, tag.timestamp)).toList(), const <(int, int)>[
      (_script, 0),
      (_video, 0),
      (_video, 0),
      (_video, 40),
      (_video, 80),
      (_video, 120),
      (_audio, 200),
      (_video, 200),
      (_video, 240),
      (_video, 280),
    ]);
    final switched = events.whereType<FlvRelaySwitched>().toList();
    expect(switched, hasLength(1));
    expect(switched.single.shifted, isFalse);
    expect(_countPayload(reader, _videoConfigV1), 1);
  });

  test('close ends the served stream and shuts the port', () async {
    final a = _stream();
    upstream.serve('/a.flv', a);
    final relay = await FlvLoopbackRelay.start(upstream: upstream.url('/a.flv'));

    _feed(a, <Uint8List>[_fileHeader(), _scriptTag(0), _videoTag(0, key: true)]);

    final reader = await _RelayReader.open(relay.inputUri);
    await reader.waitFor(2);

    await relay.close();
    await reader.done.timeout(const Duration(seconds: 10));
    expect(relay.isClosed, isTrue);

    await expectLater(_probe(relay.inputUri), throwsA(isA<SocketException>()));
  });
}
