import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

/// A scripted mDNS session: tests push real Bonsoir events into
/// [controller], no platform channel involved.
final class ScriptedSession implements MDnsDiscoverySession {
  final controller = StreamController<BonsoirDiscoveryEvent>.broadcast();
  int initialized = 0;
  int started = 0;
  int stopped = 0;

  @override
  Stream<BonsoirDiscoveryEvent>? get events => controller.stream;

  @override
  Future<void> initialize() async {
    initialized++;
  }

  @override
  Future<void> start() async {
    started++;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }
}

BonsoirService service(String name, {String host = '192.168.1.50', int port = 8000}) {
  return BonsoirService(name: name, type: '_mediarenderer._tcp', hostAddresses: <String>[host], port: port);
}

void main() {
  test('found, resolved and lost events map onto hints', () async {
    final session = ScriptedSession();
    final channel = BonsoirDiscoveryChannel(sessionFactory: (_) => session);
    final found = <MDnsServiceHint>[];
    final lost = <String>[];
    channel.serviceFound.listen(found.add);
    channel.serviceLost.listen(lost.add);

    await channel.start();
    expect(session.initialized, 1);
    expect(session.started, 1);

    session.controller.add(BonsoirDiscoveryServiceFoundEvent(service: service('Living Room TV')));
    session.controller.add(BonsoirDiscoveryServiceLostEvent(service: service('Living Room TV')));
    await pumpEventQueue();

    expect(found.single.name, 'Living Room TV');
    expect(found.single.hostAddress, '192.168.1.50');
    expect(found.single.port, 8000);
    expect(lost.single, 'Living Room TV');

    await channel.dispose();
  });

  test('one type failing to initialize does not take the channel down', () async {
    final healthy = ScriptedSession();
    final broken = ScriptedSessionBroken();
    final types = <String>['_broken._tcp', '_mediarenderer._tcp'];
    final errors = <Object>[];
    final channel = BonsoirDiscoveryChannel(
      serviceTypes: types,
      sessionFactory: (type) => type == '_broken._tcp' ? broken : healthy,
    );
    channel.errors.listen(errors.add);

    await channel.start();

    expect(errors, hasLength(1));
    expect(healthy.started, 1, reason: 'the healthy type still browses');

    await channel.dispose();
  });

  test('stop is idempotent and start restarts with fresh sessions', () async {
    final sessions = <ScriptedSession>[];
    final channel = BonsoirDiscoveryChannel(
      sessionFactory: (type) {
        final session = ScriptedSession();
        sessions.add(session);
        return session;
      },
    );

    await channel.start();
    await channel.start();
    expect(sessions, hasLength(1), reason: 'a second start does not spawn a second session');
    expect(sessions.single.started, 1);

    await channel.stop();
    expect(sessions.single.stopped, 1);
    await channel.stop();
    expect(sessions.single.stopped, 1);

    await channel.start();
    expect(sessions, hasLength(2), reason: 'Bonsoir discards stopped actions, so a restart builds a new session');
    await channel.dispose();
  });
}

/// A session whose platform initialize always fails.
final class ScriptedSessionBroken implements MDnsDiscoverySession {
  @override
  Stream<BonsoirDiscoveryEvent>? get events => null;

  @override
  Future<void> initialize() async {
    throw StateError('platform has no mDNS');
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
