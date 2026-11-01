import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';

void main() {
  late ScriptedSsdpSource ssdp;
  late List<DlnaDevice> added;
  late List<String> removed;
  late List<DlnaDiscoveryError> errors;
  var fetches = 0;

  Future<void> drain() => pumpEventQueue();

  DlnaDiscoveryManager build({
    DlnaDiscoveryOptions options = const DlnaDiscoveryOptions(),
    String Function()? description,
    DateTime Function()? now,
  }) {
    return DlnaDiscoveryManager(
      ssdp: ssdp,
      fetchDescription: (url) async {
        fetches++;
        final body = description?.call() ?? tvDescription;
        if (body.isEmpty) {
          throw const FormatException('unfetchable');
        }
        return body;
      },
      options: options,
      now: now,
    );
  }

  setUp(() {
    ssdp = ScriptedSsdpSource();
    added = <DlnaDevice>[];
    removed = <String>[];
    errors = <DlnaDiscoveryError>[];
    fetches = 0;
  });

  group('announcement to resolved device', () {
    test('an alive announcement resolves into a listed device', () async {
      final manager = build()..deviceAdded.listen(added.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();

      expect(manager.devices, hasLength(1));
      expect(manager.devices.single.udn, 'uuid:TV-001');
      expect(manager.devices.single.friendlyName, 'Salon TV');
      expect(manager.devices.single.avTransport!.controlUrl, Uri.parse('http://192.168.1.40/av'));
      expect(added, hasLength(1));
      expect(manager.state, DlnaDiscoveryState.active);

      await manager.dispose();
    });

    test('a renewal does not re-fetch or duplicate the device', () async {
      final manager = build();
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(aliveMessage());
      await drain();

      expect(fetches, 1);
      expect(manager.devices, hasLength(1));

      await manager.dispose();
    });

    test('a byebye removes the device', () async {
      final manager = build()..deviceRemoved.listen(removed.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(byebyeMessage());
      await drain();

      expect(manager.devices, isEmpty);
      expect(removed, <String>['uuid:TV-001']);

      await manager.dispose();
    });

    test('a synthetic expiry removes the device', () async {
      final manager = build()..deviceRemoved.listen(removed.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(expiredMessage());
      await drain();

      expect(manager.devices, isEmpty);
      expect(removed, <String>['uuid:TV-001']);

      await manager.dispose();
    });

    test('several devices are discovered at once and kept apart', () async {
      final manager = DlnaDiscoveryManager(
        ssdp: ssdp,
        fetchDescription: (url) async {
          fetches++;
          // A different address resolves a different device; sharing
          // the canned document would make both announcements one UDN.
          return url.contains('192.168.1.41') ? tvDescription.replaceAll('uuid:TV-001', 'uuid:TV-002') : tvDescription;
        },
      );
      await manager.start();

      ssdp.controller.add(aliveMessage());
      ssdp.controller.add(aliveMessage(usn: 'uuid:TV-002', location: 'http://192.168.1.41/desc.xml'));
      await drain();

      expect(fetches, 2);
      expect(manager.devices.map((device) => device.udn), <String>['uuid:TV-001', 'uuid:TV-002']);

      await manager.dispose();
    });

    test('a device whose USN and UDN disagree still leaves on byebye', () async {
      final manager = build()..deviceRemoved.listen(removed.add);
      await manager.start();

      // The USN root and the description UDN differ (a padded USN).
      ssdp.controller.add(aliveMessage(usn: 'uuid:UUID-ROOT::urn:schemas-upnp-org:device:MediaRenderer:1'));
      await drain();
      expect(manager.devices.single.udn, 'uuid:TV-001');

      ssdp.controller.add(byebyeMessage(usn: 'uuid:UUID-ROOT::urn:schemas-upnp-org:device:MediaRenderer:1'));
      await drain();

      expect(manager.devices, isEmpty);

      await manager.dispose();
    });
  });

  group('description failures', () {
    test('a broken description surfaces an error, not a device', () async {
      final manager = build(description: () => '<broken')..errors.listen(errors.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();

      expect(manager.devices, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single.usn, 'uuid:TV-001');

      await manager.dispose();
    });

    test('a failed device is backed off, then given another chance', () async {
      var clock = DateTime(2026);
      final manager = build(
        description: () => '<broken',
        now: () => clock,
        options: const DlnaDiscoveryOptions(descriptionFailureBackoff: Duration(seconds: 30)),
      );
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(aliveMessage());
      await drain();
      expect(fetches, 1, reason: 'within the backoff the device is not re-fetched');

      clock = clock.add(const Duration(seconds: 31));
      ssdp.controller.add(aliveMessage());
      await drain();
      expect(fetches, 2, reason: 'after the backoff the device gets one more chance');

      await manager.dispose();
    });

    test('a device without AVTransport is skipped silently', () async {
      final manager = build(
        description: () => tvDescription.replaceAll(RegExp('<service>.*?AVTransport.*?</service>', dotAll: true), ''),
      )..errors.listen(errors.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(aliveMessage());
      await drain();

      expect(manager.devices, isEmpty);
      expect(errors, isEmpty);
      expect(fetches, 1, reason: 'the skip cools the device down instead of re-fetching every renewal');

      await manager.dispose();
    });

    test('requireAvTransport off lists media servers too', () async {
      final manager = build(
        description: () => tvDescription.replaceAll(RegExp('<service>.*?AVTransport.*?</service>', dotAll: true), ''),
        options: const DlnaDiscoveryOptions(requireAvTransport: false),
      );
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();

      expect(manager.devices, hasLength(1));

      await manager.dispose();
    });
  });

  group('lifecycle', () {
    test('start is idempotent: no duplicate subscription or re-fetch', () async {
      final manager = build();
      await manager.start();
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();

      expect(fetches, 1);
      expect(manager.devices, hasLength(1));

      await manager.dispose();
    });

    test('stop drops the cache and reports stopped', () async {
      final manager = build();
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      expect(manager.devices, isNotEmpty);

      await manager.stop();

      expect(manager.devices, isEmpty);
      expect(manager.state, DlnaDiscoveryState.stopped);

      await manager.dispose();
    });

    test('refresh asks the source for a new search cycle', () async {
      final manager = build();
      await manager.start();

      await manager.refresh();

      expect(ssdp.searches, 1);

      await manager.dispose();
    });

    test('a location change re-resolves and reports updated', () async {
      final manager = build()..deviceUpdated.listen((_) {});
      final updated = <DlnaDevice>[];
      manager.deviceUpdated.listen(updated.add);
      await manager.start();

      ssdp.controller.add(aliveMessage());
      await drain();
      ssdp.controller.add(aliveMessage(location: 'http://192.168.1.99/desc.xml'));
      await drain();

      expect(fetches, 2);
      expect(manager.devices.single.location, Uri.parse('http://192.168.1.99/desc.xml'));
      expect(updated, hasLength(1));

      await manager.dispose();
    });

    test('dispose closes the streams; messages after dispose are ignored', () async {
      final manager = build();
      await manager.start();
      await manager.dispose();

      ssdp.controller.add(aliveMessage());
      await drain();

      expect(manager.devices, isEmpty);
    });
  });

  group('announcement burst (§29.1)', () {
    test('thirty simultaneous announcements all resolve under bounded concurrency', () async {
      final manager = DlnaDiscoveryManager(
        ssdp: ssdp,
        fetchDescription: (url) async {
          fetches++;
          return tvDescription;
        },
        options: const DlnaDiscoveryOptions(maxConcurrentDescriptions: 3),
      );
      await manager.start();

      // A burst: thirty distinct USNs on the wire at once. The canned
      // description resolves them all to one UDN, so the registry
      // collapses them — the assertion is that the *fetch* layer
      // handled all thirty under the concurrency cap.
      for (var i = 0; i < 30; i++) {
        ssdp.controller.add(aliveMessage(usn: 'uuid:TV-B$i', location: 'http://192.168.1.$i/desc.xml'));
      }
      await drain();

      expect(fetches, 30, reason: 'the bounded gate must not drop any announcement');
      await manager.dispose();
    });

    test('a duplicate burst collapses to one fetch and one record', () async {
      final manager = build();
      await manager.start();

      for (var i = 0; i < 10; i++) {
        ssdp.controller.add(aliveMessage());
      }
      await drain();

      expect(fetches, 1, reason: 'dedup collapses the burst to one fetch');
      expect(manager.devices, hasLength(1));
      await manager.dispose();
    });
  });
}
