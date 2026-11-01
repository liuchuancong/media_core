import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';

/// Phase 10 lifecycle-churn tests (§10 stability): the release gate for
/// "no known resource leaks" — every start/stop cycle must return the
/// process to the state it started in. Sockets, timers, registrations
/// and stream controllers are the leak candidates; each test hammers
/// one of them at a rate a human would never reach by hand.
void main() {
  group('SsdpClient churn', () {
    test('thirty start/stop cycles leave no socket open', () async {
      for (var i = 0; i < 30; i++) {
        final client = SsdpClient();
        await client.start();
        expect(client.port, isNotNull);
        await client.stop();
        expect(client.port, isNull);
      }
    });

    test('stop during a pending stagger does not crash', () async {
      final client = SsdpClient(searchInterval: const Duration(milliseconds: 5));
      await client.start();
      // Stop while the periodic re-search timer may be mid-fire.
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await client.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(client.port, isNull);
    });
  });

  group('MediaHttpServer churn', () {
    test('fifty start/stop cycles keep serving afterwards', () async {
      final file = File(
        '${Directory.systemTemp.path}/media_core_cast_dlna_stress_${DateTime.now().microsecondsSinceEpoch}.txt',
      );
      await file.writeAsString('payload');
      try {
        for (var i = 0; i < 50; i++) {
          final server = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);
          await server.start();
          final url = await server.registerFile(file, mimeType: 'text/plain');
          final client = HttpClient();
          final response = await client.getUrl(url).then((request) => request.close());
          expect(response.statusCode, HttpStatus.ok);
          await response.drain<void>();
          client.close(force: true);
          await server.stop();
        }

        // One more full cycle after the churn must still work.
        final server = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);
        await server.start();
        final url = await server.registerFile(file);
        final client = HttpClient();
        final response = await client.getUrl(url).then((request) => request.close());
        expect(response.statusCode, HttpStatus.ok);
        await response.drain<void>();
        client.close(force: true);
        await server.stop();
      } finally {
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    });
  });

  group('session churn', () {
    test('thirty connect/dispose cycles leave no timers or registrations', () async {
      final av = ScriptedAvTransport();
      final manager = DlnaSessionManager(transport: av.transport);
      DlnaDevice fixture(String udn) => DlnaDevice(
        udn: udn,
        friendlyName: udn,
        deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
        location: Uri.parse('http://192.168.1.40/desc.xml'),
        services: <DlnaService>[
          DlnaService(
            serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
            controlUrl: Uri.parse('http://192.168.1.40/av'),
          ),
        ],
        discoveredAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

      for (var i = 0; i < 30; i++) {
        final session = await manager.connect(fixture('uuid:TV-$i'));
        await session.play();
        await manager.disconnect(session);
      }

      expect(manager.sessions, isEmpty);
      await manager.dispose();
    });

    test('commands racing disposal all resolve, none hang', () async {
      final av = ScriptedAvTransport();
      final manager = DlnaSessionManager(transport: av.transport);
      final session = await manager.connect(
        DlnaDevice(
          udn: 'uuid:TV-001',
          friendlyName: 'Salon TV',
          deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
          location: Uri.parse('http://192.168.1.40/desc.xml'),
          services: <DlnaService>[
            DlnaService(
              serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
              controlUrl: Uri.parse('http://192.168.1.40/av'),
            ),
          ],
          discoveredAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        ),
      );

      // Attach the error handler at creation: a command cancelled by
      // the disconnect below settles with DlnaSessionException, and an
      // unhandled settling would crash the test zone.
      Future<void> settled(Future<void> command) => command.then((_) {}, onError: (Object _) {});
      final commands = <Future<void>>[
        settled(session.play()),
        settled(session.pause()),
        settled(session.seek(const Duration(minutes: 1))),
        settled(session.play()),
        settled(session.setVolume(50)),
        settled(session.setMute(muted: true)),
        settled(session.stop()),
      ];
      await manager.disconnect(session);
      // Every command must settle (some with DlnaSessionException from
      // cancellation); a hung future would fail the test timeout.
      await Future.wait(commands);
      await session.dispose();
      await manager.dispose();
    });
  });

  group('discovery churn', () {
    test('rapid start/stop cycles keep discovery correct afterwards', () async {
      for (var i = 0; i < 20; i++) {
        final ssdp = ScriptedSsdpSource();
        final manager = DlnaDiscoveryManager(ssdp: ssdp, fetchDescription: (url) async => tvDescription);
        await manager.start();
        if (i.isEven) {
          ssdp.controller.add(aliveMessage());
          await pumpEventQueue();
          expect(manager.devices, hasLength(1));
        }
        await manager.stop();
        expect(manager.devices, isEmpty);
        await manager.dispose();
      }

      // One more cycle after the churn must still resolve devices.
      final ssdp = ScriptedSsdpSource();
      final manager = DlnaDiscoveryManager(ssdp: ssdp, fetchDescription: (url) async => tvDescription);
      await manager.start();
      ssdp.controller.add(aliveMessage());
      await pumpEventQueue();
      expect(manager.devices, hasLength(1));
      await manager.dispose();
    });
  });
}
