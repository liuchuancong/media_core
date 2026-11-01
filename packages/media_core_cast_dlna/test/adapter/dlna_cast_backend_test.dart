import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';

SoapHttpResponse Function(Uri url, Map<String, String> headers, String body)? responder;

void main() {
  late ScriptedSsdpSource source;
  late DlnaCastBackend backend;
  late FakeSoapTransport transport;
  late List<CastEvent> seen;

  Future<void> drain() => pumpEventQueue();

  setUp(() {
    source = ScriptedSsdpSource();
    responder = null;
    seen = <CastEvent>[];
    transport = FakeSoapTransport(
      (url, headers, body) =>
          responder?.call(url, headers, body) ??
          const SoapHttpResponse(statusCode: 200, body: '<s:Envelope></s:Envelope>'),
    );
    backend = DlnaCastBackend(discovery: source, fetchDescription: (url) async => tvDescription, transport: transport);
    backend.events.listen(seen.add);
  });

  tearDown(() => backend.dispose());

  Future<CastDevice> announced() async {
    await backend.startDiscovery();
    source.controller.add(aliveMessage());
    await drain();
    return backend.devices.single;
  }

  group('discovery to picker', () {
    test('an announcement resolves its description and surfaces a device', () async {
      await backend.startDiscovery();
      source.controller.add(aliveMessage());
      await drain();

      expect(backend.devices, hasLength(1));
      final device = backend.devices.single;
      expect(device.name, 'Salon TV');
      expect(device.serviceEndpoints['AVTransport'], 'http://192.168.1.40/av');
      expect(seen, contains(isA<DeviceFound>()));
    });

    test('a byebye removes the device', () async {
      await backend.startDiscovery();
      source.controller.add(aliveMessage());
      await drain();
      expect(backend.devices, hasLength(1));

      source.controller.add(byebyeMessage());
      await drain();

      expect(backend.devices, isEmpty);
      expect(seen.whereType<DeviceLost>(), hasLength(1));
    });

    test('an unparseable description yields a fault, not a device', () async {
      backend = DlnaCastBackend(discovery: source, fetchDescription: (url) async => '<broken', transport: transport);
      final events = <CastEvent>[];
      backend.events.listen(events.add);
      await backend.startDiscovery();

      source.controller.add(aliveMessage());
      await drain();

      expect(backend.devices, isEmpty);
      expect(events.whereType<CastFault>(), hasLength(1));
      await backend.dispose();
    });
  });

  group('transport commands', () {
    test('setMedia posts the DIDL and play posts the action header', () async {
      final device = await announced();

      await backend.setMedia(device, const CastMedia(url: 'http://cdn/m.mp4', title: 'M'));
      await backend.play(device);

      expect(transport.sent, hasLength(2));
      expect(transport.sent.first.headers['SOAPAction'], contains('#SetAVTransportURI'));
      expect(transport.sent.first.body, contains('http://cdn/m.mp4'));
      expect(transport.sent.last.headers['SOAPAction'], contains('#Play'));
    });

    test('a device fault raises CastException with the UPnP code', () async {
      responder = (url, headers, body) => const SoapHttpResponse(
        statusCode: 500,
        body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>
<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>701</errorCode>
<errorDescription>TransportStateError</errorDescription></UPnPError></detail>
</s:Fault></s:Body></s:Envelope>
''',
      );
      final device = await announced();

      await expectLater(
        backend.play(device),
        throwsA(isA<CastException>().having((e) => e.message, 'message', contains('701'))),
      );
    });

    test('a network failure raises CastException, not a raw socket error', () async {
      responder = (url, headers, body) => throw const SocketException('no route');
      final device = await announced();

      await expectLater(backend.play(device), throwsA(isA<CastException>()));
    });

    test('GetPositionInfo decodes into a position', () async {
      responder = (url, headers, body) => const SoapHttpResponse(
        statusCode: 200,
        body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<RelTime>00:01:23.000</RelTime><TrackDuration>00:45:00</TrackDuration>
</u:GetPositionInfoResponse></s:Body></s:Envelope>
''',
      );
      final device = await announced();

      final position = await backend.position(device);

      expect(position.position, const Duration(minutes: 1, seconds: 23));
      expect(position.duration, const Duration(minutes: 45));
    });

    test('an unreachable device yields the unknown position, not a throw', () async {
      responder = (url, headers, body) => throw Exception('socket closed');
      final device = await announced();

      final position = await backend.position(device);

      expect(position.transportState, CastTransportState.unknown);
    });

    test('volume goes to the RenderingControl endpoint', () async {
      final device = await announced();

      await backend.setVolume(device, 142);

      expect(transport.sent.single.headers['SOAPAction'], contains('#SetVolume'));
      // UPnP volume is 0..100; the adapter clamps instead of tripping a
      // device-side 402.
      expect(transport.sent.single.body, contains('<DesiredVolume>100</DesiredVolume>'));
    });

    test('a device with no AVTransport endpoint is refused', () async {
      await backend.startDiscovery();
      final orphan = CastDevice.of(id: 'x', name: 'x', backendId: 'dlna');

      await expectLater(backend.play(orphan), throwsA(isA<CastException>()));
    });

    test('commands after dispose are refused', () async {
      final device = await announced();
      await backend.dispose();

      await expectLater(backend.play(device), throwsA(isA<CastException>()));
    });
  });

  group('local files and capabilities', () {
    late File localFile;

    setUpAll(() async {
      localFile = File(
        '${Directory.systemTemp.path}/media_core_cast_dlna_backend_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      await localFile.writeAsBytes(List<int>.generate(64, (i) => i));
    });

    tearDownAll(() {
      if (localFile.existsSync()) {
        localFile.deleteSync();
      }
    });

    test('a local file is served through the media server, not sent as a path', () async {
      final server = MediaHttpServer(addressSelector: () async => InternetAddress.loopbackIPv4);
      await server.start();
      backend = DlnaCastBackend(
        discovery: source,
        fetchDescription: (url) async => tvDescription,
        transport: transport,
        mediaServer: server,
      );
      backend.events.listen(seen.add);
      await backend.startDiscovery();
      source.controller.add(aliveMessage());
      await drain();
      final device = backend.devices.single;

      await backend.setMedia(device, CastMedia(url: localFile.path, title: 'Local', mimeType: 'video/mp4'));

      final body = transport.sent.single.body;
      expect(body, contains('<CurrentURI>http://127.0.0.1:'), reason: 'the TV gets a LAN URL, never the file path');
      expect(body, isNot(contains(localFile.path)));

      // The rewritten URL must actually serve the file's bytes.
      final match = RegExp('<CurrentURI>(http://[^<]+)</CurrentURI>').firstMatch(body)!;
      final client = HttpClient();
      final response = await client.getUrl(Uri.parse(match.group(1)!)).then((request) => request.close());
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'video/mp4');
      final served = await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(served, hasLength(64));
      client.close(force: true);
    });

    test('a second cast to the same device drops the first registration', () async {
      final device = await announced();

      await backend.setMedia(device, CastMedia(url: localFile.path, title: 'First', mimeType: 'video/mp4'));
      final firstUrl = RegExp(
        '<CurrentURI>(http://[^<]+)</CurrentURI>',
      ).firstMatch(transport.sent.last.body)!.group(1)!;
      await backend.setMedia(device, CastMedia(url: localFile.path, title: 'Second', mimeType: 'video/mp4'));

      final client = HttpClient();
      final response = await client.getUrl(Uri.parse(firstUrl)).then((request) => request.close());
      expect(response.statusCode, HttpStatus.notFound, reason: 'the replaced cast is no longer served');
      client.close(force: true);
    });

    test('a device that declares no support for the format refuses the cast up front', () async {
      // A device whose ConnectionManager answers GetProtocolInfo with
      // an mp4-only sink.
      final description = tvDescription.replaceFirst('</serviceList>', '''
  <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <controlURL>/cm</controlURL>
      </service>
    </serviceList>''');
      backend = DlnaCastBackend(
        discovery: source,
        fetchDescription: (url) async => description,
        transport: FakeSoapTransport(
          (url, headers, body) => headers['SOAPAction']!.contains('GetProtocolInfo')
              ? const SoapHttpResponse(
                  statusCode: 200,
                  body:
                      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
                      '<u:GetProtocolInfoResponse xmlns:u="urn:schemas-upnp-org:service:ConnectionManager:1"> '
                      '<Sink>http-get:*:video/mp4:*</Sink> '
                      '</u:GetProtocolInfoResponse></s:Body></s:Envelope>',
                )
              : const SoapHttpResponse(statusCode: 200, body: '<s:Envelope></s:Envelope>'),
        ),
      );
      final events = <CastEvent>[];
      backend.events.listen(events.add);
      await backend.startDiscovery();
      source.controller.add(aliveMessage());
      await drain();
      final device = backend.devices.single;

      await expectLater(
        backend.setMedia(device, const CastMedia(url: 'http://cdn/a.webm', title: 'WebM', mimeType: 'video/webm')),
        throwsA(
          isA<CastException>()
              .having((e) => e.message, 'message', contains('cannot play any resource'))
              .having(
                (e) => e.cause,
                'cause',
                isA<DlnaUnsupportedMediaException>().having(
                  (error) => error.reasons.single,
                  'reason',
                  contains('does not declare video/webm'),
                ),
              ),
        ),
      );
      expect(transport.sent, isEmpty, reason: 'the refusal happens before SetAVTransportURI');
      await backend.dispose();
    });
  });
}
