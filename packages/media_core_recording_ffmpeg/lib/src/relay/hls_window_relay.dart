import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:media_core/media_core.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// Limits of the HLS retained window and its prefetch (3.x's
/// `HlsPrefetchScheduler`, `HlsPrefetchPool` and `HlsRetainedWindow`).
final class HlsWindowLimits {
  /// Creates the limits.
  const HlsWindowLimits({
    this.maxSegments = 48,
    this.maxBytes = 96 << 20,
    this.maxSegmentBytes = 32 << 20,
    this.concurrency = 4,
    this.idlePolls = 12,
  });

  /// Segments kept listed behind the upstream window (3.x kept 64).
  final int maxSegments;

  /// Bytes of downloaded, not yet delivered segments held in memory; above it
  /// new segments are left to the engine.
  final int maxBytes;

  /// A larger segment is not held (the engine fetches it itself).
  final int maxSegmentBytes;

  /// Parallel segment downloads.
  final int concurrency;

  /// Polls without the reader asking for the playlist or a segment after
  /// which prefetching stops (the reader went away).
  final int idlePolls;
}

/// A stretch of segments the upstream window dropped before the reader took
/// them: the recording has a hole there (3.x's `CaptureCoverageGap`).
///
/// `firstSequence` and `lastSequence` bound the run (inclusive), `count` is
/// the number of segments lost in it.
typedef HlsCoverageGap = ({int firstSequence, int lastSequence, int count});

/// Fetches one URL of the source: the recording's headers and proxy apply.
typedef HlsWindowFetch = Future<({int status, Uri url, Stream<List<int>> body})> Function(Uri url);

/// One segment of a media playlist as the window keeps it.
final class _HlsSegment {
  _HlsSegment({
    required this.sequence,
    required this.url,
    required this.tags,
    required this.key,
    required this.map,
    required this.discontinuity,
    required this.cacheable,
  });

  final int sequence;
  final Uri url;

  /// Its own tags in order (`#EXTINF`, `#EXT-X-DISCONTINUITY`,
  /// `#EXT-X-PROGRAM-DATE-TIME`, `#EXT-X-DATERANGE`, ...).
  final List<String> tags;

  /// The `#EXT-X-KEY` lines and the `#EXT-X-MAP` line in force for it, with
  /// absolute URIs.
  final List<String> key;
  final String? map;

  /// Its discontinuity sequence number.
  final int discontinuity;

  /// Whether its body may be held (not a byte range, not a gap).
  final bool cacheable;

  Future<Uint8List?>? body;
  int bytes = 0;
  bool failed = false;
}

/// A parsed media playlist.
final class _HlsSnapshot {
  _HlsSnapshot(this.segments, this.header, {required this.targetSeconds, required this.ended});

  final List<_HlsSegment> segments;

  /// `#EXT-X-VERSION`, `#EXT-X-INDEPENDENT-SEGMENTS`, `#EXT-X-PLAYLIST-TYPE`
  /// and `#EXT-X-START` lines kept as they were.
  final List<String> header;
  final int targetSeconds;
  final bool ended;
}

