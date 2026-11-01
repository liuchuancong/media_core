import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../support/fakes.dart';

void main() {
  test('diagnostics snapshot reflects discovery, sessions and the media server', () async {
    final ssdp = ScriptedSsdpSource();
    final client = DlnaClient(
      ssdp: ssdp,
      fetchDescription: (url) async => tvDescription,
      transport: FakeSoapTransport((url, headers, body) => fakeResponseOk),
    );

    var before = client.diagnostics();
    expect(before.discoveryRunning, isFalse);
    expect(before.discoveredDeviceCount, 0);
    expect(before.activeSessionCount, 0);
    expect(before.mediaServerRunning, isFalse);

    await client.startDiscovery();
    ssdp.controller.add(aliveMessage());
    await pumpEventQueue();

    final tv = client.device('uuid:TV-001')!;
    final session = await client.connect(tv);
    await client.mediaServer.start();

    before = client.diagnostics();
    expect(before.discoveryRunning, isTrue);
    expect(before.discoveredDeviceCount, 1);
    expect(before.activeSessionCount, 1);
    expect(before.mediaServerRunning, isTrue);
    expect(before.capturedAt.isAfter(DateTime(2026)), isTrue);
    expect(before.toString(), contains('devices: 1'));

    await client.disconnect(session);
    await client.dispose();
    expect(client.diagnostics().discoveredDeviceCount, 0);
  });
}
