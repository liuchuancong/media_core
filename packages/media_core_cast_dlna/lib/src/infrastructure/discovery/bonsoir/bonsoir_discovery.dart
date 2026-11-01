import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

/// The mDNS service types the auxiliary channel browses by default.
///
/// DLNA itself has no standardized mDNS advertisement — SSDP is the
/// protocol's discovery mechanism. Some TV stacks do announce a media
/// renderer over DNS-SD, and the hint channel exists to surface those;
/// an mDNS hit never qualifies a device as castable by itself.
abstract final class MDnsDiscoveryConstants {
  /// The service types browsed by default.
  static const List<String> defaultServiceTypes = <String>['_mediarenderer._tcp'];
}

/// A service seen on the mDNS channel.
///
/// A hint, not a device: it carries no description LOCATION and no
/// AVTransport endpoint, so it cannot be cast to directly. Consumers
/// use it to spot candidates the SSDP channel may have missed, or to
/// match against discovered DLNA devices by name or address.
final class MDnsServiceHint {
  /// Creates a hint.
  const MDnsServiceHint({required this.name, required this.type, required this.port, this.hostAddress});

  /// The instance name as advertised.
  final String name;

  /// The DNS-SD service type (`_mediarenderer._tcp`, ...).
  final String type;

  /// The resolved host address, when the service was resolved.
  final String? hostAddress;

  /// The service port; `0` when the service has not been resolved yet.
  final int port;

  @override
  String toString() => 'MDnsServiceHint($name, $type, $hostAddress:$port)';
}

/// One running mDNS browse for a single service type.
///
/// The seam that keeps platform channels out of the tests: production
/// wraps a Bonsoir discovery, tests script the event stream.
abstract interface class MDnsDiscoverySession {
  /// The raw discovery events, when the platform exposes them.
  Stream<BonsoirDiscoveryEvent>? get events;

  /// Prepares the platform. Complete before [start].
  Future<void> initialize();

  /// Begins browsing.
  Future<void> start();

  /// Stops browsing and discards the platform resources.
  Future<void> stop();
}

/// [MDnsDiscoverySession] over a real Bonsoir discovery.
final class BonsoirMdnsSession implements MDnsDiscoverySession {
  /// Creates a session for [type].
  BonsoirMdnsSession(String type) : _discovery = BonsoirDiscovery(type: type, printLogs: false);

  final BonsoirDiscovery _discovery;

  @override
  Stream<BonsoirDiscoveryEvent>? get events => _discovery.eventStream;

  @override
  Future<void> initialize() => _discovery.initialize();

  @override
  Future<void> start() => _discovery.start();

  @override
  Future<void> stop() => _discovery.stop();
}

/// The auxiliary mDNS discovery channel, powered by Bonsoir.
///
/// SSDP is the primary DLNA discovery mechanism and this channel never
/// replaces it: a device announcing over mDNS carries no description
/// LOCATION, so nothing here can produce a castable device. What it
/// does do is surface DNS-SD advertisements (some TV stacks announce a
/// media renderer this way) so a host can correlate them with the
/// SSDP list or trigger a discovery refresh.
///
/// Each configured service type runs its own session; one type failing
/// to initialize (an implementation without a resolver, a platform
/// without mDNS) does not stop the others.
final class BonsoirDiscoveryChannel {
  /// Creates a channel.
  ///
  /// [sessionFactory] is injectable for tests; production builds a
  /// [BonsoirMdnsSession] per service type.
  BonsoirDiscoveryChannel({
    this.serviceTypes = MDnsDiscoveryConstants.defaultServiceTypes,
    MDnsDiscoverySession Function(String type)? sessionFactory,
  }) : _sessionFactory = sessionFactory ?? BonsoirMdnsSession.new;

  /// The DNS-SD service types this channel browses.
  final List<String> serviceTypes;

  final MDnsDiscoverySession Function(String type) _sessionFactory;

  final Map<String, MDnsDiscoverySession> _sessions = <String, MDnsDiscoverySession>{};
  final Map<String, StreamSubscription<BonsoirDiscoveryEvent>> _subscriptions =
      <String, StreamSubscription<BonsoirDiscoveryEvent>>{};
  final StreamController<MDnsServiceHint> _found = StreamController<MDnsServiceHint>.broadcast();
  final StreamController<String> _lost = StreamController<String>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  bool _started = false;
  bool _closed = false;

  /// A service appeared or was re-announced on the mDNS channel.
  Stream<MDnsServiceHint> get serviceFound => _found.stream;

  /// A service left the mDNS channel; the value is its instance name.
  Stream<String> get serviceLost => _lost.stream;

  /// Session failures (a type that cannot initialize or browse).
  Stream<Object> get errors => _errors.stream;

  /// Whether the channel is browsing.
  bool get isRunning => _started;

  /// Starts every session. Idempotent.
  Future<void> start() async {
    if (_started || _closed) {
      return;
    }
    _started = true;
    for (final type in serviceTypes) {
      final session = _sessionFactory(type);
      _sessions[type] = session;
      try {
        await session.initialize();
        final events = session.events;
        if (events != null) {
          _subscriptions[type] = events.listen(_onEvent, onError: _errors.add);
        }
        await session.start();
      } on Object catch (error) {
        // One broken type must not take the channel down; the failure
        // surfaces on [errors] where a host can log it.
        _errors.add(error);
      }
    }
  }

  /// Stops browsing. A fresh [start] re-initializes every session:
  /// Bonsoir discards an action once stopped.
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    _started = false;
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final session in _sessions.values) {
      try {
        await session.stop();
      } on Object catch (error) {
        _errors.add(error);
      }
    }
    _sessions.clear();
  }

  /// Stops and closes every stream this channel owns.
  Future<void> dispose() async {
    _closed = true;
    await stop();
    await _found.close();
    await _lost.close();
    await _errors.close();
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    final service = event.service;
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
      case BonsoirDiscoveryServiceResolvedEvent():
      case BonsoirDiscoveryServiceUpdatedEvent():
        if (service != null) {
          _found.add(
            MDnsServiceHint(
              name: service.name,
              type: service.type,
              hostAddress: service.hostAddress,
              port: service.port,
            ),
          );
        }
      case BonsoirDiscoveryServiceLostEvent():
        if (service != null) {
          _lost.add(service.name);
        }
      case BonsoirDiscoveryServiceResolveFailedEvent():
      case BonsoirDiscoveryStartedEvent():
      case BonsoirDiscoveryStoppedEvent():
      case BonsoirDiscoveryUnknownEvent():
        break;
    }
  }
}
