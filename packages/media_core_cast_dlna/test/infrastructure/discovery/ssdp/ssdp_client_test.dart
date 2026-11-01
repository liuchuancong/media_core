import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

void main() {
  group('SsdpClient over a real loopback socket', () {
    // Multicast itself cannot be exercised on a CI box; what these
    // tests buy is proof of the socket plumbing: the bound socket
    // receives datagrams, decodes them, tracks their cache lifetime
    // and releases everything on stop.

    test('a unicast search response reaches the message stream', () async {
      final client = SsdpClient();
      final received = <SsdpMessage>[];
      final subscription = client.messages.listen(received.add);

      await client.start();
      expect(client.port, isNotNull);

      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      const payload = '''
HTTP/1.1 200 OK
CACHE-CONTROL: max-age=1800
ST: urn:schemas-upnp-org:device:MediaRenderer:1
USN: uuid:TV-002::urn:schemas-upnp-org:device:MediaRenderer:1
LOCATION: http://192.168.1.41:8090/desc.xml
''';
      sender.send(utf8.encode(payload), InternetAddress.loopbackIPv4, client.port!);

      await pumpEventQueue();
      expect(received.where((message) => message.isSearchResponse), hasLength(1));
      expect(received.single.deviceId, 'uuid:TV-002');

      sender.close();
      await subscription.cancel();
      await client.stop();
      expect(client.port, isNull);
    });

    test('an announcement nobody renews expires on its own max-age', () async {
      final client = SsdpClient();
      final received = <SsdpMessage>[];
      final subscription = client.messages.listen(received.add);

      await client.start();

      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      const payload = '''
NOTIFY * HTTP/1.1
HOST: 239.255.255.250:1900
CACHE-CONTROL: max-age=1
LOCATION: http://192.168.1.40/desc.xml
NT: urn:schemas-upnp-org:device:MediaRenderer:1
NTS: ssdp:alive
USN: uuid:TV-003::urn:schemas-upnp-org:device:MediaRenderer:1
''';
      sender.send(utf8.encode(payload), InternetAddress.loopbackIPv4, client.port!);

      SsdpMessage? expired;
      for (var i = 0; i < 50 && expired == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expired = received
            .where((message) => message.method == 'EXPIRED' && message.deviceId == 'uuid:TV-003')
            .firstOrNull;
      }
      expect(expired, isNotNull);

      sender.close();
      await subscription.cancel();
      await client.stop();
    });

    test('start is idempotent and stop releases the socket', () async {
      final client = SsdpClient();

      await client.start();
      final port = client.port;
      await client.start();
      expect(client.port, port);

      await client.stop();
      expect(client.port, isNull);

      // A stopped client stays stopped and does not throw on a
      // second stop.
      await client.stop();
    });
  });
}
