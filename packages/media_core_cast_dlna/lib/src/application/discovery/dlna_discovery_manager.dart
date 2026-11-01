import 'dart:async';

import 'package:media_core_cast_dlna/src/application/device/dlna_device_registry.dart';
import 'package:media_core_cast_dlna/src/application/discovery/dlna_discovery_options.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_discovery_state.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/device_description_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_message.dart';
import 'package:media_core_cast_dlna/src/logging/dlna_log.dart';

/// A device whose description could not be fetched or parsed.
///
/// Surfaced on [DlnaDiscoveryManager.errors] instead of thrown: one
/// broken TV must not break a discovery loop that is also carrying
/// three healthy ones.
final class DlnaDiscoveryError {
  /// Creates an error record.
  const DlnaDiscoveryError({required this.usn, required this.error, this.location});

  /// The announcement identity the failure belongs to.
  final String usn;

  /// The description location, when the announcement carried one.
  final String? location;

  /// What went wrong.
  final Object error;
}

/// Owns the discovery pipeline: SSDP announcements in, resolved
/// [DlnaDevice]s out.
///
/// The manager is where the discovery rules live, so no consumer has
/// to re-derive them: one description fetch per device (renewals never
/// re-fetch), a bounded number of fetches in flight, a failing device
/// backed off instead of hammered every cache cycle, and identities
/// tracked by UDN with a USN bridge for the devices whose two ids
/// disagree.
final class DlnaDiscoveryManager {
  /// Creates a manager.
  ///
  /// Every collaborator is injectable: a scripted [SsdpSource], a
  /// [fetchDescription] returning canned XML and an injected [now] make
  /// the whole pipeline deterministic without a network.
  DlnaDiscoveryManager({
    SsdpSource? ssdp,
    DescriptionFetcher? fetchDescription,
    this.options = const DlnaDiscoveryOptions(),
    DateTime Function()? now,
  }) : _ssdp = ssdp ?? SsdpClient(),
       _fetchDescription = fetchDescription ?? HttpDescriptionFetcher().call,
       _ownedFetcher = fetchDescription == null ? HttpDescriptionFetcher() : null,
       _now = now ?? DateTime.now;

  final SsdpSource _ssdp;
  final DescriptionFetcher _fetchDescription;
  final HttpDescriptionFetcher? _ownedFetcher;

  /// The tunables this run obeys.
  final DlnaDiscoveryOptions options;

  final DateTime Function() _now;
  final DlnaDeviceRegistry _registry = DlnaDeviceRegistry();

  /// SSDP usn -> description UDN, for the devices whose two ids
  /// disagree.
  ///
  /// The spec says the USN's root equals the UDN, and most devices
  /// obey; devices that pad one side (a trailing service suffix, a
  /// re-formatted uuid) otherwise break exactly one thing — a BYEBYE
  /// arriving with an id the removal does not recognise, leaving a
  /// dead TV in the picker until its cache ages out.
  final Map<String, String> _usnToUdn = <String, String>{};

  /// SSDP usn -> when its description fetch last failed.
  final Map<String, DateTime> _failedDescriptions = <String, DateTime>{};

  final Set<String> _fetching = <String>{};
  final _Gate _gate = _Gate(0);

  StreamSubscription<SsdpMessage>? _subscription;
  final StreamController<List<DlnaDevice>> _devicesChanged = StreamController<List<DlnaDevice>>.broadcast();
  final StreamController<DlnaDevice> _added = StreamController<DlnaDevice>.broadcast();
  final StreamController<DlnaDevice> _updated = StreamController<DlnaDevice>.broadcast();
  final StreamController<String> _removed = StreamController<String>.broadcast();
  final StreamController<DlnaDiscoveryError> _errors = StreamController<DlnaDiscoveryError>.broadcast();

  DlnaDiscoveryState _state = DlnaDiscoveryState.idle;

  /// Where this run is in its lifecycle.
  DlnaDiscoveryState get state => _state;

  /// The devices currently considered present, in discovery order.
  List<DlnaDevice> get devices => _registry.devices;

  /// The device with this UDN, when currently present.
  DlnaDevice? device(String udn) => _registry.byUdn(udn);

  /// Fires after every list mutation with the full snapshot.
  Stream<List<DlnaDevice>> get devicesStream => _devicesChanged.stream;

  /// A resolved device appeared for the first time.
  Stream<DlnaDevice> get deviceAdded => _added.stream;

  /// A known device's description was re-resolved (its announcement
  /// moved or said `ssdp:update`).
  Stream<DlnaDevice> get deviceUpdated => _updated.stream;

  /// A device's UDN left the set (BYEBYE, expiry, or description
  /// relocation pending re-resolution).
  Stream<String> get deviceRemoved => _removed.stream;

  /// Devices whose description failed to resolve.
  Stream<DlnaDiscoveryError> get errors => _errors.stream;

  /// Whether the run is started and not yet stopping.
  bool get isRunning => _state == DlnaDiscoveryState.starting || _state == DlnaDiscoveryState.active;

  /// Starts discovery. Idempotent: a second call while running does
  /// not rebind the socket or duplicate the subscription.
  Future<void> start() async {
    if (_state != DlnaDiscoveryState.idle && _state != DlnaDiscoveryState.stopped) {
      return;
    }
    _state = DlnaDiscoveryState.starting;
    _gate.limit = options.maxConcurrentDescriptions;
    try {
      _subscription = _ssdp.messages.listen(_onMessage);
      await _ssdp.start();
      DlnaLog.info(DlnaLogCategory.discovery, 'discovery started');
    } on Object catch (error) {
      _state = DlnaDiscoveryState.error;
      await _subscription?.cancel();
      _subscription = null;
      throw DlnaDiscoveryException('SSDP discovery could not start', cause: error);
    }
    _state = DlnaDiscoveryState.active;
  }

