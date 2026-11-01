import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';

/// Phase 10 §23.4: a fetch or poll that lands after stop/dispose must
/// neither resurrect a device nor write into a closed controller.
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

DlnaMedia media() {
  return DlnaMedia(
    id: 'm1',
    title: '第四集',
    mediaType: DlnaMediaType.video,
    sourceUri: Uri.parse('http://cdn/a.mp4'),
    mimeType: 'video/mp4',
    resources: <DlnaMediaResource>[DlnaMediaResource(uri: Uri.parse('http://cdn/a.mp4'), mimeType: 'video/mp4')],
  );
}

void main() {
  test('an in-flight resolve does not resurrect a device after stop', () async {
    final gate = Completer<void>();
    final ssdp = ScriptedSsdpSource();
    final manager = DlnaDiscoveryManager(
      ssdp: ssdp,
      fetchDescription: (url) async {
        await gate.future;
        return tvDescription;
      },
    );
    await manager.start();

    ssdp.controller.add(aliveMessage());
    // Let the manager reach the fetch (the gate holds it there).
    await pumpEventQueue();

    await manager.stop();
    gate.complete();
    await pumpEventQueue();
    await pumpEventQueue();

    expect(manager.devices, isEmpty, reason: 'a stale fetch result must not resurrect the device');
    expect(manager.state, DlnaDiscoveryState.stopped);
  });

  test('an in-flight session poll after dispose is dropped silently', () async {
    final gate = Completer<void>();
    final av = ScriptedAvTransport();
    av.transport.respond = (url, headers, body) {
      final action = headers['SOAPAction'] ?? '';
      if (action.contains('#GetTransportInfo')) {
        return gate.future.then((_) => const SoapHttpResponse(statusCode: 200, body: _playingResponse));
      }
      return fakeResponseOk;
    };
    final session = DlnaSessionController(
      device: device(),
      client: SoapClient(transport: av.transport),
      monitorOptions: const DlnaPlaybackMonitorOptions(playingInterval: Duration(milliseconds: 20)),
    );
    await session.connect();
    await session.setMedia(media());
    await session.play();

    // Dispose while the monitor poll is in flight.
    await session.dispose();
    gate.complete();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // Reaching here without a StateError from the closed playback
    // controller is the assertion.
  });
}

const String _playingResponse = '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<u:GetTransportInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<CurrentTransportState>PLAYING</CurrentTransportState>
</u:GetTransportInfoResponse></s:Body></s:Envelope>
''';
