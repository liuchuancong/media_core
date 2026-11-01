import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../../support/fakes.dart';

DlnaDevice deviceOf({String manufacturer = 'PlainTV', String model = 'Base', String udn = 'uuid:TV-001'}) {
  return DlnaDevice(
    udn: udn,
    friendlyName: 'Salon TV',
    deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
    location: Uri.parse('http://192.168.1.40/desc.xml'),
    manufacturer: manufacturer,
    modelName: model,
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
  group('DeviceCompatibilityRegistry', () {
    test('a device nothing matches gets the standard profile', () {
      final registry = DeviceCompatibilityRegistry();

      final profile = registry.profileFor(deviceOf(manufacturer: 'Anything'));

      expect(profile.id, 'standard');
      expect(profile.instanceId, 0);
      expect(profile.unquotedSoapAction, isFalse);
      expect(profile.seekUnit, 'REL_TIME');
      expect(profile.omitDidl, isFalse);
    });

    test('the first matching registered profile wins', () {
      // Priority is registration order: the specific model override is
      // registered before its own family profile so it wins the subset.
      final registry = DeviceCompatibilityRegistry()
        ..register(
          DeviceCompatibilityProfile(
            id: 'vendor-a-override',
            description: 'specific model needing instance 1',
            matches: (device) => (device.manufacturer?.contains('QuirkTV') ?? false) && device.modelName == 'Model-X',
            instanceId: 1,
          ),
        )
        ..register(
          DeviceCompatibilityProfile(
            id: 'vendor-a',
            description: 'unquoted SOAPACTION family',
            matches: (device) => device.manufacturer?.contains('QuirkTV') ?? false,
            unquotedSoapAction: true,
          ),
        );

      expect(registry.profileFor(deviceOf(manufacturer: 'QuirkTV', model: 'Model-X')).id, 'vendor-a-override');
      expect(registry.profileFor(deviceOf(manufacturer: 'QuirkTV', model: 'Model-Y')).id, 'vendor-a');
      expect(registry.profileFor(deviceOf(manufacturer: 'OtherTV')).id, 'standard');
    });

    test('profiles are exposed in registration order', () {
      final registry = DeviceCompatibilityRegistry()
        ..register(DeviceCompatibilityProfile(id: 'a', description: 'first', matches: (_) => false));

      expect(registry.profiles.single.id, 'a');
      registry.register(DeviceCompatibilityProfile(id: 'b', description: 'second', matches: (_) => false));
      expect(registry.profiles.map((profile) => profile.id), <String>['a', 'b']);
    });
  });

  group('profile effects on the wire', () {
    test('a custom instance id reaches every envelope', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: deviceOf(),
        client: SoapClient(transport: av.transport),
        profile: const DeviceCompatibilityProfile(id: 'instance-1', description: 'multi-instance stack', instanceId: 1),
      );
      await session.connect();

      await session.play();
      await session.seek(const Duration(minutes: 1));

      expect(av.transport.sent.first.body, contains('<InstanceID>1</InstanceID>'));
      expect(av.transport.sent.last.body, contains('<InstanceID>1</InstanceID>'));
      await session.dispose();
    });

    test('unquotedSoapAction strips the header quotes', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: deviceOf(),
        client: SoapClient(transport: av.transport),
        profile: const DeviceCompatibilityProfile(
          id: 'unquoted',
          description: 'firmware that chokes on quoted SOAPACTION',
          unquotedSoapAction: true,
        ),
      );
      await session.connect();

      await session.play();

      final sent = av.transport.sent.firstWhere((exchange) => (exchange.headers['SOAPAction'] ?? '').contains('Play'));
      // The transport stores headers with their original casing; the
      // unquoted profile rewrites the value, not the name.
      final action = sent.headers.values.where((value) => value.contains('#Play')).first;

      expect(action.startsWith('"'), isFalse, reason: 'the profile strips the spec quotes on the wire');
      expect(action.endsWith('"'), isFalse);
      expect(action, contains('#Play'));
      await session.dispose();
    });

    test('a custom seek unit replaces REL_TIME', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: deviceOf(),
        client: SoapClient(transport: av.transport),
        profile: const DeviceCompatibilityProfile(
          id: 'vendor-seek',
          description: 'answers only to a vendor seek unit',
          seekUnit: 'X_VENDOR_TIME',
        ),
      );
      await session.connect();
      await session.setMedia(media());
      await session.play();

      await session.seek(const Duration(minutes: 1));

      expect(
        av.transport.sent
            .map((exchange) => exchange.body)
            .lastWhere((body) => body.contains('<Unit>'), orElse: () => ''),
        contains('<Unit>X_VENDOR_TIME</Unit>'),
      );
      await session.dispose();
    });

    test('omitDidl sends an empty metadata payload', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: deviceOf(),
        client: SoapClient(transport: av.transport),
        profile: const DeviceCompatibilityProfile(
          id: 'no-didl',
          description: 'firmware that rejects DIDL outright',
          omitDidl: true,
        ),
      );
      await session.connect();

      await session.setMedia(media());

      final body = av.transport.sent.first.body;
      expect(body, contains('<CurrentURIMetaData></CurrentURIMetaData>'), reason: 'the element stays, empty');
      expect(body, isNot(contains('DIDL-Lite')));
      await session.dispose();
    });

    test('a custom play speed replaces 1', () async {
      final av = ScriptedAvTransport();
      final session = DlnaSessionController(
        device: deviceOf(),
        client: SoapClient(transport: av.transport),
        profile: const DeviceCompatibilityProfile(
          id: 'speed',
          description: 'rejects the default 1 without an explicit decimal',
          playSpeed: '1.00',
        ),
      );
      await session.connect();

      await session.play();

      expect(
        av.transport.sent.firstWhere((exchange) => exchange.body.contains('<Speed>')).body,
        contains('<Speed>1.00</Speed>'),
      );
      await session.dispose();
    });
  });

  group('manager resolves profiles (§9 wiring)', () {
    test('a matching registry profile governs the session end to end', () async {
      final registry = DeviceCompatibilityRegistry()
        ..register(
          DeviceCompatibilityProfile(
            id: 'quirky',
            description: 'needs instance 2 and no DIDL',
            matches: (device) => device.manufacturer?.contains('QuirkTV') ?? false,
            instanceId: 2,
            omitDidl: true,
          ),
        );
      final av = ScriptedAvTransport();
      final manager = DlnaSessionManager(transport: av.transport, compatibility: registry);

      final session = await manager.connect(deviceOf(manufacturer: 'QuirkTV'));
      await session.setMedia(
        DlnaMedia(
          id: 'm1',
          title: '第四集',
          mediaType: DlnaMediaType.video,
          sourceUri: Uri.parse('http://cdn/a.mp4'),
          mimeType: 'video/mp4',
          resources: <DlnaMediaResource>[DlnaMediaResource(uri: Uri.parse('http://cdn/a.mp4'), mimeType: 'video/mp4')],
        ),
      );

      // SetAVTransportURI carries both quirks: the profile's instance
      // id and the empty DIDL payload.
      final setUri = av.transport.sent.firstWhere(
        (exchange) => (exchange.headers['SOAPAction'] ?? '').contains('SetAVTransportURI'),
      );
      expect(setUri.body, contains('<InstanceID>2</InstanceID>'));
      expect(setUri.body, contains('<CurrentURIMetaData></CurrentURIMetaData>'));
      await manager.disconnect(session);
      await manager.dispose();
    });
  });
}