/// Keeps one live media playlist complete for a slow reader: the segments of
/// every playlist it saw stay listed (up to [HlsWindowLimits.maxSegments])
/// until the reader took them, and while the reader reads this playlist its
/// new segments are downloaded in parallel as soon as they appear, polled at
/// half the target duration independently of the reader.
///
/// FFmpeg reads an HLS input one segment at a time and reloads the playlist
/// only after the segments it has; a CDN that is slow per request (an
/// overseas platform behind a proxy) or a short live window (low-latency HLS,
/// 2 s segments) then lets segments leave the playlist before FFmpeg asks for
/// them ("skipping N segments ahead, expired from playlists"), and the CDN
/// deletes them soon after — the recording has a hole. The window prevents
/// that, and marks the hole when it cannot:
///
/// - the served playlist starts at the segment before the next one the
///   reader needs, so an expired segment the window still knows is listed;
/// - low-latency parts, preload hints and rendition reports are left out
///   (the engine reads whole segments), date ranges and program dates stay
///   with their segment, keys and maps are repeated where they change;
/// - bodies are held in memory up to [HlsWindowLimits.maxBytes]; above it, or
///   when a download fails, the reader fetches upstream itself as before;
/// - a sequence that goes back (a restarted stream) starts the window over;
/// - segments the upstream window expired before the reader took them are
///   reported through [onCoverageGap]: the served playlist jumps past the
///   hole rather than hiding it.
///
/// The parsing, scheduling and window keeping here are free of I/O: the only
/// way out is [fetch], and the reader decides what the returned playlist is
/// worth.
final class HlsRetainedWindow {
  /// Creates the window. [source] is the playlist's upstream address and
  /// [fetch] gets it and its segments; [onCoverageGap] is called when the
  /// upstream window drops segments the reader never took.
  HlsRetainedWindow({
    required this.source,
    required this.fetch,
    this.limits = const HlsWindowLimits(),
    this.onCoverageGap,
  });

  /// Limits.
  final HlsWindowLimits limits;

  /// The playlist's upstream address.
  final Uri source;

  /// Fetches one URL of the source.
  final HlsWindowFetch fetch;

  /// Called when the upstream window expires segments the reader never took.
  final void Function(HlsCoverageGap gap)? onCoverageGap;

  final _known = <int, _HlsSegment>{};
  final _byUrl = <String, _HlsSegment>{};
  final _inFlight = <StreamSubscription<List<int>>, Completer<void>>{};
  _HlsSnapshot? _last;
  int? _next;
  int _serves = 0;
  bool _active = false;
  int _idle = 0;
  int _downloads = 0;
  bool _closed = false;
  int _gapSegments = 0;
  Timer? _poll;

  /// Whether new segments are being downloaded.
  bool get prefetching => _active && !_closed;

  /// Segments listed now (tests, diagnostics).
  int get knownSegments => _known.length;

  /// Held segments now (tests, diagnostics).
  int get heldSegments => _known.values.where((segment) => segment.body != null).length;

  /// Bytes held now (tests, diagnostics).
  int get heldBytes => _known.values.fold(0, (sum, segment) => sum + segment.bytes);

  /// Segments the upstream window expired before the reader took them,
  /// summed over the window's life.
  int get coverageGapSegments => _gapSegments;

  /// Merges a playlist fetched for the reader and returns the playlist the
  /// reader gets: [text] when it is not a live media playlist this window can
  /// keep, else the retained window with absolute URLs.
  ///
  /// Prefetching starts once the reader reloads the playlist after taking a
  /// segment: the engine reads the first segments of every variant of a
  /// master but reloads only the ones it records.
  String serve(String text, Uri base) {
    if (_closed) return text;
    _serves++;
    _idle = 0;
    final snapshot = _merge(text, base);
    if (snapshot == null) return text;
    _activate();
    return _render(snapshot);
  }

  /// Whether [url] is a segment of this playlist.
  bool owns(Uri url) => _byUrl.containsKey('$url');

  /// The held body of the segment at [url] (waiting for its download), or
  /// null when the reader should fetch it upstream. Marks it delivered.
  Future<Uint8List?> take(Uri url) async {
    final segment = _byUrl['$url'];
    if (segment == null || _closed) return null;
    _delivered(segment.sequence);
    final body = segment.body;
    if (body == null) return null;
    final bytes = await body;
    return _closed ? null : bytes;
  }

  /// Stops the independent polling and new prefetches while what is held
  /// stays servable: the clean end lets the reader drain through the last
  /// window before the relay stops for good.
  void freeze() {
    _active = false;
    _poll?.cancel();
    _poll = null;
  }

