import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../../support/fakes.dart';

void main() {
  group('MediaProtocolInfo', () {
    test('parses the four-field structure with DLNA parameters', () {
      final info = MediaProtocolInfo.tryParse('http-get:*:video/mp4:DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_PN=MP4')!;

      expect(info.protocol, 'http-get');
      expect(info.network, '*');
      expect(info.contentFormat, 'video/mp4');
      expect(info.dlnaProfile, 'MP4');
      expect(info.operations, 1);
      expect(info.supportsByteRange, isTrue);
      expect(info.requiresConversion, isFalse);
    });

    test('minimal entries without additional info still parse', () {
      final info = MediaProtocolInfo.tryParse('http-get:*:video/mpeg:*')!;

      expect(info.contentFormat, 'video/mpeg');
      expect(info.dlnaProfile, isNull);
      expect(info.operations, isNull);
      // Most real sink lists omit DLNA.ORG_OP on plain entries; reading
      // that as "no range" would disqualify every such device.
      expect(info.supportsByteRange, isTrue);
    });

    test('OP=10 means time-seek, not byte-range', () {
      final info = MediaProtocolInfo.tryParse('http-get:*:video/mp4:DLNA.ORG_OP=10')!;

      expect(info.operations, 0x10);
      expect(info.supportsByteRange, isFalse);
    });

    test('CI=1 marks a converted rendition', () {
      final info = MediaProtocolInfo.tryParse('http-get:*:video/mpeg:DLNA.ORG_CI=1')!;

      expect(info.requiresConversion, isTrue);
    });

    test('list parsing survives commas, newlines and junk', () {
      final entries = MediaProtocolInfo.parseList('''
http-get:*:video/mp4:*,
http-get:*:audio/mpeg:DLNA.ORG_PN=MP3
http-get:*:image/jpeg:*,garbage-without-colons,
http-get:*:video/x-matroska:*
''');

      expect(entries, hasLength(4));
      expect(entries.map((e) => e.contentFormat), containsAll(<String>['video/mp4', 'audio/mpeg', 'image/jpeg']));
    });

    test('structurally wrong strings are rejected', () {
      expect(MediaProtocolInfo.tryParse(''), isNull);
      expect(MediaProtocolInfo.tryParse('http-get'), isNull);
      expect(MediaProtocolInfo.tryParse('http-get:*'), isNull);
    });
  });

  group('DlnaMediaCapability', () {
    test('built from an http-get sink list', () {
      final capability = DlnaMediaCapability.fromSink(
        MediaProtocolInfo.parseList(
          'http-get:*:video/mp4:DLNA.ORG_PN=MP4;DLNA.ORG_OP=01,http-get:*:audio/mpeg:*,rtsp-rtp-udp:*:video/mp4:*,'
          'http-get:*:video/x-matroska:*',
        ),
      );

      expect(capability.known, isTrue);
      expect(capability.supportsFormat('video/mp4'), isTrue);
      expect(capability.supportsFormat('VIDEO/MP4'), isTrue);
      expect(capability.supportsFormat('video/webm'), isFalse);
      expect(capability.supportsProfile('MP4'), isTrue);
      expect(capability.supportsProfile('MKV'), isFalse);
      // rtsp entries do not speak for http-get casting.
      expect(capability.supportsFormat('image/jpeg'), isFalse);
    });

    test('a wildcard content format accepts everything', () {
      final capability = DlnaMediaCapability.fromSink(MediaProtocolInfo.parseList('http-get:*:*:*'));

      expect(capability.supportsFormat('video/webm'), isTrue);
    });

    test('an empty sink resolves to unknown, which rejects nothing', () {
      const capability = DlnaMediaCapability.unknown();

      expect(capability.known, isFalse);
      expect(capability.supportsFormat('video/whatever'), isTrue);
      expect(capability.supportsProfile('ANYTHING'), isTrue);
    });
  });

  group('DlnaCapabilityResolver', () {
    test('reads the Sink argument from GetProtocolInfo', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(
          statusCode: 200,
          body:
              '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
              '<u:GetProtocolInfoResponse xmlns:u="urn:schemas-upnp-org:service:ConnectionManager:1"> '
              '<Sink>http-get:*:video/mp4:*,http-get:*:audio/mpeg:*</Sink> '
              '</u:GetProtocolInfoResponse></s:Body></s:Envelope>',
        ),
      );
      final resolver = DlnaCapabilityResolver(client: SoapClient(transport: transport));

      final capability = await resolver.resolve(_connectionManager);

      expect(capability.known, isTrue);
      expect(capability.supportsFormat('video/mp4'), isTrue);
      expect(transport.sent.single.headers['SOAPAction'], contains('#GetProtocolInfo'));
    });

    test('a silent or failing device resolves to unknown, not an error', () async {
      final silent = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(
          statusCode: 200,
          body:
              '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
              '<u:GetProtocolInfoResponse xmlns:u="urn:schemas-upnp-org:service:ConnectionManager:1" /> '
              '</s:Body></s:Envelope>',
        ),
      );
      final resolver = DlnaCapabilityResolver(client: SoapClient(transport: silent));
      expect(await resolver.resolve(_connectionManager).then((c) => c.known), isFalse);

      final failing = DlnaCapabilityResolver(
        client: SoapClient(transport: FakeSoapTransport((url, headers, body) => throw StateError('device went away'))),
      );
      expect(await failing.resolve(_connectionManager).then((c) => c.known), isFalse);
    });
  });

  group('DlnaMediaSelector', () {
    final mp4 = DlnaMediaResource(uri: Uri.parse('http://media/a.mp4'), mimeType: 'video/mp4');
    final webm = DlnaMediaResource(uri: Uri.parse('http://media/a.webm'), mimeType: 'video/webm');
    final noRangeMp4 = DlnaMediaResource(
      uri: Uri.parse('http://media/b.mp4'),
      mimeType: 'video/mp4',
      supportsByteRange: false,
    );

    test('picks the format the device declares', () {
      final media = DlnaMedia(
        id: 'm1',
        title: 'A',
        mediaType: DlnaMediaType.video,
        sourceUri: Uri.parse('file:///a.mkv'),
        resources: <DlnaMediaResource>[webm, mp4],
      );
      final capability = DlnaMediaCapability.fromSink(MediaProtocolInfo.parseList('http-get:*:video/mp4:*'));

      final selection = const DlnaMediaSelector().select(media: media, capability: capability);

      expect(selection.resource.uri, mp4.uri);
      expect(selection.requiresTranscoding, isFalse);
      expect(selection.reasons, hasLength(2));
    });

    test('prefers a range-capable resource', () {
      final media = DlnaMedia(
        id: 'm1',
        title: 'A',
        mediaType: DlnaMediaType.video,
        sourceUri: Uri.parse('file:///a.mp4'),
        resources: <DlnaMediaResource>[noRangeMp4, mp4],
      );

      final selection = const DlnaMediaSelector().select(media: media, capability: const DlnaMediaCapability.unknown());

      expect(selection.resource.uri, mp4.uri);
    });

    test('unknown capability lets anything through, with the assumption recorded', () {
      final media = DlnaMedia(
        id: 'm1',
        title: 'A',
        mediaType: DlnaMediaType.video,
        sourceUri: Uri.parse('file:///a.webm'),
        resources: <DlnaMediaResource>[webm],
      );

      final selection = const DlnaMediaSelector().select(media: media, capability: const DlnaMediaCapability.unknown());

      expect(selection.resource, webm);
      expect(selection.reasons.single, contains('unknown'));
    });

    test('a known device that rejects every resource fails explicitly', () {
      final media = DlnaMedia(
        id: 'm1',
        title: 'A',
        mediaType: DlnaMediaType.video,
        sourceUri: Uri.parse('file:///a.webm'),
        resources: <DlnaMediaResource>[webm],
      );
      final capability = DlnaMediaCapability.fromSink(MediaProtocolInfo.parseList('http-get:*:video/mp4:*'));

      expect(
        () => const DlnaMediaSelector().select(media: media, capability: capability),
        throwsA(
          isA<DlnaUnsupportedMediaException>()
              .having((e) => e.reasons, 'reasons', hasLength(1))
              .having((e) => e.reasons.single, 'reason', contains('does not declare video/webm')),
        ),
      );
    });

    test('an item without resources is a programming error, not a selection', () {
      final media = DlnaMedia(
        id: 'm1',
        title: 'A',
        mediaType: DlnaMediaType.video,
        sourceUri: Uri.parse('file:///a'),
        resources: <DlnaMediaResource>[],
      );

      expect(
        () => const DlnaMediaSelector().select(media: media, capability: const DlnaMediaCapability.unknown()),
        throwsArgumentError,
      );
    });
  });
}

final DlnaService _connectionManager = DlnaService(
  serviceType: 'urn:schemas-upnp-org:service:ConnectionManager:1',
  controlUrl: Uri.parse('http://tv/cm'),
);
