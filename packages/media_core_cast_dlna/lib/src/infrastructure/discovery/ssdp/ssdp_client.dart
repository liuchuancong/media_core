import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_constants.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_message.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_search.dart';

/// A raw SSDP datagram: decoded text plus the address it came from.
final class SsdpDatagram {
  /// Creates a datagram.
  const SsdpDatagram({required this.text, required this.from});

  /// UTF-8 decoded payload.
  final String text;

  /// The sending socket address, kept because debugging a device that
  /// answers from the wrong interface is otherwise impossible.
  final InternetAddress from;
}

/// The message feed a discovery consumer reads: parsed SSDP datagrams
/// with alive, byebye and expiry semantics folded in.
///
/// The seam exists so the discovery pipeline is testable without a
/// network — a test scripts this interface, production binds the real
/// socket in [SsdpClient].
abstract interface class SsdpSource {
  /// Parsed SSDP messages, alive, byebye and expiry alike.
  Stream<SsdpMessage> get messages;

  /// Begins listening and searching. Idempotent.
  Future<void> start();

  /// Sends one search cycle now, without touching the listener.
  Future<void> search();

  /// Stops and releases everything.
  Future<void> stop();
}

/// Creates the socket an [SsdpClient] runs on.
///
/// Injected so tests can drive discovery from a scripted stream
/// instead of joining a multicast group a CI machine does not have.
typedef SsdpSocketFactory = Future<RawDatagramSocket> Function();

/// SSDP client: send M-SEARCH across the configured targets, listen
/// for alive/byebye/search responses, expire announcements on their own
/// cache lifetime.
///
/// UPnP's freshness rule is that an announcement lives for the
/// `CACHE-CONTROL: max-age` it carried, renewed by the next NOTIFY or
/// search response; a device that simply stops answering is gone even
/// though nothing ever said BYEBYE (the Wi-Fi did not notify you).
/// Expiry is therefore tracked per device and enforced here, so a
/// consumer cannot keep offering a TV that has been asleep for ten
/// minutes.
final class SsdpClient implements SsdpSource {
  /// Creates a client.
  ///
  /// [searchTargets] lists the STs each search cycle walks through;
  /// devices answer selectively per target, so one ST alone misses
  /// half the living room. [searchInterval] schedules the periodic
  /// re-search that refreshes every cache clock.
  SsdpClient({
    SsdpSocketFactory? socketFactory,
    this.searchTargets = SsdpConstants.defaultSearchTargets,
    this.searchInterval = const Duration(seconds: 12),
    this.mx = SsdpConstants.defaultMx,
    this.interTargetDelay = const Duration(milliseconds: 150),
  }) : _socketFactory = socketFactory ?? _defaultSocket;

  static Future<RawDatagramSocket> _defaultSocket() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    try {
      socket.joinMulticast(InternetAddress(SsdpConstants.multicastAddress));
    } on SocketException {
      // A host without a multicast-capable interface (some CI
      // containers, VPN-only machines) still gets search responses
      // unicast back to it; joining failed, the socket still works.
    }
    return socket;
  }

  final SsdpSocketFactory _socketFactory;

  /// The search targets one cycle walks through.
  final List<String> searchTargets;

  /// How often to re-send M-SEARCH.
  final Duration searchInterval;

  /// The MX value carried by every M-SEARCH.
  final int mx;

  /// The pause between two search targets of one cycle; staggering
  /// keeps the response burst for each ST apart.
  final Duration interTargetDelay;

  RawDatagramSocket? _socket;
  Timer? _searchTimer;
  final Map<String, Timer> _expiry = <String, Timer>{};
  final StreamController<SsdpDatagram> _incoming = StreamController<SsdpDatagram>.broadcast();
  final StreamController<SsdpMessage> _messages = StreamController<SsdpMessage>.broadcast();

  bool _started = false;
  bool _closed = false;

  /// The bound local port, when started; exposed for tests and for
  /// diagnosing a socket that ended up on the wrong interface.
  int? get port => _socket?.port;

  /// Every datagram received, before parsing. Diagnostic surface.
  Stream<SsdpDatagram> get rawDatagrams => _incoming.stream;

  /// Parsed SSDP messages.
  @override
  Stream<SsdpMessage> get messages => _messages.stream;

  /// Starts listening, sends the first search cycle and repeats it.
  @override
  Future<void> start() async {
    if (_closed || _started) {
      return;
    }
    _started = true;

    final socket = await _socketFactory();
    _socket = socket;

    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket.receive();
        if (datagram == null) {
          return;
        }
        final text = utf8.decode(datagram.data, allowMalformed: true);
        _incoming.add(SsdpDatagram(text: text, from: datagram.address));
        final message = SsdpMessage.tryParse(text);
        if (message != null) {
          _track(message);
          _messages.add(message);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _incoming.addError(error, stackTrace);
      },
    );

    await search();
    _searchTimer = Timer.periodic(searchInterval, (_) => unawaited(search()));
  }

  /// Sends one search cycle: one M-SEARCH per configured target, the
  /// cycle staggered by [interTargetDelay] so each ST's answer burst
  /// has the wire to itself.
  @override
  Future<void> search() async {
    final socket = _socket;
    if (socket == null || _closed) {
      return;
    }
    final address = InternetAddress(SsdpConstants.multicastAddress);
    for (var i = 0; i < searchTargets.length; i++) {
      if (i > 0 && interTargetDelay > Duration.zero) {
        await Future<void>.delayed(interTargetDelay);
      }
      if (_closed) {
        return;
      }
      socket.send(Uint8List.fromList(SsdpSearch.build(searchTargets[i], mx: mx)), address, SsdpConstants.port);
    }
  }

  void _track(SsdpMessage message) {
    final id = message.deviceId;
    if (id == null) {
      return;
    }
    if (message.isByebye) {
      _expiry.remove(id)?.cancel();
      return;
    }
    final lifetime = message.cacheLifetime;
    _expiry.remove(id)?.cancel();
    _expiry[id] = Timer(lifetime, () {
      // The announcement aged out with no renewal: report it as gone
      // on the message stream so consumers do not need a second timer
      // of their own.
      _messages.add(SsdpMessage(method: 'EXPIRED', headers: <String, String>{'usn': id}));
    });
  }

  /// Stops listening and releases the socket.
  @override
  Future<void> stop() async {
    _searchTimer?.cancel();
    _searchTimer = null;
    for (final timer in _expiry.values) {
      timer.cancel();
    }
    _expiry.clear();
    _socket?.close();
    _socket = null;
    _started = false;
    _closed = true;
    await _incoming.close();
    await _messages.close();
  }
}