  /// Stops polling and downloads and drops the held bodies.
  void close() {
    _closed = true;
    _poll?.cancel();
    for (final MapEntry(key: subscription, value: done) in _inFlight.entries.toList()) {
      unawaited(subscription.cancel());
      if (!done.isCompleted) done.completeError(StateError('closed'));
    }
    _inFlight.clear();
    _known.clear();
    _byUrl.clear();
  }

  void _delivered(int sequence) {
    _idle = 0;
    final next = _next;
    if (next == null || sequence + 1 > next) _next = sequence + 1;
    // The delivered one stays for a retry; older ones go.
    for (final old in _known.values.where((segment) => segment.sequence < sequence && segment.body != null).toList()) {
      old
        ..body = null
        ..bytes = 0;
    }
    _activate();
    _download();
  }

  void _activate() {
    if (_active || _closed || _next == null || _serves < 2) return;
    _active = true;
    _schedulePoll();
    _download();
  }

  _HlsSnapshot? _merge(String text, Uri base) {
    final snapshot = _parse(text, base);
    if (snapshot == null || snapshot.segments.isEmpty) return null;
    final first = snapshot.segments.first.sequence;
    final last = snapshot.segments.last.sequence;
    final next = _next;
    final known = _known.isEmpty ? null : _known.keys.reduce((a, b) => a > b ? a : b);
    if ((next != null && last < next - 2) || (known != null && last < known - limits.maxSegments)) {
      // The sequence went back: another stream.
      _reset();
    }
    for (final segment in snapshot.segments) {
      final existing = _known[segment.sequence];
      if (existing != null && (existing.url == segment.url || existing.body != null)) continue;
      if (existing != null) _byUrl.remove('${existing.url}');
      _known[segment.sequence] = segment;
      _byUrl['${segment.url}'] = segment;
    }
    // Forget what the reader passed and what exceeds the window; the current
    // upstream window always stays.
    final floor = math.min(
      first,
      [if (_next case final int next?) next - 1, last - limits.maxSegments + 1].reduce(math.max),
    );
    var gapFirst = -1;
    var gapLast = -1;
    for (final sequence in _known.keys.where((sequence) => sequence < floor).toList()..sort()) {
      final dropped = _known.remove(sequence)!;
      _byUrl.remove('${dropped.url}');
      if (_next != null && sequence < _next!) continue;
      // The reader never took it and the playlist no longer lists it: the
      // capture will have a hole there, and the served playlist jumps past it.
      if (gapFirst < 0) gapFirst = sequence;
      gapLast = sequence;
      _gapSegments++;
    }
    if (gapFirst >= 0) {
      onCoverageGap?.call((firstSequence: gapFirst, lastSequence: gapLast, count: gapLast - gapFirst + 1));
    }
    _last = snapshot;
    if (_active) _download();
    return snapshot;
  }

  String _render(_HlsSnapshot snapshot) {
    final last = snapshot.segments.last.sequence;
    // Back from the newest over the known segments: to the one before the
    // reader's next (an expired segment it still needs stays listed), or to
    // the upstream window before the reader started.
    final limit = _next == null ? snapshot.segments.first.sequence : _next! - 1;
    var start = last;
    while (start > limit && _known.containsKey(start - 1)) {
      start--;
    }
    final out = StringBuffer('#EXTM3U\n');
    final first = _known[start]!;
    snapshot.header.forEach(out.writeln);
    out
      ..writeln('#EXT-X-TARGETDURATION:${snapshot.targetSeconds}')
      ..writeln('#EXT-X-MEDIA-SEQUENCE:$start')
      ..writeln('#EXT-X-DISCONTINUITY-SEQUENCE:${first.discontinuity}');
    List<String>? key;
    String? map;
    for (var sequence = start; sequence <= last; sequence++) {
      final segment = _known[sequence]!;
      if (key == null || !_sameLines(key, segment.key)) {
        key = segment.key;
        // A key in force before the window starts is restated; a key that
        // ends is closed with METHOD=NONE.
        if (segment.key.isEmpty && sequence != start) {
          out.writeln('#EXT-X-KEY:METHOD=NONE');
        } else {
          segment.key.forEach(out.writeln);
        }
      }
      if (segment.map != map) {
        map = segment.map;
        if (map != null) out.writeln(map);
      }
      for (final tag in segment.tags) {
        if (sequence == start && tag == '#EXT-X-DISCONTINUITY') continue;
        out.writeln(tag);
      }
      out.writeln(segment.url);
    }
    if (snapshot.ended) out.writeln('#EXT-X-ENDLIST');
    return out.toString();
  }

