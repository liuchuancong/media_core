import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';
import '../support/log_sink.dart';

DlnaDevice device() {
  return DlnaDevice(
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
  );
}

void main() {
  late CapturingLogSink sink;

  setUp(() {
    sink = CapturingLogSink()..install();
  });

  tearDown(() => sink.uninstall());

  test('the default sink drops records without crashing', () {
    DlnaLog.sink = null;

    expect(() => DlnaLog.info(DlnaLogCategory.discovery, 'dropped'), returnsNormally);
  });

  test('a throwing sink never breaks the emitter', () {
    DlnaLog.sink = (_) => throw StateError('broken logger');

    expect(() => DlnaLog.warning(DlnaLogCategory.session, 'still works'), returnsNormally);
    DlnaLog.sink = null;
  });

  test('discovery emits device found/lost at info level', () async {
    final ssdp = ScriptedSsdpSource();
    final manager = DlnaDiscoveryManager(ssdp: ssdp, fetchDescription: (url) async => tvDescription);
    await manager.start();

    ssdp.controller.add(aliveMessage());
    await pumpEventQueue();
    ssdp.controller.add(byebyeMessage());
    await pumpEventQueue();

    expect(sink.has(DlnaLogCategory.discovery, DlnaLogLevel.info, messageContains: 'device found'), isTrue);
    expect(sink.has(DlnaLogCategory.discovery, DlnaLogLevel.info, messageContains: 'device lost'), isTrue);
    expect(sink.has(DlnaLogCategory.discovery, DlnaLogLevel.info, messageContains: 'discovery started'), isTrue);

    await manager.dispose();
  });

  test('a broken description emits a discovery warning with the usn', () async {
    final ssdp = ScriptedSsdpSource();
    final manager = DlnaDiscoveryManager(ssdp: ssdp, fetchDescription: (url) async => '<broken');
    await manager.start();

    ssdp.controller.add(aliveMessage());
    await pumpEventQueue();

    final warning = sink.find(DlnaLogCategory.discovery, DlnaLogLevel.warning, messageContains: 'description failed');
    expect(warning, isNotNull);
    expect(warning!.fields['usn'], 'uuid:TV-001');
    await manager.dispose();
  });

  test('soap faults emit a soap warning with the UPnP code', () async {
    final transport = FakeSoapTransport(
      (url, headers, body) => const SoapHttpResponse(
        statusCode: 500,
        body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>
<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>701</errorCode>
</UPnPError></detail></s:Fault></s:Body></s:Envelope>
''',
      ),
    );
    final client = SoapClient(transport: transport);
    final service = DlnaService(
      serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
      controlUrl: Uri.parse('http://tv/av'),
    );

    await expectLater(client.invoke(service: service, action: 'Pause'), throwsA(isA<DlnaUpnpException>()));

    expect(sink.has(DlnaLogCategory.soap, DlnaLogLevel.warning, messageContains: 'device refused action'), isTrue);
  });

  test('session recovery emits the warning-to-error arc', () async {
    final av = ScriptedAvTransport();
    av.transport.respond = (url, headers, body) => throw const SocketException('gone');
    final session = DlnaSessionController(
      device: device(),
      client: SoapClient(transport: av.transport),
      fetchScpd: (url) async => throw const SocketException('unreachable'),
      recoveryPolicy: const DlnaRecoveryPolicy(maxAttempts: 2, retryDelay: Duration(milliseconds: 10)),
    );
    await session.connect();

    await expectLater(session.play(), throwsA(isA<DlnaNetworkException>()));
    while (session.connectionState == DlnaConnectionState.reconnecting) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(sink.has(DlnaLogCategory.session, DlnaLogLevel.warning, messageContains: 'recovery started'), isTrue);
    expect(sink.has(DlnaLogCategory.session, DlnaLogLevel.error, messageContains: 'recovery exhausted'), isTrue);
    await session.dispose();
  });

  test('loggableUrl strips the query so tokens never reach a sink', () {
    final url = Uri.parse('http://192.168.1.10:8080/gena/abc123?token=secret');

    final safe = loggableUrl(url);

    expect(safe, isNot(contains('secret')));
    expect(safe, 'http://192.168.1.10:8080/gena/abc123');
  });
}
