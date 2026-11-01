import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../../../support/fakes.dart';

void main() {
  group('GenaMessageParser', () {
    test('parses a plain PropertySet', () {
      const body = '''
<?xml version="1.0"?>
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
  <e:property><TransportState>PLAYING</TransportState></e:property>
  <e:property><RelativeTimePosition>00:00:42</RelativeTimePosition></e:property>
</e:propertyset>
''';

      final variables = GenaMessageParser.parsePropertySet(body);

      expect(variables['TransportState'], 'PLAYING');
      expect(variables['RelativeTimePosition'], '00:00:42');
      expect(variables.transportState, DlnaTransportState.playing);
      expect(variables.position, const Duration(seconds: 42));
    });

    test('unfolds an AVT LastChange document', () {
      const body = '''
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
  <e:property><LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
    &lt;InstanceID val="0"&gt;
      &lt;TransportState val="PAUSED_PLAYBACK"/&gt;
      &lt;CurrentTrackDuration val="01:30:00"/&gt;
    &lt;/InstanceID&gt;
  &lt;/Event&gt;</LastChange></e:property>
</e:propertyset>
''';

      final variables = GenaMessageParser.parsePropertySet(body);

      expect(variables['TransportState'], 'PAUSED_PLAYBACK');
      expect(variables['CurrentTrackDuration'], '01:30:00');
      expect(variables.transportState, DlnaTransportState.paused);
      expect(variables.duration, const Duration(hours: 1, minutes: 30));
    });

    test('junk bodies yield empty maps, not exceptions', () {
      expect(GenaMessageParser.parsePropertySet('<broken'), isEmpty);
      expect(GenaMessageParser.parseLastChange('not xml at all'), isEmpty);
    });
  });

  group('GenaCallbackServer', () {
    late GenaCallbackServer server;

    Future<HttpClientResponse> notify(Uri url, {required String sid, required String seq, String? body}) async {
      final client = HttpClient();
      final request = await client.openUrl('NOTIFY', url);
      request.headers.set('SID', sid);
      request.headers.set('SEQ', seq);
      request.headers.set('NT', 'upnp:event');
      request.headers.set('NTS', 'upnp:propchange');
      request.add(utf8.encode(body ?? _propertySet('TransportState', 'PLAYING')));
      final response = await request.close();
      await response.drain<void>();
      Future<void>.delayed(const Duration(seconds: 5), client.close);
      return response;
    }

    setUpAll(() async {
      server = GenaCallbackServer(addressSelector: () async => InternetAddress.loopbackIPv4);
      await server.start();
    });

    tearDownAll(() => server.stop());

    test('a NOTIFY on the registered route reaches the handler; SEQ dedups', () async {
      final received = <GenaNotification>[];
      final url = server.registerHandler(received.add);

      await notify(url, sid: 'uuid:sub-1', seq: '0');
      await notify(url, sid: 'uuid:sub-1', seq: '1');
      await notify(url, sid: 'uuid:sub-1', seq: '1', body: _propertySet('TransportState', 'STOPPED'));
      await pumpEventQueue();

      expect(received, hasLength(2), reason: 'the replayed SEQ=1 is acknowledged and dropped');
      expect(received.first.seq, 0);
      expect(received.last.variables['TransportState'], 'PLAYING');
    });

    test('an unknown route answers 404 and a wrong method answers 405', () async {
      final client = HttpClient();

      final stray = await client
          .openUrl('NOTIFY', Uri.parse('http://127.0.0.1:${server.boundPort}/gena/not-a-token'))
          .then((request) => request.close());
      expect(stray.statusCode, HttpStatus.notFound);
      await stray.drain<void>();

      final wrongMethod = await client
          .openUrl('POST', Uri.parse('http://127.0.0.1:${server.boundPort}/gena/anything'))
          .then((request) => request.close());
      expect(wrongMethod.statusCode, HttpStatus.methodNotAllowed);
      await wrongMethod.drain<void>();
      client.close(force: true);
    });
  });

  group('GenaSubscriber', () {
    late ScriptedGenaTransport transport;

    setUp(() {
      transport = ScriptedGenaTransport();
    });

    test('subscribe stores SID and timeout; renewals extend it', () async {
      var subscribeCount = 0;
      final subscriber = GenaSubscriber(
        transport: transport,
        service: _avTransport(),
        callbackUrl: Uri.parse('http://192.168.1.10:9000/gena/x'),
        onNotification: (_) {},
        lifetime: const Duration(seconds: 4),
      );
      transport.onRequest = (method, url, headers) {
        if (method == 'SUBSCRIBE') {
          subscribeCount++;
          return const GenaHttpResponse(
            statusCode: 200,
            headers: <String, String>{'sid': 'uuid:sub-9', 'timeout': 'Second-2'},
          );
        }
        return const GenaHttpResponse(statusCode: 200, headers: <String, String>{});
      };

      await subscriber.subscribe();
      expect(subscriber.isActive, isTrue);
      expect(subscriber.subscription!.sid, 'uuid:sub-9');
      expect(subscribeCount, 1);

      // The renewal fires at half the granted lifetime (1s).
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(subscribeCount, 2, reason: 'the renewal re-SUBSCRIBEs with the SID before expiry');
      expect(subscriber.subscription!.isExpired, isFalse);
      await subscriber.dispose();
    });

    test('exhausted renewals fail the subscriber instead of retrying forever', () async {
      GenaSubscriber? failedWith;
      final subscriber = GenaSubscriber(
        transport: transport,
        service: _avTransport(),
        callbackUrl: Uri.parse('http://192.168.1.10:9000/gena/x'),
        onNotification: (_) {},
        onFailed: (subscriber) => failedWith = subscriber,
        lifetime: const Duration(seconds: 2),
      );
      transport.onRequest = (method, url, headers) {
        if (headers.containsKey('SID')) {
          return const GenaHttpResponse(statusCode: 412, headers: <String, String>{});
        }
        return const GenaHttpResponse(
          statusCode: 200,
          headers: <String, String>{'sid': 'uuid:sub-x', 'timeout': 'Second-2'},
        );
      };

      await subscriber.subscribe();
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      expect(subscriber.isFailed, isTrue, reason: 'three 412 renewals in a row give up');
      expect(identical(failedWith, subscriber), isTrue);
      await subscriber.dispose();
    });

    test('dispose unsubscribes and SID mismatches are ignored', () async {
      final methods = <String>[];
      GenaNotification? seen;
      final subscriber = GenaSubscriber(
        transport: transport,
        service: _avTransport(),
        callbackUrl: Uri.parse('http://192.168.1.10:9000/gena/x'),
        onNotification: (notification) => seen = notification,
        lifetime: const Duration(seconds: 30),
      );
      transport.onRequest = (method, url, headers) {
        methods.add(method);
        return const GenaHttpResponse(
          statusCode: 200,
          headers: <String, String>{'sid': 'uuid:sub-2', 'timeout': 'Second-30'},
        );
      };

      await subscriber.subscribe();
      subscriber.handle(const GenaNotification(sid: 'uuid:other', seq: 0, variables: <String, String>{}));
      expect(seen, isNull, reason: '§22.4: a foreign SID must not reach the handler');

      subscriber.handle(
        const GenaNotification(sid: 'uuid:sub-2', seq: 3, variables: <String, String>{'TransportState': 'STOPPED'}),
      );
      expect(seen!.variables['TransportState'], 'STOPPED');

      await subscriber.dispose();
      expect(methods.last, 'UNSUBSCRIBE');
    });
  });
}

DlnaService _avTransport() {
  return DlnaService(
    serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
    controlUrl: Uri.parse('http://tv/av'),
    eventSubUrl: Uri.parse('http://tv/event/av'),
  );
}

String _propertySet(String name, String value) {
  return '<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"> '
      '<e:property><$name>$value</$name></e:property>'
      '</e:propertyset>';
}