  static bool _sameLines(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static final _uriAttribute = RegExp('URI="([^"]*)"');

  /// The absolute http(s) URL a playlist reference points at, or null when it
  /// does not resolve to one the relay may fetch.
  static Uri? _resolve(Uri base, String reference) {
    final Uri url;
    try {
      url = base.resolve(reference.trim());
    } on FormatException {
      return null;
    }
    if (!url.isScheme('http') && !url.isScheme('https')) return null;
    return url;
  }

  _HlsSnapshot? _parse(String text, Uri base) {
    // A master (or a delta playlist, which lists only what changed) is not a
    // media list this window can keep.
    if (text.contains('#EXT-X-STREAM-INF') || text.contains('#EXT-X-I-FRAMES-ONLY') || text.contains('#EXT-X-SKIP')) {
      return null;
    }
    var sequence = 0;
    var discontinuity = 0;
    var target = 0;
    var ended = false;
    final header = <String>[];
    final segments = <_HlsSegment>[];
    var tags = <String>[];
    var key = <String>[];
    var keyContinues = false;
    String? map;
    String absolute(String line) => line.replaceFirstMapped(_uriAttribute, (match) {
      final url = _resolve(base, match.group(1)!);
      return url == null ? match.group(0)! : 'URI="$url"';
    });
    int? number(String line) => int.tryParse(line.substring(line.indexOf(':') + 1).trim());
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line == '#EXTM3U') continue;
      final wasKey = keyContinues;
      keyContinues = false;
      if (!line.startsWith('#')) {
        final url = _resolve(base, line);
        if (url == null) return null;
        if (tags.contains('#EXT-X-DISCONTINUITY')) discontinuity++;
        segments.add(
          _HlsSegment(
            sequence: sequence++,
            url: url,
            tags: tags,
            key: key,
            map: map,
            discontinuity: discontinuity,
            cacheable: !tags.any((tag) => tag.startsWith('#EXT-X-BYTERANGE') || tag == '#EXT-X-GAP'),
          ),
        );
        tags = [];
        continue;
      }
      final name = line.contains(':') ? line.substring(0, line.indexOf(':')) : line;
      switch (name) {
        case '#EXT-X-MEDIA-SEQUENCE':
          sequence = number(line) ?? 0;
        case '#EXT-X-DISCONTINUITY-SEQUENCE':
          discontinuity = number(line) ?? 0;
        case '#EXT-X-TARGETDURATION':
          target = number(line) ?? 0;
        case '#EXT-X-ENDLIST':
          ended = true;
        case '#EXT-X-VERSION' || '#EXT-X-INDEPENDENT-SEGMENTS' || '#EXT-X-PLAYLIST-TYPE' || '#EXT-X-START':
          if (segments.isEmpty && tags.isEmpty) header.add(line);
        case '#EXT-X-KEY':
          // Consecutive keys (several KEYFORMATs) apply together.
          key = [if (wasKey) ...key, absolute(line)];
          keyContinues = true;
        case '#EXT-X-MAP':
          map = absolute(line);
        case '#EXT-X-PART' ||
            '#EXT-X-PART-INF' ||
            '#EXT-X-PRELOAD-HINT' ||
            '#EXT-X-RENDITION-REPORT' ||
            '#EXT-X-SERVER-CONTROL':
          // Low-latency parts: the engine takes whole segments.
          break;
        case '#EXTINF' ||
            '#EXT-X-DISCONTINUITY' ||
            '#EXT-X-PROGRAM-DATE-TIME' ||
            '#EXT-X-DATERANGE' ||
            '#EXT-X-BYTERANGE' ||
            '#EXT-X-GAP' ||
            '#EXT-X-BITRATE':
          tags.add(line);
        default:
          // Other tags travel with the next segment, unknown ones as they
          // were.
          if (name.startsWith('#EXT')) tags.add(line);
      }
    }
    if (target <= 0 || (ended && segments.isEmpty)) return null;
    return _HlsSnapshot(segments, header, targetSeconds: target, ended: ended);
  }

  void _download() {
    final next = _next;
    if (_closed || !_active || next == null) return;
    final held = heldBytes;
    for (final sequence in _known.keys.toList()..sort()) {
      if (_downloads >= limits.concurrency || held >= limits.maxBytes) return;
      final segment = _known[sequence]!;
      if (sequence < next || !segment.cacheable || segment.body != null || segment.failed) continue;
      _downloads++;
      segment.body = _get(segment).whenComplete(() {
        _downloads--;
        if (!_closed) _download();
      });
    }
  }

  Future<Uint8List?> _get(_HlsSegment segment) async {
    try {
      final answer = await fetch(segment.url);
      if (answer.status != 200) {
        unawaited(answer.body.drain<void>().catchError((Object _) {}));
        throw StateError('upstream ${answer.status}');
      }
      final builder = BytesBuilder(copy: false);
      final done = Completer<void>();
      late final StreamSubscription<List<int>> subscription;
      subscription = answer.body.listen(
        (chunk) {
          builder.add(chunk);
          if (builder.length > limits.maxSegmentBytes) {
            // Not held: the engine fetches it itself.
            unawaited(subscription.cancel());
            if (!done.isCompleted) done.completeError(StateError('segment too large'));
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      _inFlight[subscription] = done;
      try {
        await done.future;
      } finally {
        _inFlight.remove(subscription);
      }
      if (_closed) return null;
      final bytes = builder.takeBytes();
      segment.bytes = bytes.length;
      return bytes;
    } on Object {
      segment
        ..failed = true
        ..bytes = 0;
      return null;
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    final seconds = (_last?.targetSeconds ?? 2) / 2;
    final wait = Duration(milliseconds: (seconds.clamp(1, 6) * 1000).round());
    _poll = Timer(wait, () => unawaited(_pollNow()));
  }

  Future<void> _pollNow() async {
    if (_closed || !_active) return;
    // Counted per round and reset by every read: when the reader stops asking
    // for the playlist or a segment, there is nobody left to prefetch for.
    if (++_idle > limits.idlePolls) {
      _active = false;
      for (final segment in _known.values) {
        segment
          ..body = null
          ..bytes = 0;
      }
      return;
    }
    try {
      final answer = await fetch(source);
      final body = await _readText(answer.body, _maxPlaylistBytes);
      if (answer.status == 200 && !_closed) _merge(body, answer.url);
    } on Object {
      // The reader's own reload still works; poll again later.
    }
    if (!_closed && _active) _schedulePoll();
  }

  static const int _maxPlaylistBytes = 4 << 20;

  static Future<String> _readText(Stream<List<int>> body, int limit) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in body) {
      builder.add(chunk);
      if (builder.length > limit) throw const FormatException('playlist too large');
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  void _reset() {
    _known.clear();
    _byUrl.clear();
    _next = null;
    _active = false;
    _poll?.cancel();
  }
}

/// A loopback HLS window relay between FFmpeg and the live source.
///
/// FFmpeg reads the recording from `http://127.0.0.1:<port>/<secret>/index.m3u8`
/// while the relay fetches the real media playlist and re-serves it through an
/// [HlsRetainedWindow]: every segment the playlist listed — including ones the
/// upstream window has since expired — stays listed, and the segments the
/// window still needs are downloaded in parallel so a slow reader never has to
/// race the playlist's own expiry. Segment URLs in the served playlist point
/// back here; a segment the window holds is answered from memory, one it does
/// not hold is passed through upstream. Keys, maps and a master playlist keep
/// their upstream URIs: the engine fetches them itself with the recording's
/// headers, like an unrelayed capture would.
///
/// The reason is coverage, not latency: a segment the upstream window expires
/// before the engine asks for it is a hole in the recording, and the CDN
/// deletes it soon after. When the window cannot hold one (the byte budget
/// ran out, the segment is a byte range, the download failed) the gap is
/// reported through [coverageGaps] and logged rather than lost silently.
///
/// One relay serves one capture: every FFmpeg attempt (a re-open included)
/// gets a fresh relay for its own address, because the address and the
/// headers it was minted with change together. Only resources the served
/// playlists named are fetched for the engine — the relay is not an open
/// proxy.
final class RecordingHlsWindowRelay {
  RecordingHlsWindowRelay._({
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
  /// be started (the caller captures directly, and only loses the clean end).
  static Future<RecordingHlsWindowRelay?> start({
    required Uri upstream,
    required Map<String, String> headers,
    String? proxy,
  }) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final relay = RecordingHlsWindowRelay._(
        server: server,
        client: _clientOf(proxy),
        upstream: upstream,
        headers: headers,
        secret: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      );
      server.listen(
        relay._serve,
        onError: (Object error) {
          _log.debug('the recording relay stopped serving', error: error);
        },
      );
      return relay;
    } on Object catch (error) {
      try {
        await server?.close(force: true);
      } on Object {
        // A server that never bound has nothing to close.
      }
      _log.warning('the HLS window relay could not start; capturing directly', error: error);
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

  /// Name the playlist is served under, below the secret.
  static const String _playlistName = 'index.m3u8';

  /// Cap on the remembered segment names: a forward-only reader never comes
  /// back for the oldest ones, and an unbounded map would grow with the
  /// recording.
  static const int _maxNames = 2048;

  /// Largest playlist read.
  static const int _maxPlaylistBytes = 4 << 20;

  static final _extensionPattern = RegExp(r'\.[A-Za-z0-9]{1,6}$');

  final HttpServer _server;
  final HttpClient _client;
  final Uri _upstream;
  final Map<String, String> _headers;
  final String _secret;

  late final HlsRetainedWindow _window = HlsRetainedWindow(
    source: _upstream,
    fetch: _fetchUpstream,
    onCoverageGap: _reportGap,
  );

  /// Upstream URL behind each served segment name.
  final _segments = <String, Uri>{};
  final _names = <String, String>{};
  int _nextName = 0;
  int _serving = 0;
  bool _ending = false;
  bool _masterWarned = false;
  int _coverageGaps = 0;
  String? _lastServed;
  bool _lastEnded = false;
  String? _finalPlaylist;

  /// The address FFmpeg reads instead of the real one.
  Uri get localUrl => Uri.parse('http://127.0.0.1:${_server.port}/$_secret/$_playlistName');

  /// Whether a request is being served right now.
  bool get isActive => _serving > 0;

  /// Segments the upstream window expired before the capture took them: the
  /// recording has a hole wherever one of them was needed.
  int get coverageGaps => _coverageGaps;

  /// Held segments now (tests, diagnostics).
  int get heldSegments => _window.heldSegments;

  /// Bytes held now (tests, diagnostics).
  int get heldBytes => _window.heldBytes;

  Future<void> _serve(HttpRequest request) async {
    _serving++;
    try {
      if (request.method != 'GET' || !request.uri.path.startsWith('/$_secret/')) {
        await _status(request.response, HttpStatus.notFound);
        return;
      }
      final name = request.uri.path.substring(_secret.length + 2);
      if (name == _playlistName) {
        await _servePlaylist(request.response);
      } else {
        await _serveSegment(request, name);
      }
    } on Object catch (error) {
      _log.debug(
        'the recording relay failed to answer',
        error: error,
        fields: <String, Object?>{'upstream': _upstream.host},
      );
      try {
        await request.response.close();
      } on Object {
        // A client already gone has nothing to answer.
      }
    } finally {
      _serving--;
    }
  }

  Future<void> _servePlaylist(HttpResponse response) async {
    // The clean end froze the window: the last window served, closed with
    // ENDLIST when it was not, is what the reader drains through.
    if (_ending) {
      await _servePlaylistText(response, _finalPlaylist ?? '#EXTM3U\n#EXT-X-ENDLIST\n');
      return;
    }
    final ({int status, Uri url, Stream<List<int>> body}) answer;
    try {
      answer = await _fetchUpstream(_upstream);
      final text = await _readText(answer.body, _maxPlaylistBytes);
      if (answer.status != HttpStatus.ok) {
        await _status(response, answer.status >= 400 ? answer.status : HttpStatus.badGateway);
        return;
      }
      if (!text.trimLeft().startsWith('#EXTM3U')) {
        await _status(response, HttpStatus.badGateway);
        return;
      }
      // The recording address is a media playlist; a master answers as it
      // came and the capture reads it directly, like an unrelayed one would.
      if (text.contains('#EXT-X-STREAM-INF')) {
        if (!_masterWarned) {
          _masterWarned = true;
          _log.warning(
            'the recording address answered a master playlist; the retained window does not cover it',
            fields: <String, Object?>{'upstream': _upstream.host},
          );
        }
        _lastServed = text;
        _lastEnded = text.contains('#EXT-X-ENDLIST');
        await _servePlaylistText(response, text);
        return;
      }
      final served = _rewrite(_window.serve(text, answer.url));
      _lastServed = served;
      _lastEnded = served.contains('#EXT-X-ENDLIST');
      await _servePlaylistText(response, served);
    } on Object {
      await _status(response, HttpStatus.badGateway);
    }
  }

  Future<void> _serveSegment(HttpRequest request, String name) async {
    final response = request.response;
    final url = _segments[name];
    if (url == null) {
      // Only what the served playlists listed is served: the relay is not an
      // open proxy.
      await _status(response, HttpStatus.notFound);
      return;
    }
    // The window answers what it holds (waiting for its download); everything
    // else is passed through upstream, a byte range the engine asked for
    // included.
    Uint8List? held;
    try {
      held = await _window.take(url);
    } on Object {
      // The window closed mid-wait; pass through upstream.
    }
    if (held != null) {
      try {
        response
          ..statusCode = HttpStatus.ok
          ..contentLength = held.length
          ..add(held);
      } on Object {
        // The engine already hung up.
      }
      try {
        await response.close();
      } on Object {
        // The engine already hung up.
      }
      return;
    }
    HttpClientResponse answer;
    try {
      final upstreamRequest = await _client.openUrl('GET', url);
      _headers.forEach(upstreamRequest.headers.set);
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) upstreamRequest.headers.set(HttpHeaders.rangeHeader, range);
      answer = await upstreamRequest.close();
    } on Object {
      await _status(response, HttpStatus.badGateway);
      return;
    }
    if (answer.statusCode != HttpStatus.ok && answer.statusCode != HttpStatus.partialContent) {
      unawaited(answer.drain<void>().catchError((Object _) {}));
      await _status(response, answer.statusCode >= 400 ? answer.statusCode : HttpStatus.badGateway);
      return;
    }
    try {
      response
        ..statusCode = answer.statusCode
        ..bufferOutput = false;
      // A response the CDN ended (or the relay stopped) ends the engine's
      // read, the way an unrelayed capture ends.
      await answer.pipe(response);
    } on Object {
      // Upstream or the engine went away mid-body; the engine retries.
      try {
        response.statusCode = HttpStatus.badGateway;
      } on Object {
        // Headers already sent.
      }
      try {
        await response.close();
      } on Object {
        // Headers already sent.
      }
    }
  }

  /// [text] with its segment lines pointing back at this relay; tag lines are
  /// kept as the window rendered them (keys and maps carry absolute upstream
  /// URIs the engine fetches itself).
  String _rewrite(String text) {
    final out = StringBuffer();
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        out.writeln(raw);
        continue;
      }
      final url = Uri.tryParse(line);
      if (url == null || (!url.isScheme('http') && !url.isScheme('https'))) {
        out.writeln(raw);
        continue;
      }
      out.writeln(_localOf(_nameOf(url)));
    }
    return out.toString();
  }

  /// The local name for [url], the same for the same resource.
  String _nameOf(Uri url) {
    final key = '$url';
    final known = _names[key];
    if (known != null) return known;
    final extension = _extensionPattern.firstMatch(url.path)?.group(0) ?? '';
    final name = 's${_nextName++}$extension';
    _names[key] = name;
    _segments[name] = url;
    while (_segments.length > _maxNames) {
      final oldest = _segments.keys.first;
      final dropped = _segments.remove(oldest)!;
      _names.remove('$dropped');
    }
    return name;
  }

  Uri _localOf(String name) => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: '/$_secret/$name');

  Future<({int status, Uri url, Stream<List<int>> body})> _fetchUpstream(Uri url) async {
    final request = await _client.openUrl('GET', url);
    _headers.forEach(request.headers.set);
    final answer = await request.close();
    var at = url;
    for (final redirect in answer.redirects) {
      at = at.resolveUri(redirect.location);
    }
    return (status: answer.statusCode, url: at, body: answer);
  }

  void _reportGap(HlsCoverageGap gap) {
    _coverageGaps += gap.count;
    _log.warning(
      'the upstream window expired segment(s) the capture had not taken; the recording has a gap there',
      fields: <String, Object?>{
        'upstream': _upstream.host,
        'first': gap.firstSequence,
        'last': gap.lastSequence,
        'count': gap.count,
      },
    );
  }

  Future<void> _servePlaylistText(HttpResponse response, String text) async {
    final body = utf8.encode(text);
    try {
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('application', 'vnd.apple.mpegurl')
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
        ..contentLength = body.length
        ..add(body);
    } on Object {
      // The engine already hung up.
    }
    try {
      await response.close();
    } on Object {
      // The engine already hung up.
    }
  }

  static Future<String> _readText(Stream<List<int>> body, int limit) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in body) {
      builder.add(chunk);
      if (builder.length > limit) throw const FormatException('playlist too large');
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  static Future<void> _status(HttpResponse response, int status) async {
    try {
      response.statusCode = status;
      await response.close();
    } on Object {
      // The peer went away.
    }
  }

  /// Ends the input the way an HLS source ends: the next playlist reload is
  /// answered with the last window served, closed with `#EXT-X-ENDLIST` when
  /// it was not, so the engine reads what is listed, muxes complete segments
  /// and exits on its own. Polling and prefetching stop; what is held stays
  /// servable for that drain.
  Future<void> closeInput() async {
    if (_ending) return;
    _ending = true;
    _window.freeze();
    final last = _lastServed;
    if (last == null || last.contains('#EXT-X-STREAM-INF') || _lastEnded) {
      _finalPlaylist = last ?? '#EXTM3U\n#EXT-X-ENDLIST\n';
    } else {
      _finalPlaylist = '$last#EXT-X-ENDLIST\n';
    }
  }

  /// Stops the relay for good.
  Future<void> stop() async {
    _ending = true;
    _window.close();
    _client.close(force: true);
    try {
      await _server.close(force: true);
    } on Object {
      // A server that already died has nothing to close.
    }
  }
}
