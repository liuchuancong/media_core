import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../../support/fakes.dart';

DlnaDevice device({bool withScpd = false}) {
  return DlnaDevice(
    udn: 'uuid:TV-001',
    friendlyName: 'Salon TV',
    deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
    location: Uri.parse('http://192.168.1.40/desc.xml'),
    services: <DlnaService>[
      DlnaService(
        serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
        controlUrl: Uri.parse('http://192.168.1.40/av'),
        scpdUrl: withScpd ? Uri.parse('http://192.168.1.40/av.xml') : null,
      ),
    ],
    discoveredAt: DateTime(2026),
    lastSeenAt: DateTime(2026),
  );
}

DlnaService _renderingControl() {
  return DlnaService(
    serviceType: 'urn:schemas-upnp-org:service:RenderingControl:1',
    controlUrl: Uri.parse('http://tv/rc'),
  );
}

DlnaDevice deviceWithEventSub() {
  return DlnaDevice(
    udn: 'uuid:TV-001',
    friendlyName: 'Salon TV',
    deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
    location: Uri.parse('http://192.168.1.40/desc.xml'),
    services: <DlnaService>[
      DlnaService(
        serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
        controlUrl: Uri.parse('http://192.168.1.40/av'),
        eventSubUrl: Uri.parse('http://192.168.1.40/event/av'),
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
  group('DlnaTransportState', () {
    test('maps the UPnP vocabulary; junk lands on unknown', () {
      expect(DlnaTransportState.fromUpnp('PLAYING'), DlnaTransportState.playing);
      expect(DlnaTransportState.fromUpnp('PAUSED_PLAYBACK'), DlnaTransportState.paused);
      expect(DlnaTransportState.fromUpnp('NO_MEDIA_PRESENT'), DlnaTransportState.noMediaPresent);
      expect(DlnaTransportState.fromUpnp('TRANSITIONING'), DlnaTransportState.transitioning);
      expect(DlnaTransportState.fromUpnp('NOT_IMPLEMENTED'), DlnaTransportState.unknown);
      expect(DlnaTransportState.fromUpnp(null), DlnaTransportState.unknown);
    });
  });

  group('RenderingControlService', () {
    late FakeSoapTransport transport;

    setUp(() {
      transport = FakeSoapTransport((url, headers, body) {
        final action = headers['SOAPAction'] ?? '';
        if (action.contains('GetVolume')) {
          return const SoapHttpResponse(
            statusCode: 200,
            body:
                '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
                '<u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"> '
                '<CurrentVolume>37</CurrentVolume>'
                '</u:GetVolumeResponse></s:Body></s:Envelope>',
          );
        }
        if (action.contains('GetMute')) {
          return const SoapHttpResponse(
            statusCode: 200,
            body:
                '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
                '<u:GetMuteResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"> '
                '<CurrentMute>1</CurrentMute>'
                '</u:GetMuteResponse></s:Body></s:Envelope>',
          );
        }
        return fakeResponseOk;
      });
    });

    test('volume round-trips clamped to 0..100', () async {
      final service = RenderingControlService(
        client: SoapClient(transport: transport),
        service: _renderingControl(),
      );

      expect(await service.getVolume(), 37);
      expect(await service.setVolume(142), 100, reason: 'out-of-range clamps instead of tripping a 402');
      expect(await service.setVolume(-5), 0);
      expect(transport.sent.last.body, contains('<DesiredVolume>0</DesiredVolume>'));
      expect(transport.sent.first.headers['SOAPAction'], contains('#GetVolume'));
    });

    test('mute reads 1/0 answers and sets with named arguments', () async {
      final service = RenderingControlService(
        client: SoapClient(transport: transport),
        service: _renderingControl(),
      );

      expect(await service.isMuted(), isTrue);
      await service.setMute(muted: false);
      expect(transport.sent.last.body, contains('<DesiredMute>0</DesiredMute>'));
    });
  });

  group('DlnaCommandQueue', () {
    test('commands run serially in submission order', () async {
      final queue = DlnaCommandQueue();
      final order = <String>[];

      final futures = <Future<String>>[
        queue.submit(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          order.add('slow');
          return 'slow';
        }),
        queue.submit(() async {
          order.add('fast');
          return 'fast';
        }),
      ];

      expect(await futures[0], 'slow');
      expect(await futures[1], 'fast');
      expect(order, <String>['slow', 'fast']);
    });

    test('cancelPending drops queued work with a session exception', () async {
      final queue = DlnaCommandQueue();
      final started = Completer<void>();
      final gate = Completer<void>();

      final first = queue.submit(() async {
        started.complete();
        await gate.future;
        return 1;
      });
      // Wait until the first command is genuinely running; only then is
      // the second one strictly queued-but-not-started.
      await started.future;
      final second = queue.submit(() async => 2);

      queue.cancelPending();
      // The serial queue only reaches `second` once the running command
      // finishes, so the gate opens before the cancellation can be
      // observed.
      gate.complete();
      await expectLater(second, throwsA(isA<DlnaSessionException>()));
      expect(await first, 1, reason: 'the running command finishes; only queued work is dropped');
    });

    test('submit after dispose throws', () async {
      final queue = DlnaCommandQueue();
      await queue.submit(() async => 1);
      await queue.dispose();

      expect(() => queue.submit(() async => 2), throwsA(isA<DlnaSessionException>()));
    });
  });

  group('DlnaPlaybackMonitor', () {
    test('ticks adapt to the transport state and stop when idle', () async {
      var ticks = 0;
      final monitor =
          DlnaPlaybackMonitor(
              onTick: () => ticks++,
              options: const DlnaPlaybackMonitorOptions(playingInterval: Duration(milliseconds: 20)),
            )
            ..start()
            ..updateTransportState(DlnaTransportState.playing);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      final playingTicks = ticks;
      expect(playingTicks, greaterThanOrEqualTo(2));

      monitor.updateTransportState(DlnaTransportState.noMediaPresent);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ticks, playingTicks, reason: 'an idle renderer has no playhead to poll');

      monitor.dispose();
    });
  });

  group('DlnaSessionController', () {
    late ScriptedAvTransport av;
    late DlnaSessionController session;
    final clock = <DateTime>[DateTime(2026)];

    Future<void> drain() => pumpEventQueue();

    setUp(() {
      av = ScriptedAvTransport();
      clock
        ..clear()
        ..add(DateTime(2026));
      session = DlnaSessionController(
        device: device(),
        client: SoapClient(transport: av.transport),
        monitorOptions: const DlnaPlaybackMonitorOptions(playingInterval: Duration(milliseconds: 20)),
        now: () => clock.last,
      );
    });

    tearDown(() => session.dispose());

    test('connect validates the device and reports connected', () async {
      await session.connect();

      expect(session.connectionState, DlnaConnectionState.connected);
      expect(session.playbackState.transportState, DlnaTransportState.unknown);

      await session.disconnect();
      expect(session.connectionState, DlnaConnectionState.disconnected);
    });

    test('connect fails for a device without AVTransport', () async {
      final broken = DlnaSessionController(
        device: DlnaDevice(
          udn: 'uuid:X',
          friendlyName: 'x',
          deviceType: 'urn:schemas-upnp-org:device:MediaServer:1',
          location: Uri.parse('http://x/desc.xml'),
          services: const <DlnaService>[],
          discoveredAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        ),
        client: SoapClient(transport: av.transport),
      );

      await expectLater(broken.connect(), throwsA(isA<DlnaSessionException>()));
      expect(broken.connectionState, DlnaConnectionState.failed);
      await broken.dispose();
    });

    test('setMedia then play commands run in order and verify state', () async {
      final updates = <DlnaPlaybackState>[];
      session.playbackStateStream.listen(updates.add);
      await session.connect();

      await session.setMedia(media());
      await session.play();
      await drain();

      expect(
        av.sent.take(3),
        <String>['SetAVTransportURI', 'GetTransportInfo', 'Play'],
        reason:
            'setUri is followed '
            'by a state verification before play; the queue serializes the rest',
      );
      final last = updates.last;
      expect(last.transportState, DlnaTransportState.playing, reason: 'the device said PLAYING, not "command ok"');
      expect(last.currentTitle, '第四集');
      expect(last.currentUri, 'http://cdn/a.mp4');
    });

    test('the monitor polls while playing and advances position', () async {
      await session.connect();
      final updates = <DlnaPlaybackState>[];
      session.playbackStateStream.listen(updates.add);

      await session.setMedia(media());
      await session.play();
      await Future<void>.delayed(const Duration(milliseconds: 70));

      final withPosition = updates.where((state) => state.position != null).toList();
      expect(withPosition, isNotEmpty);
      expect(withPosition.last.duration, const Duration(minutes: 45));
      await session.dispose();
    });

    test('stop cancels queued commands; they complete with a session exception', () async {
      // A transport whose Play stalls long enough for a stop to be
      // queued behind it; the long client budget keeps the stall from
      // turning into a timeout before the gate opens.
      final stall = Completer<void>();
      av.transport.respond = (url, headers, body) {
        final action = headers['SOAPAction'] ?? '';
        if (action.contains('#Play')) {
          return stall.future.then((_) => fakeResponseOk);
        }
        if (action.contains('#GetTransportInfo')) {
          return const SoapHttpResponse(statusCode: 200, body: avTransportInfoResponse);
        }
        return fakeResponseOk;
      };
      final stalledSession = DlnaSessionController(
        device: device(),
        client: SoapClient(transport: av.transport, timeout: const Duration(seconds: 25)),
      );
      await stalledSession.connect();

      final play = stalledSession.play();
      // Wait until Play is genuinely on the wire; only then is a
      // following pause strictly queued-behind-it.
      while (!av.sent.contains('Play')) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final paused = stalledSession.pause();
      final stopped = stalledSession.stop();

      // The gate opens before the assertion: the paused command's fate
      // is decided only once the running play has finished.
      stall.complete();
      await expectLater(paused, throwsA(isA<DlnaSessionException>()));
      await play;
      await stopped;
      // The Stop went out after the stalled Play, and its follow-up
      // state read does not change that order.
      expect(av.sent.indexOf('Stop'), greaterThan(av.sent.indexOf('Play')));
      await stalledSession.dispose();
    });

    test('seek validates against the known duration', () async {
      await session.connect();
      await session.setMedia(media());
      await session.play();
      // A state read makes the device's 45:00 duration known; without
      // it the session cannot judge what "beyond the end" means.
      final state = await session.getPlaybackState();
      expect(state.duration, const Duration(minutes: 45));

      await session.seek(const Duration(minutes: 5));
      expect(av.sent, contains('Seek'));

      await expectLater(session.seek(const Duration(minutes: 50)), throwsArgumentError);
      await expectLater(session.seek(const Duration(seconds: -1)), throwsArgumentError);
    });

    test('commands before connect are refused', () async {
      await expectLater(session.play(), throwsA(isA<DlnaSessionException>()));
    });

    test('an SCPD-declared action set refuses undeclared actions locally', () async {
      final scpd = ScriptedAvTransport();
      final sessionWithScpd = DlnaSessionController(
        device: device(withScpd: true),
        client: SoapClient(transport: scpd.transport),
        fetchScpd: (url) async => '''
<scpd><actionList>
<action><name>Play</name></action>
<action><name>Stop</name></action>
<action><name>SetAVTransportURI</name></action>
<action><name>GetPositionInfo</name></action>
<action><name>GetTransportInfo</name></action>
</actionList></scpd>
''',
      );
      await sessionWithScpd.connect();
      await sessionWithScpd.setMedia(media());

      await expectLater(sessionWithScpd.pause(), throwsA(isA<DlnaUnsupportedActionException>()));
      await sessionWithScpd.dispose();
    });

    test('a silent device keeps its last state instead of flashing unknown', () async {
      await session.connect();
      await session.setMedia(media());
      await session.play();
      final before = session.playbackState;

      av.transport.respond = (url, headers, body) => throw StateError('device went away');
      clock.add(DateTime(2026).add(const Duration(seconds: 1)));
      final after = await session.getPlaybackState();

      expect(after.transportState, before.transportState, reason: 'one missed poll is not a state change');
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue, reason: 'the snapshot still refreshes its freshness');
    });
  });

  group('DlnaSessionManager', () {
    test('connecting twice returns the same session', () async {
      final av = ScriptedAvTransport();
      final manager = DlnaSessionManager(transport: av.transport);
      final first = await manager.connect(device());
      final second = await manager.connect(device());

      expect(identical(first, second), isTrue);
      expect(manager.sessions, hasLength(1));

      await manager.disconnect(first);
      expect(manager.sessions, isEmpty);
      await manager.dispose();
    });

    test('connect refuses a device without AVTransport', () async {
      final manager = DlnaSessionManager(transport: ScriptedAvTransport().transport);

      await expectLater(
        manager.connect(
          DlnaDevice(
            udn: 'uuid:X',
            friendlyName: 'x',
            deviceType: 'urn:schemas-upnp-org:device:MediaServer:1',
            location: Uri.parse('http://x/desc.xml'),
            services: const <DlnaService>[],
            discoveredAt: DateTime(2026),
            lastSeenAt: DateTime(2026),
          ),
        ),
        throwsA(isA<DlnaSessionException>()),
      );
      await manager.dispose();
    });

    test('GENA: a pushed event updates the session state, subscribe failure falls back', () async {
      // The SOAP transport serves control; the GENA transport
      // subscribes against a loopback callback server that this test
      // then NOTIFYs directly — the full push path without a TV.
      final av = ScriptedAvTransport();
      GenaHttpResponse genaResponder(String method, Uri url, Map<String, String> headers) {
        return const GenaHttpResponse(
          statusCode: 200,
          headers: <String, String>{'sid': 'uuid:gena-1', 'timeout': 'Second-300'},
        );
      }

      final gena = ScriptedGenaTransport()..onRequest = genaResponder;
      final server = GenaCallbackServer(addressSelector: () async => InternetAddress.loopbackIPv4);
      await server.start();
      final manager = DlnaSessionManager(
        transport: av.transport,
        genaTransport: gena,
        callbackServer: server,
        monitorOptions: const DlnaPlaybackMonitorOptions(playingInterval: Duration(milliseconds: 20)),
      );

      final updates = <DlnaPlaybackState>[];
      final session = await manager.connect(deviceWithEventSub());
      session.playbackStateStream.listen(updates.add);
      expect(session.gena, isNotNull, reason: 'the device advertises eventSubURL, so eventing is armed');
      expect(gena.sent.single.method, 'SUBSCRIBE');
      expect(gena.sent.single.headers['CALLBACK'], startsWith('<http://127.0.0.1:'));

      // The device pushes a state change; it must land on the stream.
      final callbackUrl = session.gena!.subscription!.callbackUrl;
      final httpClient = HttpClient();
      final request = await httpClient.openUrl('NOTIFY', callbackUrl);
      request.headers.set('SID', 'uuid:gena-1');
      request.headers.set('SEQ', '0');
      request.add(
        utf8.encode(
          '<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"> '
          '<e:property><TransportState>PAUSED_PLAYBACK</TransportState></e:property>'
          '</e:propertyset>',
        ),
      );
      final answer = await request.close();
      await answer.drain<void>();
      await pumpEventQueue();

      expect(session.playbackState.transportState, DlnaTransportState.paused);

      // A foreign SID is ignored (Sec 22.4).
      final stray = await httpClient.openUrl('NOTIFY', callbackUrl);
      stray.headers.set('SID', 'uuid:intruder');
      stray.headers.set('SEQ', '1');
      stray.add(
        utf8.encode(
          '<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0"> '
          '<e:property><TransportState>PLAYING</TransportState></e:property>'
          '</e:propertyset>',
        ),
      );
      await stray.close().then((response) => response.drain<void>());
      await pumpEventQueue();
      expect(session.playbackState.transportState, DlnaTransportState.paused);

      httpClient.close(force: true);
      await manager.disconnect(session);
      expect(gena.sent.map((exchange) => exchange.method), contains('UNSUBSCRIBE'));
      expect(server.routeCount, 0, reason: 'the callback route is cleaned up with the session');
      await server.stop();
      await manager.dispose();
    });

    test('GENA: a subscribe failure keeps the session on polling', () async {
      final gena = ScriptedGenaTransport()
        ..onRequest = (method, url, headers) => const GenaHttpResponse(statusCode: 501, headers: <String, String>{});
      final server = GenaCallbackServer(addressSelector: () async => InternetAddress.loopbackIPv4);
      await server.start();
      final manager = DlnaSessionManager(
        transport: ScriptedAvTransport().transport,
        genaTransport: gena,
        callbackServer: server,
      );

      final session = await manager.connect(deviceWithEventSub());

      expect(
        session.connectionState,
        DlnaConnectionState.connected,
        reason:
            '§14.7: eventing failure is not a '
            'session failure',
      );
      expect(session.gena!.isFailed, isTrue);
      expect(session.playbackState.transportState, DlnaTransportState.unknown);

      await manager.disconnect(session);
      await server.stop();
      await manager.dispose();
    });
  });

  group('DlnaClient', () {
    test('discovery, prepare and connect work end to end without a network', () async {
      final av = ScriptedAvTransport();
      final ssdp = ScriptedSsdpSource();
      final client = DlnaClient(ssdp: ssdp, fetchDescription: (url) async => tvDescription, transport: av.transport);
      final added = <DlnaDevice>[];
      client.deviceAdded.listen(added.add);

      await client.startDiscovery();
      ssdp.controller.add(aliveMessage());
      await pumpEventQueue();

      final tv = client.device('uuid:TV-001')!;
      final prepared = await client.prepareMedia(
        device: tv,
        title: '第四集',
        url: 'http://cdn/a.mp4',
        mimeType: 'video/mp4',
      );
      expect(prepared.resources.single.uri, Uri.parse('http://cdn/a.mp4'));

      final session = await client.connect(tv);
      await session.setMedia(prepared);
      await session.play();
      expect(av.sent, contains('Play'));

      await client.disconnect(session);
      await client.dispose();
    });
  });

  group('volume and mute (Phase 8)', () {
    test('setVolume and setMute ride the command queue to RenderingControl', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: DlnaDevice(
          udn: 'uuid:TV-001',
          friendlyName: 'Salon TV',
          deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
          location: Uri.parse('http://192.168.1.40/desc.xml'),
          services: <DlnaService>[device().avTransport!, _renderingControl()],
          discoveredAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        ),
        client: SoapClient(transport: av.transport),
      );
      await session.connect();

      await session.setVolume(142);
      await session.setMute(muted: true);

      expect(av.sent, contains('SetVolume'));
      expect(av.sent, contains('SetMute'));
      expect(session.playbackState.volume, 100, reason: 'clamped, and the snapshot carries it');
      expect(session.playbackState.isMuted, isTrue);
      await session.dispose();
    });

    test('a device without RenderingControl refuses volume politely', () async {
      final session = DlnaSessionController(
        device: device(),
        client: SoapClient(transport: ScriptedAvTransport().transport),
      );
      await session.connect();

      await expectLater(session.setVolume(30), throwsA(isA<DlnaSessionException>()));
      await session.dispose();
    });
  });

  group('multi-device isolation (Phase 8)', () {
    test('two sessions play independently; one device failing does not touch the other', () async {
      final wire = ScriptedAvTransport();
      // Production routes every session through one transport; the URL
      // on each SOAP call says which device it is for.
      final manager = DlnaSessionManager(transport: wire.transport);

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

      final sessionA = await manager.connect(fixture('uuid:TV-A'));
      final sessionB = await manager.connect(fixture('uuid:TV-B'));

      await sessionA.play();
      expect(wire.sent, contains('Play'));
      final playsAfterA = wire.sent.where((action) => action == 'Play').length;

      await sessionA.dispose();
      expect(
        sessionB.connectionState,
        DlnaConnectionState.connected,
        reason:
            'Sec 23.2: one session ending does '
            'not disturb the others',
      );
      await sessionB.play();
      expect(
        wire.sent.where((action) => action == 'Play').length,
        playsAfterA + 1,
        reason: 'B keeps commanding after A is gone',
      );
      await manager.dispose();
    });
  });
}