  /// Re-sends the search cycle without touching the listener.
  Future<void> refresh() async {
    if (!isRunning) {
      return;
    }
    await _ssdp.search();
  }

  /// Stops discovery and drops every cached device.
  Future<void> stop() async {
    if (_state == DlnaDiscoveryState.stopped || _state == DlnaDiscoveryState.idle) {
      return;
    }
    _state = DlnaDiscoveryState.stopping;
    await _subscription?.cancel();
    _subscription = null;
    await _ssdp.stop();
    _registry.clear();
    _usnToUdn.clear();
    _failedDescriptions.clear();
    _fetching.clear();
    _state = DlnaDiscoveryState.stopped;
    DlnaLog.info(DlnaLogCategory.discovery, 'discovery stopped');
    _emitDevices();
  }

  /// Stops and closes every stream this manager owns.
  Future<void> dispose() async {
    await stop();
    _ownedFetcher?.close();
    await _devicesChanged.close();
    await _added.close();
    await _updated.close();
    await _removed.close();
    await _errors.close();
  }

  void _onMessage(SsdpMessage message) {
    if (!isRunning) {
      return;
    }

    if (message.isByebye || message.method == 'EXPIRED') {
      _remove(message.deviceId);
      return;
    }

    final location = message.location;
    if (location == null || (!message.isAlive && !message.isSearchResponse && !message.isUpdate)) {
      return;
    }

    final usn = message.deviceId;
    if (usn == null) {
      return;
    }

    final canonical = _usnToUdn[usn] ?? usn;
    final known = _registry.byUdn(canonical);

    if (known != null) {
      if (message.isUpdate || known.location.toString() != location) {
        // The device says its description moved: drop the record and
        // resolve the new location, emitting updated (not added) once
        // the fresh description is in.
        _registry.remove(canonical);
        _emitDevices();
      } else {
        // A renewal of a known device. Re-fetching every cache cycle
        // would hammer the LAN, and a device that actually changed its
        // description re-announces with a byebye first.
        _registry.addOrUpdate(known.renewed(at: _now(), maxAge: message.cacheLifetime));
        return;
      }
    }

    final failedAt = _failedDescriptions[usn];
    if (failedAt != null) {
      if (_now().difference(failedAt) < options.descriptionFailureBackoff) {
        return;
      }
      _failedDescriptions.remove(usn);
    }

    unawaited(_resolve(usn, location, message.cacheLifetime));
  }

  Future<void> _resolve(String usn, String location, Duration maxAge) async {
    if (!_fetching.add(usn)) {
      return;
    }
    try {
      await _gate.acquire();
      // The fetch spans real network time; the run may have been
      // stopped (or the manager disposed) while it was in flight. The
      // post-await guards keep a stale result from resurrecting a
      // device or writing into closed controllers.
      if (!isRunning) {
        return;
      }
      try {
        final xml = await _fetchDescription(location);
        if (!isRunning) {
          return;
        }
        final device = DeviceDescriptionParser.parse(
          xml,
          location: Uri.parse(location),
          maxAge: maxAge,
          seenAt: _now(),
        );

        if (options.requireAvTransport && device.avTransport == null) {
          // A device that cannot accept a cast is not a renderer; this
          // is a normal, silent skip — media servers announce on the
          // same multicast group and are not a fault. The cooldown
          // keeps the renewal cycle from re-fetching it every 30s
          // forever.
          _failedDescriptions[usn] = _now();
          return;
        }

        final wasKnown = _usnToUdn.containsKey(usn);
        _registry.addOrUpdate(device);
        _usnToUdn[usn] = device.udn;
        _failedDescriptions.remove(usn);
        DlnaLog.info(
          DlnaLogCategory.discovery,
          wasKnown ? 'device re-resolved' : 'device found',
          fields: <String, Object?>{'device': device.udn, 'name': device.friendlyName},
        );
        if (wasKnown) {
          _updated.add(device);
        } else {
          _added.add(device);
        }
        _emitDevices();
      } finally {
        _gate.release();
      }
    } on Object catch (error) {
      if (!isRunning) {
        return;
      }
      _failedDescriptions[usn] = _now();
      DlnaLog.warning(
        DlnaLogCategory.discovery,
        'device description failed',
        error: error,
        fields: <String, Object?>{'usn': usn, 'location': location},
      );
      _errors.add(DlnaDiscoveryError(usn: usn, location: location, error: error));
    } finally {
      _fetching.remove(usn);
    }
  }

  void _remove(String? id) {
    if (id == null) {
      return;
    }
    final canonical = _usnToUdn[id] ?? id;
    // One device can be known under several USNs (it answers several
    // STs); a departure ends all of them.
    _usnToUdn.removeWhere((usn, udn) => usn == id || udn == canonical);
    final gone = _registry.remove(canonical);
    if (gone != null) {
      DlnaLog.info(DlnaLogCategory.discovery, 'device lost', fields: <String, Object?>{'device': canonical});
      _removed.add(canonical);
      _emitDevices();
    }
  }

  void _emitDevices() {
    _devicesChanged.add(_registry.devices);
  }
}

/// Bounds how many description fetches run concurrently; waiters queue
/// in arrival order and a release hands the slot straight to the next
/// waiter.
final class _Gate {
  _Gate(this.limit);

  int limit;
  int _active = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_active < limit) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_active > 0) {
      _active--;
    }
  }
}
